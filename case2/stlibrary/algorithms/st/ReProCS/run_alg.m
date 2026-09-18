function out = run_alg(M, opts, context)
%RUN_ALG Memory-safe ReProCS foreground/background adapter.
%
% This implements the projected-CS / support LS / projection-PCA loop used in
% the public ReProCS foreground-background code, but it never forms the dense
% n-by-n matrix I-P*P'. For a support T, only (I-P*P')(:,T) is constructed.
% In headless mode it also keeps only an alpha-frame low-rank ring buffer
% instead of the complete background video.

vendor=fullfile(context.projectRoot,'libs','ReProCS');
assert(isfolder(vendor), 'ReProCS is not installed. Run setup_third_party.');
oldPath=path; addpath(genpath(vendor)); cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
assert(exist('yall1','file')==2, 'YALL1 from the ReProCS repository was not found.');
assert(exist('cgls','file')==2, 'cgls.m from the ReProCS repository was not found.');
assert(exist('proj_PCA_thresh','file')==2, 'proj_PCA_thresh.m was not found.');

[n,T]=size(M);
[U0,tTrain,initSource]=resolve_initial_subspace(M,opts,context);
subTrace=init_subspace_trace(context,T);
if subTrace.enabled, subDiag=context.subspaceDiagnostics; else, subDiag=struct(); end
diagOverhead=0;
r=size(U0,2);
Xtrain=double(M(:,1:tTrain));

% Fair-comparison policy: ReProCS receives exactly the same U0 as every
% other tracker. Its optional robust initializer is therefore bypassed.
% Use zero affine offset so Pold spans precisely the shared subspace.
mu=zeros(n,1);
Ltrain=U0*(U0'*Xtrain);
coeffTrain=(U0'*Xtrain)/sqrt(max(tTrain,1));
ss=svd(coeffTrain,'econ'); if isempty(ss), ss=eps; end
sigma=ss(min(r,numel(ss)));
evThresh=opts.evScale*sigma*(sin(opts.thetaDeg*pi/180)^2);

score=zeros(n,T,context.scoreClass);
score(:,1:tTrain)=cast(abs(double(M(:,1:tTrain))-Ltrain),context.scoreClass);
[snapIdx,snapMap,snapBg]=prepare_snapshot_capture(context,n,T);
if ~isempty(snapIdx)
    warmSlots=find(snapIdx<=tTrain);
    if ~isempty(warmSlots)
        snapBg(:,warmSlots)=cast(Ltrain(:,snapIdx(warmSlots)),context.scoreClass);
    end
end
if context.needBackground
    L=zeros(n,T); L(:,1:tTrain)=Ltrain;
else
    L=[];
end
if context.keepAuxiliaryMasks, nativeFull=false(n,T); else, nativeFull=[]; end
if subTrace.enabled
    for tt=1:tTrain
        if should_sample_subspace_trace(subTrace,tt)
            tDiag=tic;
            subTrace=record_subspace_trace(subTrace,subDiag,U0,U0,tt);
            diagOverhead=diagOverhead+toc(tDiag);
        end
    end
end
if tTrain>=T
    out=struct('L',L,'score',score,'Ufinal',U0,'Uinitial',U0, ...
        'changeTimes',[],'nativeMask',nativeFull,'initializationSource',initSource);
    if subTrace.enabled, out.diagnostics=struct('subspace',subTrace,'overheadSeconds',diagOverhead); end
    if ~isempty(snapIdx), out.snapshotBackground=snapBg; out.snapshotIndices=snapIdx; end
    if context.keepResidual && context.needBackground, out.S=double(M)-L; end
    return;
end

Pold=U0; Pnew=[]; P=[Pold Pnew];
changeTimes=[]; phase=0; k=0;
alpha=max(1,round(opts.alpha));
lowRankBlock=zeros(n,alpha);
blockCount=0;

% First post-training frame gets a causal projection background.
t=tTrain+1;
xcenter=double(M(:,t))-mu;
lprev=P*(P'*xcenter);
if context.needBackground, L(:,t)=lprev+mu; end
snapSlot=snapMap(t); if snapSlot>0, snapBg(:,snapSlot)=cast(lprev+mu,context.scoreClass); end
score(:,t)=cast(abs(xcenter-lprev),context.scoreClass);
if should_sample_subspace_trace(subTrace,t)
    tDiag=tic;
    subTrace=record_subspace_trace(subTrace,subDiag,P,P,t);
    diagOverhead=diagOverhead+toc(tDiag);
end

for t=tTrain+2:T
    ii=t-tTrain;
    xcenter=double(M(:,t))-mu;
    doSubTrace=should_sample_subspace_trace(subTrace,t);
    if doSubTrace, Pprev=P; end
    project=@(x) x-P*(P'*x);
    y=project(xcenter);
    A.times=@(x) x-P*(P'*x);
    A.trans=@(x) x-P*(P'*x);
    yopts.tol=opts.yallTol; yopts.print=0;
    prevProj=project(lprev);
    yopts.delta=max(norm(prevProj),1e-8);
    xhat=yall1(A,y,yopts);
    omega=sqrt(sum(xcenter.^2)/n);
    support=find(abs(xhat)>omega);
    if context.keepAuxiliaryMasks, nativeFull(support,t)=true; end

    shat=zeros(n,1);
    if ~isempty(support)
        sN=numel(support);
        E=sparse(support,1:sN,1,n,sN);
        As=E-P*(P(support,:).');
        coeff=cgls(As,y,0,opts.cglsTol);
        shat(support)=coeff;
    end
    lcurr=xcenter-shat;
    if context.needBackground, L(:,t)=lcurr+mu; end
    snapSlot=snapMap(t); if snapSlot>0, snapBg(:,snapSlot)=cast(lcurr+mu,context.scoreClass); end
    score(:,t)=cast(abs(shat),context.scoreClass);

    blockCount=blockCount+1;
    lowRankBlock(:,mod(blockCount-1,alpha)+1)=lcurr;
    if mod(ii-1,alpha)==0 && ii>=alpha && blockCount>=alpha
        MM=(lowRankBlock-Pold*(Pold'*lowRankBlock))/sqrt(alpha);
        if phase==0
            lead=svds(MM,1);
            if lead>=sqrt(max(evThresh,eps))
                phase=1; changeTimes(end+1)=t; %#ok<AGROW>
                k=0;
            end
        else
            Pnew=proj_PCA_thresh(MM,sqrt(max(alpha*evThresh,eps)));
            P=[Pold Pnew]; k=k+1;
            if k==opts.K+1
                Pold=P; Pnew=[]; P=Pold; k=1; phase=0;
            end
        end
    end
    if doSubTrace
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,P,Pprev,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end
    lprev=lcurr;
end

out=struct('L',L,'score',score,'Ufinal',P,'Uinitial',U0, ...
    'changeTimes',changeTimes,'nativeMask',nativeFull,'initializationSource',initSource);
if subTrace.enabled, out.diagnostics=struct('subspace',subTrace,'overheadSeconds',diagOverhead); end
if ~isempty(snapIdx), out.snapshotBackground=snapBg; out.snapshotIndices=snapIdx; end
if context.keepResidual && context.needBackground, out.S=double(M)-L; end
end
