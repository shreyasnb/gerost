function trace = compute_frame_metrics_over_time(score, mask, seq)
%COMPUTE_FRAME_METRICS_OVER_TIME Per-frame CDnet confusion counts/diagnostics.
%
% MASK is the already-thresholded/postprocessed n-by-T logical prediction.
% SCORE is the continuous foreground score and is used only to summarize
% score separation on true foreground/background pixels. Frames outside
% CDnet's evaluation interval are left NaN for derived metrics.
%
% TP/TN/FP/FN and score sums/counts are also retained temporarily so plots
% can form statistically correct rolling-window metrics. Averaging F1,
% precision, etc. directly across frames is not equivalent to computing the
% metric on the pooled pixels in a time window.

T=seq.numFrames;
trace=struct();
trace.frameNumbers=double(seq.frameNumbers(:)');
trace.evalFrame=logical(seq.evalFrame(:)');
fields={'Precision','TPR','Recall','Specificity','FPR','FNR','PWC','F1','IoU', ...
    'MCC','BalancedAccuracy','PredictedForegroundFraction', ...
    'MeanForegroundScore','MeanBackgroundScore','ScoreRatio'};
for i=1:numel(fields), trace.(fields{i})=nan(1,T); end
trace.TP=zeros(1,T); trace.TN=zeros(1,T); trace.FP=zeros(1,T); trace.FN=zeros(1,T);
trace.ForegroundPixelCount=zeros(1,T);
trace.BackgroundPixelCount=zeros(1,T);
trace.ForegroundScoreCount=zeros(1,T);
trace.BackgroundScoreCount=zeros(1,T);
trace.ForegroundScoreSum=zeros(1,T);
trace.BackgroundScoreSum=zeros(1,T);

for t=find(trace.evalFrame)
    gt=seq.groundTruth(:,:,t);
    pos=gt==255;
    neg=(gt==0 | gt==50);
    valid=seq.roi & (pos | neg);
    if ~any(valid(:)), continue; end
    pred=reshape(logical(mask(:,t)),seq.height,seq.width);
    TP=nnz(valid & pos & pred); FN=nnz(valid & pos & ~pred);
    FP=nnz(valid & neg & pred); TN=nnz(valid & neg & ~pred);
    trace.TP(t)=TP; trace.TN(t)=TN; trace.FP(t)=FP; trace.FN(t)=FN;
    trace.ForegroundPixelCount(t)=TP+FN;
    trace.BackgroundPixelCount(t)=TN+FP;
    if TP+FP>0
        precision=double(TP)/double(TP+FP);
    elseif TP+FN>0
        precision=0; % no detections on a frame that contains foreground
    else
        precision=NaN;
    end
    recall=safe_ratio(TP,TP+FN);
    specificity=safe_ratio(TN,TN+FP);
    fpr=safe_ratio(FP,FP+TN);
    fnr=safe_ratio(FN,FN+TP);
    pwc=100*safe_ratio(FP+FN,TP+TN+FP+FN);
    f1=safe_ratio(2*TP,2*TP+FP+FN);
    iou=safe_ratio(TP,TP+FP+FN);
    den=sqrt(double(TP+FP)*double(TP+FN)*double(TN+FP)*double(TN+FN));
    if den>0, mcc=(double(TP)*double(TN)-double(FP)*double(FN))/den; else, mcc=NaN; end
    trace.Precision(t)=precision;
    trace.TPR(t)=recall; trace.Recall(t)=recall;
    trace.Specificity(t)=specificity; trace.FPR(t)=fpr; trace.FNR(t)=fnr;
    trace.PWC(t)=pwc; trace.F1(t)=f1; trace.IoU(t)=iou; trace.MCC(t)=mcc;
    if isfinite(recall) && isfinite(specificity)
        trace.BalancedAccuracy(t)=0.5*(recall+specificity);
    end
    trace.PredictedForegroundFraction(t)=safe_ratio(TP+FP,TP+TN+FP+FN);

    if nargin>=1 && ~isempty(score)
        s=reshape(double(score(:,t)),seq.height,seq.width);
        sp=s(valid & pos & isfinite(s)); sn=s(valid & neg & isfinite(s));
        trace.ForegroundScoreCount(t)=numel(sp);
        trace.BackgroundScoreCount(t)=numel(sn);
        if ~isempty(sp)
            trace.ForegroundScoreSum(t)=sum(sp);
            trace.MeanForegroundScore(t)=trace.ForegroundScoreSum(t)/numel(sp);
        end
        if ~isempty(sn)
            trace.BackgroundScoreSum(t)=sum(sn);
            trace.MeanBackgroundScore(t)=trace.BackgroundScoreSum(t)/numel(sn);
        end
        if isfinite(trace.MeanForegroundScore(t)) && isfinite(trace.MeanBackgroundScore(t))
            trace.ScoreRatio(t)=trace.MeanForegroundScore(t)/max(trace.MeanBackgroundScore(t),eps);
        end
    end
end
end

function y=safe_ratio(a,b)
if b<=0, y=NaN; else, y=double(a)/double(b); end
end
