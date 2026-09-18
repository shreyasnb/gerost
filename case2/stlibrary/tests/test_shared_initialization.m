function tests = test_shared_initialization
tests=functiontests(localfunctions);
end

function testCommonSvdWarmStart(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); st_setup();
cfg=benchmark_config();
cfg.dataset.root=fullfile(root,'dataset','synthetic_demo');
cfg.dataset.category='baseline'; cfg.dataset.sequence='synthetic_square';
cfg.io.maxFrames=25; cfg.rank=3; cfg.trainFrames=10;
seq=load_cdnet_sequence(cfg.dataset.root,cfg.dataset.category,cfg.dataset.sequence,cfg);
init=prepare_shared_initialization(seq.M,cfg);
verifyEqual(testCase,init.rank,3);
verifyEqual(testCase,init.trainingFrames,10);
verifyLessThan(testCase,init.orthogonalityError,1e-10);
[U,~,~]=svd(double(seq.M(:,1:10)),'econ');
verifyLessThanOrEqual(testCase,norm(init.U0-U(:,1:3),'fro'),1e-12);
end

function testIstaReturnsConsistentBackground(testCase)
rng(7);
U=orth(randn(20,3)); y=randn(20,1);
[bg,fg,w]=extract_fg_bg_ista(y,U,0.1,5);
verifySize(testCase,bg,[20 1]);
verifySize(testCase,fg,[20 1]);
verifySize(testCase,w,[3 1]);
verifyLessThanOrEqual(testCase,norm(bg-U*w),1e-12);
verifyTrue(testCase,all(isfinite([bg;fg;w])));
end

function testResolverPrefersCanonicalSharedObject(testCase)
rng(11);
M=randn(40,12);
cfg=benchmark_config(); cfg.rank=3; cfg.trainFrames=6;
shared=prepare_shared_initialization(M,cfg);
opts=struct('rank',cfg.rank,'trainingFrames',cfg.trainFrames);
context=struct('sharedInitialization',shared); % deliberately no initialSubspace alias
[U0,tTrain,source]=resolve_initial_subspace(M,opts,context);
verifyEqual(testCase,U0,shared.U0,'AbsTol',1e-12);
verifyEqual(testCase,tTrain,shared.trainingFrames);
verifyEqual(testCase,string(source),"context.sharedInitialization.U0");
end

function testResolverLegacyFallback(testCase)
rng(12);
M=randn(30,10);
[Q,~]=qr(randn(30,2),0);
opts=struct('rank',2,'trainingFrames',5);
context=struct('initialSubspace',Q,'trainingFrames',5);
[U0,tTrain,source]=resolve_initial_subspace(M,opts,context);
verifyEqual(testCase,U0,Q,'AbsTol',1e-12);
verifyEqual(testCase,tTrain,5);
verifyTrue(testCase,contains(string(source),"legacy"));
end
