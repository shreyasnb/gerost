function tests = test_cdnet_metrics
tests=functiontests(localfunctions);
end
function testPerfect(testCase)
[H,W,T]=deal(4,5,3); gt=zeros(H,W,T,'uint8'); gt(2:3,2:3,:)=255;
seq=struct('hasGroundTruth',true,'groundTruth',gt,'roi',true(H,W), ...
    'evalFrame',true(1,T),'height',H,'width',W);
mask=reshape(gt==255,H*W,T); score=double(mask);
cfg=benchmark_config(); m=evaluate_cdnet(score,mask,seq,cfg);
verifyEqual(testCase,m.F1,1,'AbsTol',1e-12); verifyEqual(testCase,m.AUC,1,'AbsTol',2e-3);
end
function testShadowIsNegative(testCase)
gt=uint8([0 50;255 170]); seq=struct('hasGroundTruth',true,'groundTruth',reshape(gt,2,2,1), ...
    'roi',true(2,2),'evalFrame',true,'height',2,'width',2);
mask=logical([0;1;1;0]); score=double(mask); cfg=benchmark_config();
m=evaluate_cdnet(score,mask,seq,cfg); verifyEqual(testCase,m.FP,1); verifyEqual(testCase,m.TP,1);
end

function testNoEvaluationPixelsIsNaN(testCase)
gt=85*ones(2,2,1,'uint8');
seq=struct('hasGroundTruth',true,'groundTruth',gt,'roi',true(2,2), ...
    'evalFrame',true,'height',2,'width',2);
mask=false(4,1); score=zeros(4,1); cfg=benchmark_config();
m=evaluate_cdnet(score,mask,seq,cfg);
verifyTrue(testCase,isnan(m.F1)); verifyTrue(testCase,isnan(m.AUC));
end
