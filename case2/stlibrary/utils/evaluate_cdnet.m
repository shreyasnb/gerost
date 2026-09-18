function metrics = evaluate_cdnet(score, mask, seq, cfg)
%EVALUATE_CDNET Evaluate CDnet labels and histogram ROC AUC.
if ~seq.hasGroundTruth
    metrics=blank_metrics(); return;
end
TP=0;TN=0;FP=0;FN=0;
for t=find(seq.evalFrame)
    gt=seq.groundTruth(:,:,t);
    pos=gt==255;
    neg=(gt==0 | gt==50);
    valid=seq.roi & (pos | neg);
    pred=reshape(mask(:,t),seq.height,seq.width);
    TP=TP+nnz(valid & pos & pred);
    FN=FN+nnz(valid & pos & ~pred);
    FP=FP+nnz(valid & neg & pred);
    TN=TN+nnz(valid & neg & ~pred);
end
if TP+TN+FP+FN==0
    metrics=blank_metrics(); return;
end
metrics=compute_metrics(TP,TN,FP,FN);
metrics.AUC=roc_auc_histogram(score,seq,cfg.foreground.aucBins);
end

function m=blank_metrics()
m=compute_metrics(0,0,0,0);
fields={'Precision','Recall','Specificity','FPR','FNR','PWC','F1','IoU','MCC','AUC'};
for i=1:numel(fields), m.(fields{i})=NaN; end
end
