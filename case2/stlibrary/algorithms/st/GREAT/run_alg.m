function out = run_alg(M, opts, context)
%RUN_ALG Memory-bounded GREAT adapter with an exact Gram-matrix backend.
%
% This implementation keeps the GREAT objective and update exactly the same
% as the public GREAT flow, but avoids recomputing svd(W,'econ') on the tall
% n-by-window data matrix at every frame.
%
% For a sliding window W, GREAT needs
%   1) sigma_1(W)^2 for the default step size, and
%   2) W*(W'*Y) for the exact Riemannian gradient.
%
% sigma_1(W)^2 = lambda_max(W'*W), so we maintain the small window Gram
% matrix G = W'*W exactly as samples enter/leave the ring buffer.  This
% changes only the numerical linear-algebra backend; it does NOT truncate W,
% approximate GREAT's objective, or use GeRoST's robust inner problem.
%
% Foreground/background extraction remains the same short alternating
% soft-threshold (ISTA-style) decomposition used by the benchmark.

vendor=fullfile(context.projectRoot,'libs','GeRoST');
assert(isfile(fullfile(vendor,'great.m')), ...
    'GREAT is not installed. Run setup_third_party.');
oldPath=path;
addpath(genpath(vendor));
cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
assert(exist('grassmannfactory','file')==2, ...
    'Manopt not found. Run setup_third_party.');

[n,T]=size(M);
[U,tTrain,initSource]=resolve_initial_subspace(M,opts,context);
U0=U;
subTrace=init_subspace_trace(context,T);
if subTrace.enabled
    subDiag=context.subspaceDiagnostics;
else
    subDiag=struct();
end
diagOverhead=0;
r=size(U,2);
window=max(round(opts.window),r);
K=max(1,round(opts.K));
manifold=grassmannfactory(n,r);

score=zeros(n,T,context.scoreClass);
[snapIdx,snapMap,snapBg]=prepare_snapshot_capture(context,n,T);
if context.needBackground
    L=zeros(n,T);
else
    L=[];
end
if context.keepAuxiliaryMasks
    nativeSparse=zeros(n,T,context.scoreClass);
else
    nativeSparse=[];
end

% Fill the common warm-up interval from the shared U0 without updating it.
for t=1:tTrain
    I=double(M(:,t));
    [bg,fg]=extract_fg_bg_ista(I,U,opts.istaLambda,opts.istaIterations);
    if context.needBackground
        L(:,t)=bg;
    end
    snapSlot=snapMap(t);
    if snapSlot>0
        snapBg(:,snapSlot)=cast(bg,context.scoreClass);
    end
    if context.keepAuxiliaryMasks
        nativeSparse(:,t)=cast(fg,context.scoreClass);
    end
    score(:,t)=cast(abs(I-bg),context.scoreClass);
    if should_sample_subspace_trace(subTrace,t)
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,U,U,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end
end

% Fixed-size ring buffer.  Column order is irrelevant to GREAT because both
% W*W' and the singular values of W are invariant to column permutation.
Wbuf=zeros(n,window);
G=zeros(window,window);       % exact G = Wbuf'*Wbuf on active columns
count=0;
step=0;

for t=tTrain+1:T
    step=step+1;
    I=double(M(:,t));
    slot=mod(step-1,window)+1;

    % Insert/overwrite the current ring-buffer slot first.  Then one matrix-
    % vector product gives all correlations of the new sample with the
    % active window.  Only one row/column of G changes at a sliding update.
    Wbuf(:,slot)=I;
    count=min(count+1,window);

    if count<window
        % Before the buffer fills, slots are populated in order 1:count.
        active=1:count;
        corr=Wbuf(:,active)'*I;
        G(active,slot)=corr;
        G(slot,active)=corr';
    else
        active=1:window;
        corr=Wbuf'*I;
        G(:,slot)=corr;
        G(slot,:)=corr';
    end

    doSubTrace=should_sample_subspace_trace(subTrace,t);
    if doSubTrace
        Uprev=U;
    end

    % GREAT upstream descent_step: update only once at least rank(U) samples
    % are present.  The gradient below is the exact full-window gradient.
    if count>=r
        W=Wbuf(:,active);

        % Exact sigma_1(W)^2 from the small Gram matrix.  Symmetrization only
        % removes floating-point skew accumulated by repeated assignments.
        Gactive=G(active,active);
        Gactive=0.5*(Gactive+Gactive');
        evals=eig(Gactive,'vector');
        sig1sq=max(max(real(evals)),1e-8);

        if isempty(opts.alpha)
            alpha=1.0/(4.0*sig1sq);
        else
            alpha=opts.alpha;
        end

        Y=U;
        for iter=1:K %#ok<NASGU>
            % Exact GREAT gradient for F_W(Y)=||(I-YY')W||_F^2:
            % grad F = -2 (I-YY') W W' Y.
            WtY=W'*Y;
            WWtY=W*WtY;
            grad=-2.0*(WWtY-Y*(Y'*WWtY));
            Y=manifold.exp(Y,-alpha*grad);
        end
        U=Y;
    end

    if doSubTrace
        tDiag=tic;
        subTrace=record_subspace_trace(subTrace,subDiag,U,Uprev,t);
        diagOverhead=diagOverhead+toc(tDiag);
    end

    % Foreground/background extraction after the subspace tracking update.
    [bg,fg]=extract_fg_bg_ista(I,U,opts.istaLambda,opts.istaIterations);
    if context.needBackground
        L(:,t)=bg;
    end
    snapSlot=snapMap(t);
    if snapSlot>0
        snapBg(:,snapSlot)=cast(bg,context.scoreClass);
    end
    if context.keepAuxiliaryMasks
        nativeSparse(:,t)=cast(fg,context.scoreClass);
    end
    score(:,t)=cast(abs(I-bg),context.scoreClass);
end

out=struct('L',L,'score',score,'Ufinal',U,'Uinitial',U0, ...
    'state',struct( ...
        'steps',step, ...
        'windowLength',window, ...
        'samplesRetained',count, ...
        'spectralBackend','exact-sliding-gram'), ...
    'initializationSource',initSource);

if subTrace.enabled
    out.diagnostics=struct('subspace',subTrace,'overheadSeconds',diagOverhead);
end
if context.keepAuxiliaryMasks
    out.nativeSparse=nativeSparse;
end
if ~isempty(snapIdx)
    out.snapshotBackground=snapBg;
    out.snapshotIndices=snapIdx;
end
if context.keepResidual && context.needBackground
    out.S=double(M)-L;
end
end
