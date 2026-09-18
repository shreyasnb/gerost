function tests = test_time_diagnostics
tests=functiontests(localfunctions);
end

function testChordalDistance(testCase)
U=[1 0;0 1;0 0;0 0];
V=U;
verifyEqual(testCase,subspace_chordal_distance(U,V,false),0,'AbsTol',1e-12);
W=[0 0;0 0;1 0;0 1];
verifyEqual(testCase,subspace_chordal_distance(U,W,true),1,'AbsTol',1e-12);
end

function testChordalIgnoresBasisScaling(testCase)
U=[1 0;0 1;0 0;0 0];
V=U*diag([3 0.2]);
verifyEqual(testCase,subspace_chordal_distance(U,V,true),0,'AbsTol',1e-12);
end

function testAutoDoesNotInventCdnetGroundTruth(testCase)
cfg=benchmark_config();
cfg.output.makeTimeMetricPdfs=true;
seq=struct('M',zeros(6,4),'numFrames',4);
shared=struct('U0',[eye(2);zeros(4,2)]);
d=prepare_subspace_diagnostics(seq,shared,cfg);
verifyTrue(testCase,d.enabled);
verifyEqual(testCase,d.referenceType,'none');
verifyFalse(testCase,d.referenceIsGroundTruth);
verifyEmpty(testCase,d.reference);
end

function testExplicitInitialProxyReference(testCase)
cfg=benchmark_config();
cfg.output.makeTimeMetricPdfs=true;
cfg.diagnostics.subspace.referenceMode='initial';
seq=struct('M',zeros(6,4),'numFrames',4);
shared=struct('U0',[eye(2);zeros(4,2)]);
d=prepare_subspace_diagnostics(seq,shared,cfg);
verifyEqual(testCase,d.referenceType,'fixed');
verifyFalse(testCase,d.referenceIsGroundTruth);
verifyTrue(testCase,contains(d.referenceLabel,'not ground truth'));
end

function testTrueReferencePreferred(testCase)
cfg=benchmark_config();
cfg.output.makeTimeMetricPdfs=true;
U=[eye(2);zeros(4,2)];
cfg.diagnostics.subspace.trueSubspace=U;
seq=struct('M',zeros(6,4),'numFrames',4);
shared=struct('U0',U);
d=prepare_subspace_diagnostics(seq,shared,cfg);
verifyTrue(testCase,d.referenceIsGroundTruth);
verifyEqual(testCase,d.referenceLabel,'true subspace');
end

function testFrameMetrics(testCase)
seq=struct();
seq.height=2; seq.width=2; seq.numFrames=2;
seq.frameNumbers=[10 11]; seq.evalFrame=[true true]; seq.roi=true(2,2);
seq.groundTruth=zeros(2,2,2,'uint8');
seq.groundTruth(:,:,1)=uint8([255 0;0 50]);
seq.groundTruth(:,:,2)=uint8([255 255;0 0]);
mask=false(4,2);
% MATLAB linear order for frame 1: [255;0;0;50]. Predict first pixel only.
mask(1,1)=true;
% Frame 2 linear order: [255;0;255;0]. Predict first and fourth.
mask([1 4],2)=true;
score=single(mask);
tr=compute_frame_metrics_over_time(score,mask,seq);
verifyEqual(testCase,tr.TPR(1),1,'AbsTol',1e-12);
verifyEqual(testCase,tr.FPR(1),0,'AbsTol',1e-12);
verifyEqual(testCase,tr.Precision(1),1,'AbsTol',1e-12);
verifyEqual(testCase,tr.TPR(2),0.5,'AbsTol',1e-12);
verifyEqual(testCase,tr.FPR(2),0.5,'AbsTol',1e-12);
end

function testRollingMetricsPoolCountsBeforeF1(testCase)
tr=struct();
tr.frameNumbers=[1 2]; tr.evalFrame=[true true];
% Frame 1: TP=1, FP=0, FN=0 => F1=1.
% Frame 2: TP=1, FP=8, FN=0 => F1=0.2.
% Mean per-frame F1 would be 0.6, but pooled F1 is 4/(4+8)=1/3.
tr.TP=[1 1]; tr.TN=[10 2]; tr.FP=[0 8]; tr.FN=[0 0];
tr.Precision=[1 1/9]; tr.TPR=[1 1]; tr.Recall=tr.TPR;
tr.Specificity=[1 0.2]; tr.FPR=[0 0.8]; tr.FNR=[0 0];
tr.PWC=[0 40]; tr.F1=[1 0.2]; tr.IoU=[1 1/9]; tr.MCC=[1 NaN];
tr.BalancedAccuracy=[1 0.6]; tr.PredictedForegroundFraction=[1/11 9/11];
tr.MeanForegroundScore=[1 1]; tr.MeanBackgroundScore=[0.1 0.1]; tr.ScoreRatio=[10 10];
tr.ForegroundScoreSum=[1 1]; tr.BackgroundScoreSum=[1 1];
tr.ForegroundScoreCount=[1 1]; tr.BackgroundScoreCount=[10 10];
r=rolling_frame_metrics(tr,2);
verifyEqual(testCase,r.F1(1),1/3,'AbsTol',1e-12);
verifyEqual(testCase,r.F1(2),1/3,'AbsTol',1e-12);
verifyNotEqual(testCase,r.F1(1),mean(tr.F1),'AbsTol',1e-12);
end

function testRocCurveMonotoneAndPerfect(testCase)
seq=struct();
seq.height=1; seq.width=4; seq.numFrames=1; seq.frameNumbers=1;
seq.evalFrame=true; seq.roi=true(1,4); seq.hasGroundTruth=true;
seq.groundTruth=reshape(uint8([255 255 0 0]),1,4,1);
score=single([0.9;0.8;0.2;0.1]);
c=roc_curve_histogram(score,seq,64);
verifyGreaterThanOrEqual(testCase,min(diff(c.FPR)),-1e-12);
verifyGreaterThanOrEqual(testCase,min(diff(c.TPR)),-1e-12);
verifyEqual(testCase,c.AUC,1,'AbsTol',2e-2);
end
