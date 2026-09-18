function m = compute_metrics(TP,TN,FP,FN)
%COMPUTE_METRICS Standard foreground segmentation metrics.
sdiv=@(a,b) a./max(b,eps);
precision=sdiv(TP,TP+FP); recall=sdiv(TP,TP+FN); specificity=sdiv(TN,TN+FP);
fpr=sdiv(FP,FP+TN); fnr=sdiv(FN,FN+TP); pwc=100*sdiv(FP+FN,TP+TN+FP+FN);
f1=sdiv(2*precision*recall,precision+recall); iou=sdiv(TP,TP+FP+FN);
den=sqrt(double(TP+FP)*double(TP+FN)*double(TN+FP)*double(TN+FN));
mcc=sdiv(double(TP)*double(TN)-double(FP)*double(FN),den);
m=struct('Algorithm',"",'Status',"ok",'Precision',precision,'Recall',recall, ...
    'Specificity',specificity,'FPR',fpr,'FNR',fnr,'PWC',pwc,'F1',f1,'IoU',iou, ...
    'MCC',mcc,'AUC',NaN,'TP',double(TP),'TN',double(TN),'FP',double(FP),'FN',double(FN), ...
    'Runtime',NaN,'FPS',NaN,'Threshold',NaN);
end
