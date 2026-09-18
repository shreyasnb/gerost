function op = foreground_operating_point(score, threshold, seq)
%FOREGROUND_OPERATING_POINT Exact raw-score TPR/FPR at one threshold.
%
% This intentionally precedes optional morphology so the point belongs to
% the same score-threshold family as roc_curve_histogram.
TP=0; TN=0; FP=0; FN=0;
for t=find(seq.evalFrame)
    gt=seq.groundTruth(:,:,t);
    pos=gt==255; neg=(gt==0 | gt==50);
    valid=seq.roi & (pos | neg);
    s=reshape(double(score(:,t)),seq.height,seq.width);
    pred=s>=threshold;
    TP=TP+nnz(valid & pos & pred);
    FN=FN+nnz(valid & pos & ~pred);
    FP=FP+nnz(valid & neg & pred);
    TN=TN+nnz(valid & neg & ~pred);
end
op=struct('TPR',safe(TP,TP+FN),'FPR',safe(FP,FP+TN), ...
    'TP',double(TP),'TN',double(TN),'FP',double(FP),'FN',double(FN), ...
    'Threshold',double(threshold));
end

function y=safe(a,b)
if b<=0, y=NaN; else, y=double(a)/double(b); end
end
