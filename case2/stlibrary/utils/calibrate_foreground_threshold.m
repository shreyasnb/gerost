function threshold = calibrate_foreground_threshold(score, seq, cfg)
%CALIBRATE_FOREGROUND_THRESHOLD Ground-truth-free robust threshold calibration.
if strcmpi(cfg.foreground.thresholdMode,'fixed')
    threshold=cfg.foreground.fixedThreshold; return;
end
% Prefer frames before CDnet's temporal evaluation ROI. If unavailable, use
% the first configured training frames. Sample spatially for memory stability.
if isfield(seq,'temporalEvalFrame')
    idx=find(~seq.temporalEvalFrame);
else
    idx=find(~seq.evalFrame);
end
if isempty(idx), idx=1:min(seq.numFrames,cfg.trainFrames); end
if isfield(seq,'roi'), spatial=seq.roi(:); else, spatial=true(size(score,1),1); end
x=score(spatial,idx);
if numel(x)>2e6
    step=ceil(numel(x)/2e6); x=x(1:step:end);
else
    x=x(:);
end
x=x(isfinite(x));
if isempty(x), threshold=cfg.foreground.minThreshold; return; end
med=median(x);
mad0=median(abs(x-med));
sigma=1.4826*mad0;
threshold=max(cfg.foreground.minThreshold, med + cfg.foreground.madMultiplier*sigma);
end
