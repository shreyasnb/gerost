function tests = test_algorithm_smoke
tests=functiontests(localfunctions);
end

function testAllInstalledAlgorithmsReturnScores(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); st_setup();
missing=check_dependencies(root);
assumeTrue(testCase,isempty(missing), ...
    sprintf('Third-party dependencies not installed: %s',strjoin(missing,', ')));

cfg=benchmark_config();
cfg.dataset.root=fullfile(root,'dataset','synthetic_demo');
cfg.dataset.category='baseline'; cfg.dataset.sequence='synthetic_square';
cfg.io.maxFrames=30; cfg.rank=2; cfg.trainFrames=8;
cfg.output.makeVideo=false; cfg.output.saveBackground=false;
cfg.execution.retainFullResults=false; cfg.execution.forceBackground=false;
cfg.method.GRASTA.trainingCycles=0;
cfg.method.ReProCS.alpha=4; cfg.method.ReProCS.K=1;
cfg.method.GREAT.window=8; cfg.method.GREAT.K=2;
cfg.method.GeRoST.window=8; cfg.method.GeRoST.K=2; cfg.method.GeRoST.dataRank=4;
seq=load_cdnet_sequence(cfg.dataset.root,cfg.dataset.category,cfg.dataset.sequence,cfg);
shared=prepare_shared_initialization(seq.M,cfg);
runContext=seq; runContext.sharedInitialization=shared;
for a=1:numel(cfg.algorithms)
    result=run_algorithm('ST',cfg.algorithms{a},seq.M,runContext,cfg);
    verifySize(testCase,result.score,size(seq.M));
    verifyTrue(testCase,all(isfinite(result.score(:))));
    verifySize(testCase,result.Uinitial,size(shared.U0));
    verifyLessThanOrEqual(testCase,norm(double(result.Uinitial)-double(shared.U0),'fro'),1e-12);
    verifyEqual(testCase,string(result.initializationSource),"context.sharedInitialization.U0");
    verifyTrue(testCase,isfield(result,'dataProvenance'));
    verifyEqual(testCase,result.dataProvenance.frameNumbers,seq.frameNumbers);
    verifyEqual(testCase,result.dataProvenance.inputFiles,seq.inputFiles);
end
end
