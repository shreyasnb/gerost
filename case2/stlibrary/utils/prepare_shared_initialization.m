function init = prepare_shared_initialization(M, cfg)
%PREPARE_SHARED_INITIALIZATION Compute one SVD warm start for every method.
%
% The returned U0 is computed exactly once from the first cfg.trainFrames
% samples and should be passed unchanged to GRASTA, ReProCS, GREAT and
% GeRoST. Reusing this object avoids algorithm-specific re-initialization.

[n,T] = size(M);
requestedRank = max(1, round(cfg.rank));
r = min([requestedRank, n, T]);
tTrain = min(T, max(r, round(cfg.trainFrames)));

Xtrain = double(M(:,1:tTrain));
[U,S,~] = svd(Xtrain, 'econ');
r = min(r, size(U,2));
U0 = U(:,1:r);
s = diag(S);

init = struct();
init.U0 = U0;
init.rank = r;
init.trainingFrames = tTrain;
init.frameIndices = 1:tTrain;
init.method = 'rank-k SVD of common warm-up frames';
init.singularValues = s(1:min(r,numel(s)));
init.orthogonalityError = norm(U0' * U0 - eye(r), 'fro');
end
