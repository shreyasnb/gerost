function [U0, trainingFrames, source] = resolve_initial_subspace(M, opts, context)
%RESOLVE_INITIAL_SUBSPACE Return the benchmark-wide common warm-start basis.
%
% Priority:
%   1) context.sharedInitialization.U0  (canonical benchmark contract)
%   2) context.initialSubspace          (legacy compatibility alias)
%   3) deterministic SVD fallback using opts.rank/trainingFrames
%
% Adapters must not re-estimate or modify U0 when the canonical shared
% initialization is present. This keeps GRASTA, ReProCS, GREAT and GeRoST
% on exactly the same starting basis.

[n,T] = size(M);
source = '';
trainingFrames = [];

if isfield(context,'sharedInitialization') && ...
        isstruct(context.sharedInitialization) && ...
        isfield(context.sharedInitialization,'U0') && ...
        ~isempty(context.sharedInitialization.U0)
    U0 = double(context.sharedInitialization.U0);
    source = 'context.sharedInitialization.U0';
    if isfield(context.sharedInitialization,'trainingFrames')
        trainingFrames = context.sharedInitialization.trainingFrames;
    end
elseif isfield(context,'initialSubspace') && ~isempty(context.initialSubspace)
    U0 = double(context.initialSubspace);
    source = 'context.initialSubspace (legacy alias)';
elseif isfield(opts,'rank') && isfield(opts,'trainingFrames')
    r = min([max(1,round(opts.rank)), n, T]);
    trainingFrames = min(T,max(r,round(opts.trainingFrames)));
    [U,~,~] = svd(double(M(:,1:trainingFrames)),'econ');
    U0 = U(:,1:r);
    source = 'deterministic adapter SVD fallback';
else
    error('SubspaceBenchmark:MissingSharedInitialization', ...
        ['No common initial subspace was supplied. Call RUN_ALGORITHM or provide ' ...
         'context.sharedInitialization.U0.']);
end

if isempty(trainingFrames)
    if isfield(context,'trainingFrames') && ~isempty(context.trainingFrames)
        trainingFrames = context.trainingFrames;
    elseif isfield(opts,'trainingFrames') && ~isempty(opts.trainingFrames)
        trainingFrames = opts.trainingFrames;
    else
        trainingFrames = size(U0,2);
    end
end
trainingFrames = min(T,max(size(U0,2),round(trainingFrames)));

if size(U0,1) ~= n
    error('SubspaceBenchmark:InitialSubspaceDimension', ...
        'Initial subspace has %d rows but the data has %d pixels.',size(U0,1),n);
end
if isempty(U0) || size(U0,2) < 1 || any(~isfinite(U0(:)))
    error('SubspaceBenchmark:InvalidInitialSubspace', ...
        'The supplied initial subspace is empty or contains non-finite values.');
end
orthErr = norm(U0'*U0-eye(size(U0,2)),'fro');
if orthErr > 1e-8
    error('SubspaceBenchmark:InitialSubspaceNotOrthonormal', ...
        'Common initial subspace is not orthonormal (Frobenius error %.3e).',orthErr);
end
end
