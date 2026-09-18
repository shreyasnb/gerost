function cfg = benchmark_config()
%BENCHMARK_CONFIG Reproducible defaults for the CDnet ST benchmark.

root = fileparts(mfilename('fullpath'));

plot_settings();

cfg.projectRoot = root;
cfg.randomSeed = 42;
cfg.rank = 5;
cfg.trainFrames = 50;
cfg.algorithms = {'GRASTA','GREAT','GeRoST'};

cfg.dataset.root = fullfile(root, 'dataset', 'cdnet2014', 'dataset');
cfg.dataset.category = 'baseline';
cfg.dataset.sequence = 'highway';
cfg.dataset.categories = {'baseline'};
cfg.dataset.sequences = {'all'};

cfg.io.maxFrames = inf;
cfg.io.frameStride = 1;
cfg.io.resizeScale = 1;
cfg.io.frameRange = [];           % native CDnet frame numbers [first last], [] = all
cfg.io.dataType = 'single';        % input video matrix; adapters promote frames as needed

cfg.foreground.thresholdMode = 'mad';   % 'mad' or 'fixed'
cfg.foreground.madMultiplier = 6.0;
cfg.foreground.minThreshold = 0.02;     % intensities are in [0,1]
cfg.foreground.fixedThreshold = 0.08;
cfg.foreground.useMorphology = false;
cfg.foreground.minArea = 0;
cfg.foreground.aucBins = 1024;

cfg.output.root = fullfile(root, 'output');
cfg.output.saveMat = true;
cfg.output.saveMasks = false;
cfg.output.saveBackground = false;
cfg.output.saveScores = false;
% Save one compact, self-contained plotting bundle after each benchmark.
% This contains only data required to regenerate figures (tables/scalar
% traces/ROC histograms/one snapshot), never full video or background
% histories. Set false for the absolute minimum diagnostic overhead.
cfg.output.savePlotData = true;
cfg.output.plotDataFileName = 'plot_data.mat';
cfg.output.makeComparisonPlot = true;
cfg.output.makeVideo = false;
cfg.output.videoFrameRate = 12;
% Lightweight publication snapshot: adapters retain only the requested
% background frame, not the full n-by-T background matrix.
cfg.output.makeSnapshotPdf = false;
cfg.output.snapshotFrame = [];       % native frame(s), e.g. [700 1000 1300]; [] -> temporal-ROI midpoint
cfg.output.snapshotAlgorithms = {'GRASTA','GREAT','GeRoST'};
cfg.output.snapshotPdfName = '';     % []/'' -> fg_bg_snapshot_frameXXXXXX.pdf

% Lightweight time-resolved diagnostics. Only scalar traces are held in
% memory long enough to create the PDFs; raw masks/backgrounds/subspaces are
% not written unless separately requested.
cfg.output.makeTimeMetricPdfs = false;
cfg.output.timeMetricAlgorithms = {'GRASTA','ReProCS','GREAT','GeRoST'};
cfg.output.timeMetricPrefix = '';    % optional filename prefix

% GeRoST-only robustness diagnostics. This writes one compact vector PDF
% from scalar histories already produced by the tracker; no masks,
% backgrounds, or subspace histories are saved.
cfg.output.makeGeRoSTRobustnessPdf = false;
cfg.output.gerostRobustnessPdfName = 'gerost_rho_lambda_xi.pdf';

cfg.diagnostics.smoothingWindow = 15;       % frames pooled before nonlinear metrics are computed
cfg.diagnostics.plotRawFrameMetrics = false;
cfg.diagnostics.saveTraceData = false;      % do not duplicate traces in per-algorithm result.mat; plot_data.mat handles replotting
cfg.diagnostics.subspace.enabled = true;
cfg.diagnostics.subspace.referenceMode = 'auto'; % auto uses truth/reference if supplied; CDnet otherwise plots update magnitude only
cfg.diagnostics.subspace.trueSubspace = [];       % n-by-r fixed ground-truth basis
cfg.diagnostics.subspace.trueSubspaceHistory = []; % n-by-r-by-T optional trajectory
cfg.diagnostics.subspace.referenceSubspace = [];  % n-by-r user reference (not necessarily truth)
cfg.diagnostics.subspace.referenceHistory = [];   % n-by-r-by-T user reference trajectory
cfg.diagnostics.subspace.referenceLabel = '';
cfg.diagnostics.subspace.normalizeChordal = true; % normalized projector/chordal distance
cfg.diagnostics.subspace.sampleStride = 5;      % compute chordal traces every N frames
cfg.diagnostics.subspace.computeStepDistance = true;

% Robustness-plot presentation only. xi is the observable frame-wise proxy
% used by the current CDnet adapter, not the inaccessible theoretical xi_t.
cfg.diagnostics.gerostRobustness.smoothingWindow = 1; % 1 = raw traces
cfg.diagnostics.gerostRobustness.showCap = true;
cfg.diagnostics.gerostRobustness.showTrainingMarker = true;
cfg.diagnostics.gerostRobustness.showEvaluationMarker = true;

cfg.execution.failFast = false;
cfg.execution.retainFullResults = false;
cfg.execution.keepResidual = false;       % do not retain a dense S matrix by default
cfg.execution.forceBackground = false;    % process_video sets this internally
cfg.execution.scoreClass = 'single';      % halves score-matrix memory with negligible metric impact
cfg.execution.verbose = true;

% GRASTA receives the same shared SVD U0 as every other method. Its normal
% first-call random initialization and private training passes are disabled.
cfg.method.GRASTA.rank = cfg.rank;
cfg.method.GRASTA.trainingFrames = cfg.trainFrames;
cfg.method.GRASTA.trainingCycles = 0; % shared SVD warm start replaces private pre-training
cfg.method.GRASTA.subsampling = 1;
cfg.method.GRASTA.rho = 1.8;
cfg.method.GRASTA.maxMu = 15;
cfg.method.GRASTA.minMu = 1;
cfg.method.GRASTA.iterMin = 5;
cfg.method.GRASTA.iterMax = 20;
cfg.method.GRASTA.tol = 1e-7;
cfg.method.GRASTA.profile = 'lrslibrary';     % LRSLibrary online rule, but with the common U0
cfg.method.GRASTA.initialStepScale = 1e-2; % used only by profile='gerostCase2'
cfg.method.GRASTA.constantStep = 1e-2;      % used by profile='lrslibrary'
cfg.method.GRASTA.onlineAdmmIterations = 20;% LRSLibrary online solve budget after its training phase
cfg.method.GRASTA.scoreMode = 'residual';   % matches LRSLibrary and GeRoST-paper ROC definition
cfg.method.GRASTA.quiet = true;
cfg.method.GRASTA.useMex = false;

% ReProCS: projected-CS update, memory-safe support-restricted projector.
cfg.method.ReProCS.rank = cfg.rank;
cfg.method.ReProCS.trainingFrames = cfg.trainFrames;
cfg.method.ReProCS.useRobustInit = false; % retained for compatibility; bypassed by shared U0
cfg.method.ReProCS.alpha = 60;
cfg.method.ReProCS.K = 3;
cfg.method.ReProCS.thetaDeg = 20;
cfg.method.ReProCS.evScale = 0.1;
cfg.method.ReProCS.yallTol = 1e-3;
cfg.method.ReProCS.cglsTol = 1e-3;

% GREAT / GeRoST defaults follow the foreground-background flow in
% shreyasnb/GeRoST/case2/bg_fg_main.m. The upstream synthetic experiment
% uses window=30, K=5, d=k+2, adaptive rho for GeRoST, and five ISTA steps.
% Because this benchmark scales CDnet intensities to [0,1], the ISTA
% shrinkage lambda is correspondingly much smaller than the upstream
% synthetic example's value of 1.0.
cfg.method.GREAT.rank = cfg.rank;
cfg.method.GREAT.trainingFrames = cfg.trainFrames;
cfg.method.GREAT.window = 30;
cfg.method.GREAT.K = 5;
cfg.method.GREAT.alpha = [];
cfg.method.GREAT.istaLambda = 0.02;
cfg.method.GREAT.istaIterations = 5;

cfg.method.GeRoST.rank = cfg.rank;
cfg.method.GeRoST.trainingFrames = cfg.trainFrames;
cfg.method.GeRoST.dataRank = [];           % [] -> rank + dataRankOffset
cfg.method.GeRoST.dataRankOffset = 2;      % upstream case2 uses d=k+2
cfg.method.GeRoST.window = 30;
cfg.method.GeRoST.K = 5;
cfg.method.GeRoST.adaptiveRho = true;
cfg.method.GeRoST.rho = 0.1;               % used only when adaptiveRho=false
cfg.method.GeRoST.rhoNsrCap = 0.15;        % upstream case2 cap on instantaneous NSR
cfg.method.GeRoST.rhoScale = sqrt(2);      % rho_t = scale*p/(1-p)
cfg.method.GeRoST.alpha = [];
cfg.method.GeRoST.fallback = 'data';
cfg.method.GeRoST.innerMaxImplementation = 'reduced'; % exact low-rank span([Y,What]) implementation
cfg.method.GeRoST.bisectTol = 1e-6;        % paper complexity remark uses ~1e-6, not upstream code's 1e-12
cfg.method.GeRoST.bisectMaxIter = 32;
cfg.method.GeRoST.profileTiming = false;
cfg.method.GeRoST.istaLambda = 0.02;
cfg.method.GeRoST.istaIterations = 5;
end
