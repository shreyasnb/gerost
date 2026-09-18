function auc = roc_auc_histogram(score, seq, nBins)
%ROC_AUC_HISTOGRAM Memory-conscious pixel ROC AUC using score histograms.
curve = roc_curve_histogram(score, seq, nBins);
auc = curve.AUC;
end
