function out = rolling_frame_metrics(trace, window)
%ROLLING_FRAME_METRICS Confusion-matrix metrics over a rolling frame window.
%
% Unlike applying MOVMEAN to per-frame precision/F1/etc., this function
% first sums TP/TN/FP/FN over the local window and only then computes each
% nonlinear metric. This is the statistically meaningful rolling analogue
% of the sequence-level CDnet metrics.
%
% Frames outside trace.evalFrame remain NaN in the returned metric fields.

if nargin < 2 || isempty(window), window = 1; end
window = max(1, round(window));

TP = movsum(double(trace.TP), window, 'Endpoints', 'shrink');
TN = movsum(double(trace.TN), window, 'Endpoints', 'shrink');
FP = movsum(double(trace.FP), window, 'Endpoints', 'shrink');
FN = movsum(double(trace.FN), window, 'Endpoints', 'shrink');

out = struct();
out.frameNumbers = double(trace.frameNumbers(:)');
out.evalFrame = logical(trace.evalFrame(:)');
out.TP = TP; out.TN = TN; out.FP = FP; out.FN = FN;

out.Precision = ratio_with_zero_detection_rule(TP, TP + FP, TP + FN);
out.TPR = safe_ratio_vec(TP, TP + FN);
out.Recall = out.TPR;
out.Specificity = safe_ratio_vec(TN, TN + FP);
out.FPR = safe_ratio_vec(FP, FP + TN);
out.FNR = safe_ratio_vec(FN, FN + TP);
out.PWC = 100 * safe_ratio_vec(FP + FN, TP + TN + FP + FN);
out.F1 = safe_ratio_vec(2 * TP, 2 * TP + FP + FN);
out.IoU = safe_ratio_vec(TP, TP + FP + FN);
out.PredictedForegroundFraction = safe_ratio_vec(TP + FP, TP + TN + FP + FN);
out.BalancedAccuracy = 0.5 * (out.TPR + out.Specificity);

den = sqrt((TP + FP) .* (TP + FN) .* (TN + FP) .* (TN + FN));
out.MCC = nan(size(TP));
good = den > 0;
out.MCC(good) = (TP(good).*TN(good) - FP(good).*FN(good)) ./ den(good);

% Weighted score means. A MOVMEAN of per-frame means gives equal weight to
% quiet and busy frames; summing score mass and pixel counts is the correct
% rolling statistic. Fall back to the legacy per-frame means if an older
% trace is passed in.
if all(isfield(trace, {'ForegroundScoreSum','BackgroundScoreSum', ...
        'ForegroundScoreCount','BackgroundScoreCount'}))
    fgSum = movsum(zero_nonfinite(trace.ForegroundScoreSum), window, 'Endpoints', 'shrink');
    bgSum = movsum(zero_nonfinite(trace.BackgroundScoreSum), window, 'Endpoints', 'shrink');
    fgCount = movsum(double(trace.ForegroundScoreCount), window, 'Endpoints', 'shrink');
    bgCount = movsum(double(trace.BackgroundScoreCount), window, 'Endpoints', 'shrink');
    out.MeanForegroundScore = safe_ratio_vec(fgSum, fgCount);
    out.MeanBackgroundScore = safe_ratio_vec(bgSum, bgCount);
else
    out.MeanForegroundScore = smooth_legacy(trace.MeanForegroundScore, window);
    out.MeanBackgroundScore = smooth_legacy(trace.MeanBackgroundScore, window);
end
out.ScoreRatio = out.MeanForegroundScore ./ max(out.MeanBackgroundScore, eps);
out.ScoreRatio(~isfinite(out.MeanForegroundScore) | ~isfinite(out.MeanBackgroundScore)) = NaN;

% Never draw rolling-window values on non-evaluation frames. Counts remain
% available for debugging but all derived metric/score fields are masked.
metricFields = {'Precision','TPR','Recall','Specificity','FPR','FNR','PWC', ...
    'F1','IoU','MCC','BalancedAccuracy','PredictedForegroundFraction', ...
    'MeanForegroundScore','MeanBackgroundScore','ScoreRatio'};
for i = 1:numel(metricFields)
    v = out.(metricFields{i});
    v(~out.evalFrame) = NaN;
    out.(metricFields{i}) = v;
end
end

function y = safe_ratio_vec(a,b)
y = nan(size(a));
good = b > 0;
y(good) = a(good) ./ b(good);
end

function y = ratio_with_zero_detection_rule(tp, detected, actualPositive)
y = safe_ratio_vec(tp, detected);
noDetectionButPositive = detected == 0 & actualPositive > 0;
y(noDetectionButPositive) = 0;
end

function x = zero_nonfinite(x)
x = double(x(:)');
x(~isfinite(x)) = 0;
end

function y = smooth_legacy(y,window)
y = double(y(:)');
valid = isfinite(y);
if window > 1
    y = movmean(y, window, 'omitnan', 'Endpoints', 'shrink');
end
y(~valid) = NaN;
end
