function plotData = build_plot_data_bundle(T, timeTraces, results, gerostResult, seq, cfg, sharedInit)
%BUILD_PLOT_DATA_BUNDLE Create the compact self-contained figure data file.
%
% The bundle intentionally stores only quantities needed for plotting:
%   * final comparison table,
%   * per-frame confusion-count/score summaries and ROC histograms,
%   * sampled scalar subspace diagnostics,
%   * one requested input/foreground/background snapshot per algorithm,
%   * GeRoST xi-hat/rho/lambda scalar histories.
% It never stores full M, ground-truth volumes, masks, score videos, full
% background matrices, or estimated subspace histories.

plotData=struct();
plotData.schemaVersion=1;
plotData.benchmarkVersion=benchmark_version();
plotData.created=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
plotData.comparisonTable=T;
plotData.timeTraces=compact_trace_cells(timeTraces);
plotData.snapshots=compact_snapshots(results);
plotData.gerostResult=gerostResult;
plotData.sequence=compact_sequence(seq);
plotData.initialization=compact_initialization(sharedInit);
plotData.plotConfig=compact_plot_config(cfg);
plotData.notes=[ ...
    "plot_data.mat contains plotting-only data; it is not a full benchmark result archive."; ...
    "CDnet subspace diagnostics are update magnitudes unless an explicit true/reference subspace was supplied."];
end

function c=compact_trace_cells(traces)
c={};
for i=1:numel(traces)
    if isstruct(traces{i}) && ~isempty(fieldnames(traces{i}))
        c{end+1,1}=traces{i}; %#ok<AGROW>
    end
end
end

function c=compact_snapshots(results)
c={};
for i=1:numel(results)
    r=results{i};
    if ~isstruct(r) || ~isfield(r,'algorithm') || ~isfield(r,'snapshot') || isempty(r.snapshot)
        continue;
    end
    c{end+1,1}=struct('algorithm',r.algorithm,'snapshot',r.snapshot); %#ok<AGROW>
end
end

function s=compact_sequence(seq)
s=struct();
names={'category','name','height','width','numFrames','frameNumbers','frameStride', ...
    'temporalROI','path','roiFile','temporalROIFile'};
for i=1:numel(names)
    if isfield(seq,names{i}), s.(names{i})=seq.(names{i}); end
end
end

function s=compact_initialization(sharedInit)
s=sharedInit;
if isfield(s,'U0'), s=rmfield(s,'U0'); end
end

function pc=compact_plot_config(cfg)
pc=struct();
pc.output=struct();
outNames={'timeMetricAlgorithms','timeMetricPrefix','snapshotAlgorithms','snapshotPdfName', ...
    'gerostRobustnessPdfName'};
for i=1:numel(outNames)
    f=outNames{i};
    if isfield(cfg.output,f), pc.output.(f)=cfg.output.(f); end
end
pc.diagnostics=struct();
diagNames={'smoothingWindow','plotRawFrameMetrics'};
for i=1:numel(diagNames)
    f=diagNames{i};
    if isfield(cfg.diagnostics,f), pc.diagnostics.(f)=cfg.diagnostics.(f); end
end
if isfield(cfg.diagnostics,'gerostRobustness')
    pc.diagnostics.gerostRobustness=cfg.diagnostics.gerostRobustness;
end
pc.foreground=struct();
if isfield(cfg,'foreground') && isfield(cfg.foreground,'aucBins')
    pc.foreground.aucBins=cfg.foreground.aucBins;
end
end
