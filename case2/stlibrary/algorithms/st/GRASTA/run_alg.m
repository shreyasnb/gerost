function out = run_alg(M, opts, context)
%RUN_ALG GRASTA adapter using the benchmark-wide shared initial subspace.
%
% profile='lrslibrary' (benchmark default): use LRSLibrary's constant 1e-2
% online step and a 20-iteration ADMM budget, but preserve the benchmark-wide
% common U0 instead of running GRASTA-only private training.
%
% profile='sharedAdaptive': preserve the common U0 but let GRASTA
% learn its adaptive step scale from the first online CDnet frame. This is
% scale-aware and avoids borrowing the literal 0.01 adaptive scale from the
% much larger-amplitude synthetic GeRoST case-2 experiment.
%
% profile='gerostCase2': reproduce the GeRoST repository comparison setup
% (adaptive rule with STATUS.step_scale=0.01).

vendor = fullfile(context.projectRoot,'libs','GRASTA');
assert(isfile(fullfile(vendor,'grasta_stream.m')), ...
    'GRASTA is not installed. Run setup_third_party.');
oldPath=path; addpath(genpath(vendor)); cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>

[n,T]=size(M);
[U_hat,tTrain,initSource] = resolve_initial_subspace(M,opts,context);
r = size(U_hat,2);
U0 = U_hat;
subTrace=init_subspace_trace(context,T);
if subTrace.enabled, subDiag=context.subspaceDiagnostics; else, subDiag=struct(); end
diagOverhead=0;

if ~isfield(opts,'profile') || isempty(opts.profile), opts.profile='lrslibrary'; end
if ~isfield(opts,'onlineAdmmIterations') || isempty(opts.onlineAdmmIterations)
    opts.onlineAdmmIterations=opts.iterMax;
end
if ~isfield(opts,'scoreMode') || isempty(opts.scoreMode), opts.scoreMode='residual'; end
if ~isfield(opts,'quiet') || isempty(opts.quiet), opts.quiet=true; end
profile=lower(string(opts.profile));
scoreMode=lower(string(opts.scoreMode));
if ~any(profile==["sharedadaptive","lrslibrary","gerostcase2"])
    error('SubspaceBenchmark:BadGRASTAProfile', ...
        'GRASTA profile must be sharedAdaptive, lrslibrary, or gerostCase2.');
end
if ~any(scoreMode==["residual","sparse"])
    error('SubspaceBenchmark:BadGRASTAScoreMode', ...
        'GRASTA scoreMode must be residual or sparse.');
end

OPTIONS.RANK = r;
OPTIONS.rho = opts.rho;
OPTIONS.MAX_MU = opts.maxMu;
OPTIONS.MIN_MU = opts.minMu;
OPTIONS.ITER_MIN = opts.iterMin;
OPTIONS.ITER_MAX = opts.iterMax;
OPTIONS.TOL = opts.tol;
OPTIONS.DIM_M = n;
OPTIONS.USE_MEX = double(opts.useMex);
OPTIONS.QUIET = double(logical(opts.quiet));

status.init = 1;
status.curr_iter = 0;
status.last_mu = opts.minMu;
status.level = 0;
status.last_w = zeros(r,1);
status.last_gamma = zeros(n,1);
OPTS.TOL = opts.tol;
OPTS.QUIET = 1;
OPTS.RHO = opts.rho;

switch profile
    case "sharedadaptive"
        OPTIONS.CONSTANT_STEP = 0;
        % Let the native adaptive rule infer a scale from the first CDnet
        % observation while preserving the supplied U0 (STATUS.init=1).
        status.step_scale = 0;
        OPTS.MAX_ITER = opts.iterMin;
    case "lrslibrary"
        OPTIONS.CONSTANT_STEP = opts.constantStep;
        if OPTIONS.CONSTANT_STEP<=0, OPTIONS.CONSTANT_STEP=1e-2; end
        status.step_scale = 0; % unused by constant-step branch
        % LRSLibrary reaches the online phase after repeated robust training;
        % use the configured online solve budget rather than freezing at 5.
        OPTS.MAX_ITER = max(opts.iterMin,min(opts.iterMax,round(opts.onlineAdmmIterations)));
    case "gerostcase2"
        OPTIONS.CONSTANT_STEP = 0;
        status.step_scale = opts.initialStepScale;
        OPTS.MAX_ITER = opts.iterMin;
end

Xtrain = double(M(:,1:tTrain));
Ltrain = U_hat * (U_hat' * Xtrain);
score = zeros(n,T,context.scoreClass);
score(:,1:tTrain) = cast(abs(Xtrain-Ltrain),context.scoreClass);
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
if context.keepAuxiliaryMasks
    nativeSparse=zeros(n,T,context.scoreClass);
    nativeSparse(:,1:tTrain)=score(:,1:tTrain);
else
    nativeSparse=[];
end
if subTrace.enabled
    for tt=1:tTrain
        if should_sample_subspace_trace(subTrace,tt)
            tDiag=tic;
            subTrace=record_subspace_trace(subTrace,subDiag,U_hat,U_hat,tt);
            diagOverhead=diagOverhead+toc(tDiag);
        end
    end
end

subsampling=min(max(opts.subsampling,eps),1);
for t=tTrain+1:T
    I=double(M(:,t));
    idx=sample_idx(n,subsampling);
    I_Omega=I(idx);
    doSubTrace=should_sample_subspace_trace(subTrace,t);
    if doSubTrace, Uprev=U_hat; end
    [U_hat,status,OPTS]=grasta_stream(I_Omega,idx,U_hat,status,OPTIONS,OPTS);
    if doSubTrace
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,U_hat,Uprev,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end
    l=U_hat*status.w*status.SCALE;
    if context.needBackground, L(:,t)=l; end
    snapSlot=snapMap(t);
    if snapSlot>0, snapBg(:,snapSlot)=cast(l,context.scoreClass); end
    if context.keepAuxiliaryMasks
        sFull=zeros(n,1);
        sFull(idx)=status.s_t;
        nativeSparse(:,t)=cast(sFull,context.scoreClass);
    end
    if scoreMode=="sparse"
        sFull=zeros(n,1);
        sFull(idx)=status.s_t;
        score(:,t)=cast(abs(sFull),context.scoreClass);
    else
        score(:,t)=cast(abs(I-l),context.scoreClass);
    end
end

state=status;
state.profile=char(profile);
state.scoreMode=char(scoreMode);
state.finalAdmmMaxIter=OPTS.MAX_ITER;
out=struct('L',L,'score',score,'Ufinal',U_hat,'Uinitial',U0, ...
    'state',state,'initializationSource',initSource);
if subTrace.enabled, out.diagnostics=struct('subspace',subTrace,'overheadSeconds',diagOverhead); end
if context.keepAuxiliaryMasks, out.nativeSparse=nativeSparse; end
if ~isempty(snapIdx), out.snapshotBackground=snapBg; out.snapshotIndices=snapIdx; end
if context.keepResidual && context.needBackground, out.S=double(M)-L; end
end

function idx=sample_idx(n,fraction)
if fraction>=1, idx=(1:n)'; return; end
m=max(1,round(fraction*n)); p=randperm(n,m); idx=p(:);
end
