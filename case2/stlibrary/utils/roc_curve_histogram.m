function curve = roc_curve_histogram(score, seq, nBins)
%ROC_CURVE_HISTOGRAM Memory-conscious threshold-swept pixel ROC curve.
%
% The curve is accumulated from CDnet evaluation pixels only. It returns a
% small O(nBins) structure rather than storing pixel scores. Thresholds are
% swept from +Inf downward, so FPR and TPR are monotone nondecreasing.

if nargin < 3 || isempty(nBins), nBins = 1024; end
nBins = max(16, round(nBins));
curve = struct('FPR',[],'TPR',[],'Threshold',[],'AUC',NaN, ...
    'PositiveCount',0,'NegativeCount',0,'MaxScore',NaN);
if ~isfield(seq,'hasGroundTruth') || ~seq.hasGroundTruth, return; end

mx = 0;
for t = find(seq.evalFrame)
    gt = seq.groundTruth(:,:,t);
    valid = seq.roi & (gt==255 | gt==0 | gt==50);
    s = reshape(double(score(:,t)), seq.height, seq.width);
    v = s(valid & isfinite(s));
    if ~isempty(v), mx = max(mx, max(v)); end
end
if mx <= 0
    curve.FPR = [0 1]; curve.TPR = [0 1];
    curve.Threshold = [Inf 0]; curve.AUC = 0.5; curve.MaxScore = mx;
    return;
end

edges = linspace(0, mx, nBins+1);
hp = zeros(1,nBins); hn = zeros(1,nBins);
for t = find(seq.evalFrame)
    gt = seq.groundTruth(:,:,t);
    pos = gt==255; neg = (gt==0 | gt==50);
    valid = seq.roi & (pos | neg);
    s = reshape(double(score(:,t)), seq.height, seq.width);
    p = s(valid & pos & isfinite(s));
    n = s(valid & neg & isfinite(s));
    if ~isempty(p), hp = hp + histcounts(p,edges); end
    if ~isempty(n), hn = hn + histcounts(n,edges); end
end
P = sum(hp); N = sum(hn);
curve.PositiveCount = P; curve.NegativeCount = N; curve.MaxScore = mx;
if P==0 || N==0, return; end

% Enter bins from highest score to lowest score. The first point corresponds
% to threshold > max(score); the last corresponds to threshold <= 0.
curve.TPR = [0 cumsum(fliplr(hp))/P];
curve.FPR = [0 cumsum(fliplr(hn))/N];
curve.Threshold = [Inf fliplr(edges(1:end-1))];
curve.AUC = trapz(curve.FPR, curve.TPR);
end
