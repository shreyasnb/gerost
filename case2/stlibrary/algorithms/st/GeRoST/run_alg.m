function out = run_alg(M, opts, context)
%RUN_ALG GeRoST foreground/background adapter following upstream case2 flow.
%
% The online order follows shreyasnb/GeRoST/case2/bg_fg_main.m:
%   pre-update NSR -> adaptive rho -> GeRoST descent step -> FG/BG ISTA.
%
% For CDnet-sized videos, the nominal window SVD is maintained with the
% upstream rank-1 eigenspace update. By default the inner maximization uses
% an algebraically equivalent reduced-coordinate implementation: because
% B=lambda*P_What-P_Y has rank <= d+k, bisection eigendecompositions are
% done in span([Y,What]) and the ambient basis is formed only once per inner
% solve. Set opts.innerMaxImplementation='upstream' to call the reference
% gerost.inner_max directly for validation/reproduction.

vendor=fullfile(context.projectRoot,'libs','GeRoST');
assert(isfile(fullfile(vendor,'gerost.m')), 'GeRoST is not installed. Run setup_third_party.');
oldPath=path; addpath(genpath(vendor)); cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
assert(exist('grassmannfactory','file')==2, 'Manopt not found. Run setup_third_party.');

[n,T]=size(M);
[U,tTrain,initSource]=resolve_initial_subspace(M,opts,context);
U0=U;
subTrace=init_subspace_trace(context,T);
if subTrace.enabled, subDiag=context.subspaceDiagnostics; else, subDiag=struct(); end
diagOverhead=0;
r=size(U,2);
window=max(round(opts.window),r);
if isempty(opts.dataRank)
    requestedD=r+round(opts.dataRankOffset);
else
    requestedD=round(opts.dataRank);
end
d=min([max(r,requestedD),window,n]);
K=max(1,round(opts.K));
manifold=grassmannfactory(n,r);

if ~isfield(opts,'innerMaxImplementation') || isempty(opts.innerMaxImplementation)
    opts.innerMaxImplementation='reduced';
end
if ~isfield(opts,'bisectTol') || isempty(opts.bisectTol), opts.bisectTol=1e-6; end
if ~isfield(opts,'bisectMaxIter') || isempty(opts.bisectMaxIter), opts.bisectMaxIter=32; end
if ~isfield(opts,'profileTiming') || isempty(opts.profileTiming), opts.profileTiming=false; end
innerMode=lower(string(opts.innerMaxImplementation));
if ~any(innerMode==["reduced","upstream"])
    error('SubspaceBenchmark:BadGeRoSTInnerMode', ...
        'GeRoST innerMaxImplementation must be ''reduced'' or ''upstream''.');
end
profileTiming=logical(opts.profileTiming);
timing=struct('warmupSeparation',0,'nsr',0,'windowUpdate',0,'innerMax',0, ...
    'gradientLogic',0,'expMap',0,'onlineSeparation',0,'totalOnline',0, ...
    'innerCalls',0,'bisectionIterations',0,'activeInnerCalls',0);

score=zeros(n,T,context.scoreClass);
[snapIdx,snapMap,snapBg]=prepare_snapshot_capture(context,n,T);
if context.needBackground, L=zeros(n,T); else, L=[]; end
if context.keepAuxiliaryMasks, nativeSparse=zeros(n,T,context.scoreClass); else, nativeSparse=[]; end
rhoHistory=nan(1,T);
pHistory=nan(1,T);
xiOperationalHistory=nan(1,T);
lambdaHistory=nan(1,T);

for t=1:tTrain
    if profileTiming, tt=tic; end
    I=double(M(:,t));
    [bg,fg]=extract_fg_bg_ista(I,U,opts.istaLambda,opts.istaIterations);
    if profileTiming, timing.warmupSeparation=timing.warmupSeparation+toc(tt); end
    if context.needBackground, L(:,t)=bg; end
    snapSlot=snapMap(t); if snapSlot>0, snapBg(:,snapSlot)=cast(bg,context.scoreClass); end
    if context.keepAuxiliaryMasks, nativeSparse(:,t)=cast(fg,context.scoreClass); end
    score(:,t)=cast(abs(I-bg),context.scoreClass);
    if should_sample_subspace_trace(subTrace,t)
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,U,U,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end
end

Wbuf=zeros(n,window);
count=0;
step=0;
What=[];
sigmaVals=[];
lambdaLast=NaN;
if profileTiming, onlineTimer=tic; end

for t=tTrain+1:T
    step=step+1;
    I=double(M(:,t));
    doSubTrace=should_sample_subspace_trace(subTrace,t);
    if doSubTrace, Uprev=U; end

    if profileTiming, tt=tic; end
    proj=U*(U'*I);
    resNorm=norm(I-proj);
    signalNorm=max(norm(U'*I),1e-6);
    p_t=resNorm/signalNorm;
    pHistory(t)=p_t;
    if opts.adaptiveRho
        pCap=min(max(p_t,0),min(opts.rhoNsrCap,0.99));
        xiOperationalHistory(t)=pCap;
        rhoCandidate=opts.rhoScale*pCap/max(1-pCap,1e-12);
        rhoHistory(t)=min(max(rhoCandidate,1e-6),sqrt(d)-1e-6);
    else
        pCap=p_t;
        xiOperationalHistory(t)=pCap;
        rhoCandidate=[];
    end
    if profileTiming, timing.nsr=timing.nsr+toc(tt); end

    if profileTiming, tt=tic; end
    slot=mod(step-1,window)+1;
    if step>window && ~isempty(What)
        outgoing=Wbuf(:,slot);
        [What,sigmaVals]=gerost.rank1_eig_update(What,sigmaVals,outgoing,-1,d);
        Wbuf(:,slot)=I;
        [What,sigmaVals]=gerost.rank1_eig_update(What,sigmaVals,I,+1,d);
        count=window;
    else
        Wbuf(:,slot)=I;
        count=min(count+1,window);
        if count>=d
            W=Wbuf(:,1:count);
            [Uw,Sw,~]=svd(W,'econ');
            sv=diag(Sw);
            What=Uw(:,1:d);
            sigmaVals=sv(1:d);
        end
    end
    if profileTiming, timing.windowUpdate=timing.windowUpdate+toc(tt); end

    if count>=d
        if opts.adaptiveRho
            rho=rhoCandidate;
        elseif isa(opts.rho,'function_handle')
            try
                rho=opts.rho(step,sigmaVals,What,U);
            catch
                rho=opts.rho(step,sigmaVals,What);
            end
        else
            rho=opts.rho;
        end
        rho=min(max(rho,1e-6),sqrt(d)-1e-6);
        rhoHistory(t)=rho;

        if step<=window, Wdata=Wbuf(:,1:count); else, Wdata=Wbuf; end
        Y=U;
        lambdaStar=NaN;
        for iter=1:K %#ok<NASGU>
            if profileTiming, tt=tic; end
            if innerMode=="reduced"
                [lambdaValue,WWtY,Nhat,innerInfo]=gerost_inner_max_reduced( ...
                    Y,What,rho,d,opts.bisectTol,opts.bisectMaxIter);
                lambdaStar=lambdaValue;
                if profileTiming
                    timing.bisectionIterations=timing.bisectionIterations+innerInfo.bisectionIterations;
                    timing.activeInnerCalls=timing.activeInnerCalls+double(innerInfo.constraintActive);
                end
            else
                [Wstar,lambdaStar]=gerost.inner_max(Y,What,rho,d);
                lambdaValue=lambdaStar(1);
                WWtY=[]; Nhat=[];
            end
            if profileTiming
                timing.innerMax=timing.innerMax+toc(tt);
                timing.innerCalls=timing.innerCalls+1;
                tt=tic;
            end

            lambdaValue=lambdaStar(1);
            if lambdaValue>2.0
                if innerMode=="reduced"
                    grad=-2.0*(WWtY-Y*Nhat);
                else
                    grad=gerost.gradf(Y,Wstar);
                    YtW=Y'*Wstar;
                    Nhat=YtW*YtW';
                    Nhat=(Nhat+Nhat')/2;
                end
                delta=max(lambdaValue-2.0,1e-2);
                Llip=4.0*(1.0+1.0/delta)+4.0*sqrt(d)/(delta^2);
                eigvals=eig(Nhat);
                nu0=max(min(eigvals),1e-10);
                nu=2.0*nu0;
            else
                if strcmp(opts.fallback,'data')
                    WtY=Wdata'*Y;
                    WWtYdata=Wdata*WtY;
                    grad=-2.0*(WWtYdata-Y*(Y'*WWtYdata));
                    Llip=4.0*sigmaVals(1)^2;
                else
                    grad=gerost.gradf(Y,What);
                    Llip=4.0;
                end
                nu=0.0;
            end

            if ~isempty(opts.alpha)
                alpha=opts.alpha;
            elseif nu>1e-10
                alpha=min(1.0/max(Llip,1e-8),1.0/(2.0*nu));
            else
                alpha=1.0/max(Llip,1e-8);
            end
            tangent=-alpha*grad;
            if profileTiming
                timing.gradientLogic=timing.gradientLogic+toc(tt);
                tt=tic;
            end
            Y=manifold.exp(Y,tangent);
            if profileTiming, timing.expMap=timing.expMap+toc(tt); end
        end
        U=Y;
        lambdaLast=lambdaStar(1);
        lambdaHistory(t)=lambdaLast;
    end
    if doSubTrace
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,U,Uprev,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end

    if profileTiming, tt=tic; end
    [bg,fg]=extract_fg_bg_ista(I,U,opts.istaLambda,opts.istaIterations);
    if profileTiming, timing.onlineSeparation=timing.onlineSeparation+toc(tt); end
    if context.needBackground, L(:,t)=bg; end
    snapSlot=snapMap(t); if snapSlot>0, snapBg(:,snapSlot)=cast(bg,context.scoreClass); end
    if context.keepAuxiliaryMasks, nativeSparse(:,t)=cast(fg,context.scoreClass); end
    score(:,t)=cast(abs(I-bg),context.scoreClass);
end
if profileTiming, timing.totalOnline=toc(onlineTimer); end

state=struct('steps',step,'windowLength',window,'samplesRetained',count, ...
    'dataRank',d,'lambdaLast',lambdaLast,'rhoHistory',rhoHistory, ...
    'pHistory',pHistory,'xiProxyHistory',pHistory, ...
    'xiOperationalHistory',xiOperationalHistory, ...
    'lambdaHistory',lambdaHistory,'lambdaStarHistory',lambdaHistory, ...
    'rhoNsrCap',opts.rhoNsrCap,'rhoScale',opts.rhoScale, ...
    'xiProxyDefinition','norm((I-UU'')u_t)/max(norm(U''u_t),1e-6)', ...
    'innerMaxImplementation',char(innerMode),'bisectTol',opts.bisectTol, ...
    'bisectMaxIter',opts.bisectMaxIter);
if profileTiming
    timing.onlineFrames=max(T-tTrain,0);
    if timing.innerCalls>0
        timing.meanBisectionIterations=timing.bisectionIterations/timing.innerCalls;
    else
        timing.meanBisectionIterations=0;
    end
    state.timing=timing;
end

out=struct('L',L,'score',score,'Ufinal',U,'Uinitial',U0, ...
    'state',state,'initializationSource',initSource);
if subTrace.enabled, out.diagnostics=struct('subspace',subTrace,'overheadSeconds',diagOverhead); end
if context.keepAuxiliaryMasks, out.nativeSparse=nativeSparse; end
if ~isempty(snapIdx), out.snapshotBackground=snapBg; out.snapshotIndices=snapIdx; end
if context.keepResidual && context.needBackground, out.S=double(M)-L; end
end
