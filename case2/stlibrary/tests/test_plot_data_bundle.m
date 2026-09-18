function tests = test_plot_data_bundle
tests=functiontests(localfunctions);
end

function testBundleContainsOnlyCompactPlotQuantities(tc)
cfg=benchmark_config();
T=table("GREAT", "ok", 0.5, 0.9, 1.0, ...
    'VariableNames',{'Algorithm','Status','F1','AUC','Runtime'});
tr=struct('algorithm','GREAT','metrics',struct('frameNumbers',1:3,'TP',[1 2 3]), ...
    'roc',struct('FPR',[0 1],'TPR',[0 1],'AUC',0.5),'subspace',struct('enabled',false));
results={struct('algorithm','GREAT','snapshot',struct('frameNumbers',2, ...
    'original',single([1;2]),'foreground',single([0;1]),'background',single([1;1]), ...
    'height',2,'width',1))};
seq=struct('category','baseline','name','x','height',2,'width',1,'numFrames',3, ...
    'frameNumbers',1:3,'temporalROI',[1 3]);
shared=struct('U0',eye(2,1),'rank',1,'trainingFrames',1,'orthogonalityError',0);
p=build_plot_data_bundle(T,{tr},results,struct(),seq,cfg,shared);
verifyTrue(tc,istable(p.comparisonTable));
verifyEqual(tc,numel(p.timeTraces),1);
verifyEqual(tc,numel(p.snapshots),1);
verifyFalse(tc,isfield(p.sequence,'M'));
verifyFalse(tc,isfield(p.sequence,'groundTruth'));
verifyFalse(tc,isfield(p.initialization,'U0'));
end
