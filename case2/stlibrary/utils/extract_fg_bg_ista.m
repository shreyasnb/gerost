function [bg, fg, w] = extract_fg_bg_ista(y, U, lambda, numIterations)
%EXTRACT_FG_BG_ISTA Sparse foreground / subspace background decomposition.
%
% Mirrors the helper used in shreyasnb/GeRoST/case2/bg_fg_main.m:
%   w <- U' y
%   repeat: soft-threshold y-Uw, then refit w to y-fg
%   bg <- U w
%
% lambda must be expressed in the same intensity units as y. CDnet frames
% in this benchmark are scaled to [0,1], so lambda is typically much lower
% than the value 1.0 used by the upstream synthetic example.

if nargin < 4 || isempty(numIterations), numIterations = 5; end
if nargin < 3 || isempty(lambda), lambda = 0; end
lambda = max(double(lambda), 0);
numIterations = max(1, round(numIterations));

w = U' * y;
fg = zeros(size(y));
for iter = 1:numIterations %#ok<NASGU>
    residual = y - U * w;
    fg = sign(residual) .* max(abs(residual) - lambda, 0);
    w = U' * (y - fg);
end
bg = U * w;
end
