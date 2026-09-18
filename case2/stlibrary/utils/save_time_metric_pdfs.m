function files = save_time_metric_pdfs(traces, outDir, cfg)
%SAVE_TIME_METRIC_PDFS Save corrected time/frame-resolved diagnostics as PDFs.
%
% Important statistical details:
%   * Smoothed segmentation metrics are computed from rolling sums of
%     TP/TN/FP/FN, not from MOVMEAN(metric). Nonlinear metrics such as F1
%     and precision must be recomputed after pooling the window counts.
%   * Foreground/background score means are pixel-count weighted over the
%     rolling window.
%   * The ROC is a genuine threshold-swept pixel ROC accumulated over all
%     CDnet evaluation pixels. Frame-wise operating points are not connected
%     into a pseudo-ROC trajectory.
%   * CDnet has no ground-truth latent subspace. In auto reference mode only
%     subspace update magnitude is plotted unless truth/reference is supplied.

if nargin<3, error('cfg is required.'); end
if ~isfolder(outDir), mkdir(outDir); end
selected=select_traces(traces,cfg);
files=struct('segmentation','','roc','','scores','','subspace','');
if isempty(selected), return; end

prefix='';
if isfield(cfg.output,'timeMetricPrefix') && ~isempty(cfg.output.timeMetricPrefix)
    prefix=char(string(cfg.output.timeMetricPrefix));
    if ~endsWith(prefix,'_'), prefix=[prefix '_']; end
end
if isfield(cfg,'diagnostics') && isfield(cfg.diagnostics,'smoothingWindow')
    smoothWindow=max(1,round(cfg.diagnostics.smoothingWindow));
else
    smoothWindow=1;
end
plotRaw=isfield(cfg,'diagnostics') && isfield(cfg.diagnostics,'plotRawFrameMetrics') && ...
    logical(cfg.diagnostics.plotRawFrameMetrics);

% Remove the obsolete connected frame-wise TPR/FPR trajectory so an old
% pseudo-ROC cannot be mistaken for the corrected threshold-swept ROC.
legacyRoc=fullfile(outDir,[prefix 'tpr_vs_fpr_by_frame.pdf']);
if isfile(legacyRoc), delete(legacyRoc); end

files.segmentation=fullfile(outDir,[prefix 'segmentation_metrics_vs_frame.pdf']);
plot_metric_grid(selected,files.segmentation,smoothWindow,plotRaw);
files.roc=fullfile(outDir,[prefix 'roc_curve.pdf']);
plot_roc(selected,files.roc,cfg);
files.scores=fullfile(outDir,[prefix 'foreground_score_vs_frame.pdf']);
plot_score_traces(selected,files.scores,smoothWindow,plotRaw);

if any(cellfun(@has_subspace_trace,selected))
    files.subspace=fullfile(outDir,[prefix 'subspace_distance_vs_frame.pdf']);
    plot_subspace_traces(selected,files.subspace,smoothWindow,plotRaw);
end
end

function selected=select_traces(traces,cfg)
selected={};
if isempty(traces), return; end
filter={};
if isfield(cfg.output,'timeMetricAlgorithms') && ~isempty(cfg.output.timeMetricAlgorithms)
    filter=cfg.output.timeMetricAlgorithms;
    if isstring(filter), filter=cellstr(filter); end
    if ischar(filter), filter={filter}; end
end
for i=1:numel(traces)
    d=traces{i};
    if ~isstruct(d) || ~isfield(d,'algorithm') || ~isfield(d,'metrics'), continue; end
    if ~isempty(filter) && ~any(strcmpi(d.algorithm,filter)), continue; end
    selected{end+1}=d; %#ok<AGROW>
end
end

function plot_metric_grid(selected,filename,w,plotRaw)
f=figure('Visible','off','Color','w','Position',[60 60 1500 1050]);
cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
tl=tiledlayout(f,3,3,'Padding','compact','TileSpacing','compact');
metrics={ ...
    'Precision','Precision',[0 1]; ...
    'TPR','TPR / Recall',[0 1]; ...
    'FPR','FPR',[0 1]; ...
    'Specificity','Specificity',[0 1]; ...
    'F1','F1',[0 1]; ...
    'IoU','IoU',[0 1]; ...
    'MCC','MCC',[-1 1]; ...
    'PWC','PWC (%)',[0 NaN]; ...
    'BalancedAccuracy','Balanced accuracy',[0 1]};
rolled=cell(size(selected));
for i=1:numel(selected)
    rolled{i}=rolling_frame_metrics(selected{i}.metrics,w);
end
for k=1:size(metrics,1)
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    for i=1:numel(selected)
        d=selected{i}; r=rolled{i};
        if plotRaw
            plot(ax,d.metrics.frameNumbers,d.metrics.(metrics{k,1}), ...
                'LineWidth',0.25,'HandleVisibility','off');
        end
        plot(ax,r.frameNumbers,r.(metrics{k,1}),'LineWidth',1.35, ...
            'DisplayName',d.algorithm);
    end
    ylabel(ax,metrics{k,2}); xlabel(ax,'Native frame number');
    set_eval_xlim(ax,selected);
    lim=metrics{k,3};
    if all(isfinite(lim))
        ylim(ax,lim);
    elseif isfinite(lim(1))
        ylim(ax,[lim(1) max_reasonable_ylim(ax,lim(1))]);
    end
    if k==1, legend(ax,'Location','best','Interpreter','none'); end
end
if w<=1
    desc='Per-frame CDnet metrics';
else
    desc=sprintf('CDnet metrics over a %d-frame pooled window',w);
end
sgtitle(tl,desc,'FontWeight','bold');
exportgraphics(f,filename,'ContentType','vector');
end

function plot_roc(selected,filename,cfg)
% Genuine threshold-swept pixel ROC with an inset magnifying the low-FPR
% operating region. This is one ROC figure: the inset re-plots the boxed
% region of the same curves and does not represent a second metric.
opt=roc_plot_options(cfg,selected);
f=figure('Visible','off','Color','w','Position',[80 80 1200 600]);
cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>

% Main ROC occupies a square plot box so figure-normalized connector
% coordinates are stable when exported to vector PDF.
ax=axes(f,'Units','normalized','Position',[0.105 0.105 0.79 0.79]);
set(ax,'TickLabelInterpreter','latex', 'FontSize',27);
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
curveColors=nan(numel(selected),3);
for i=1:numel(selected)
    d=selected{i};
    if ~isfield(d,'roc') || ~isstruct(d.roc) || isempty(d.roc.FPR), continue; end
    auc=d.roc.AUC;
    label=sprintf('%s (AUC %.4f)',d.algorithm,auc);
    h=plot(ax,double(d.roc.FPR),double(d.roc.TPR),'LineWidth',3, ...
        'DisplayName',label);
    curveColors(i,:)=h.Color;
    if isfield(d,'operatingPoint') && numel(d.operatingPoint)>=2 && ...
            all(isfinite(d.operatingPoint(1:2)))
        scatter(ax,d.operatingPoint(1),d.operatingPoint(2),60,'o', ...
            'MarkerEdgeColor',h.Color,'MarkerFaceColor',h.Color, ...
            'HandleVisibility','off');
    end
end
plot(ax,[0 1],[0 1],'k--', ...
    'HandleVisibility','off', 'LineWidth',1.8);
xlim(ax,[0 1]); ylim(ax,[0 1]);
% axis(ax,'square');
xlabel(ax,'False Positive Rate', 'Interpreter','latex','FontSize',27);
ylabel(ax,'True Positive Rate', 'Interpreter','latex', 'FontSize',27);
% title(ax,'Pixel ROC over the CDnet evaluation region - threshold sweep', ...
%     'FontWeight','bold');
% subtitle(ax,'Inset magnifies the boxed low-FPR region; filled circles mark the fixed benchmark thresholds.');
lgd = legend(ax,'Location','best','Interpreter','latex', 'FontSize',23);
lgd.Position = [0.57, 0.2, 0.32, 0.1];

if opt.showMagnifier
    % Box the region enlarged by the inset on the main axes.
    rectangle(ax,'Position',[0 opt.zoomTprMin opt.zoomFprMax 1-opt.zoomTprMin], ...
        'EdgeColor',[0.28 0.28 0.28],'LineStyle','--','LineWidth',1.5, ...
        'HandleVisibility','off');

    % Inset is deliberately an independent axes so exportgraphics writes a
    % true vector magnification rather than a raster screenshot.
    axInset=axes(f,'Units','normalized','Position',opt.insetPosition); %#ok<LAXES>
    set(axInset,'TickLabelInterpreter','latex', 'FontSize',20);
    hold(axInset,'on'); grid(axInset,'on'); box(axInset,'on');
    for i=1:numel(selected)
        d=selected{i};
        if ~isfield(d,'roc') || ~isstruct(d.roc) || isempty(d.roc.FPR), continue; end
        h=plot(axInset,double(d.roc.FPR),double(d.roc.TPR),'LineWidth',2, ...
            'HandleVisibility','off');
        % Preserve exactly the same algorithm color as the main ROC.
        if all(isfinite(curveColors(i,:))), h.Color=curveColors(i,:); end
        if isfield(d,'operatingPoint') && numel(d.operatingPoint)>=2 && ...
                all(isfinite(d.operatingPoint(1:2)))
            scatter(axInset,d.operatingPoint(1),d.operatingPoint(2),40,'o', ...
                'MarkerEdgeColor',h.Color,'MarkerFaceColor',h.Color, ...
                'HandleVisibility','off');
        end
    end
    xlim(axInset,[0 opt.zoomFprMax]);
    ylim(axInset,[opt.zoomTprMin 1]);
    set(axInset,'TickLabelInterpreter','latex', 'FontSize',20);

    xlabel(axInset,'FPR','FontSize',20, 'Interpreter','latex');
    ylabel(axInset,'TPR','FontSize',20, 'Interpreter','latex');
    title(axInset,'Low-FPR magnification','FontWeight','bold','FontSize',23, 'Interpreter','latex');

    % Draw magnifier connectors from the right edge of the boxed region to
    % the left edge of the inset. Annotation coordinates are figure-normalized.
    drawnow;
    [xTop,yTop]=data_to_figure(ax,opt.zoomFprMax,1);
    [xBot,yBot]=data_to_figure(ax,opt.zoomFprMax,opt.zoomTprMin);
    p=opt.insetPosition;
    annotation(f,'line',[xTop p(1)],[yTop p(2)+p(4)], ...
        'Color',[0.38 0.38 0.38],'LineStyle',':','LineWidth',1.5);
    annotation(f,'line',[xBot p(1)],[yBot p(2)], ...
        'Color',[0.38 0.38 0.38],'LineStyle',':','LineWidth',1.5);
end
exportgraphics(f,filename,'ContentType','vector');
end

function opt=roc_plot_options(cfg,selected)
opt=struct('showMagnifier',true,'zoomFprMax',[],'zoomTprMin',0.5, ...
    'insetPosition',[0.53 0.50 0.32 0.30]);
if isfield(cfg,'diagnostics') && isfield(cfg.diagnostics,'roc') && ...
        isstruct(cfg.diagnostics.roc)
    r=cfg.diagnostics.roc;
    if isfield(r,'showMagnifier') && ~isempty(r.showMagnifier)
        opt.showMagnifier=logical(r.showMagnifier);
    end
    if isfield(r,'zoomFprMax') && ~isempty(r.zoomFprMax) && ...
            isfinite(r.zoomFprMax) && r.zoomFprMax>0
        opt.zoomFprMax=min(1,double(r.zoomFprMax));
    end
    if isfield(r,'zoomTprMin') && ~isempty(r.zoomTprMin) && ...
            isfinite(r.zoomTprMin)
        opt.zoomTprMin=max(0,min(0.99,double(r.zoomTprMin)));
    end
    if isfield(r,'insetPosition') && isnumeric(r.insetPosition) && ...
            numel(r.insetPosition)==4 && all(isfinite(r.insetPosition))
        q=double(r.insetPosition(:)');
        if all(q(3:4)>0), opt.insetPosition=q; end
    end
end

% If no explicit x-range was requested, magnify enough low-FPR space to
% include all benchmark operating points with a modest margin.
if isempty(opt.zoomFprMax)
    op=[];
    for i=1:numel(selected)
        if isfield(selected{i},'operatingPoint') && ...
                numel(selected{i}.operatingPoint)>=1
            op(end+1)=selected{i}.operatingPoint(1); %#ok<AGROW>
        end
    end
    op=op(isfinite(op));
    if isempty(op)
        opt.zoomFprMax=0.15;
    else
        opt.zoomFprMax=max(0.15,min(0.35,1.6*max(op)));
    end
end
end

function [xf,yf]=data_to_figure(ax,x,y)
%DATA_TO_FIGURE Convert axes data coordinates to normalized figure coords.
oldUnits=ax.Units;
ax.Units='normalized';
pos=ax.Position;
ax.Units=oldUnits;
xl=ax.XLim; yl=ax.YLim;
xf=pos(1)+pos(3)*(double(x)-xl(1))/(xl(2)-xl(1));
yf=pos(2)+pos(4)*(double(y)-yl(1))/(yl(2)-yl(1));
end

function plot_score_traces(selected,filename,w,plotRaw)
f=figure('Visible','off','Color','w','Position',[80 80 1300 450]);
cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
items={'MeanForegroundScore','Mean score on true FG'; ...
    'MeanBackgroundScore','Mean score on true BG'; ...
    'ScoreRatio','FG/BG score ratio'};
rolled=cell(size(selected));
for i=1:numel(selected)
    rolled{i}=rolling_frame_metrics(selected{i}.metrics,w);
end
for k=1:3
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    for i=1:numel(selected)
        d=selected{i}; r=rolled{i};
        if plotRaw
            plot(ax,d.metrics.frameNumbers,d.metrics.(items{k,1}), ...
                'LineWidth',0.25,'HandleVisibility','off');
        end
        plot(ax,r.frameNumbers,r.(items{k,1}),'LineWidth',1.35, ...
            'DisplayName',d.algorithm);
    end
    xlabel(ax,'Native frame number'); ylabel(ax,items{k,2});
    set_eval_xlim(ax,selected);
    if k==1, legend(ax,'Location','best','Interpreter','none'); end
end
if w<=1
    desc='Foreground-score separation over time';
else
    desc=sprintf('Foreground-score separation over a %d-frame pooled window',w);
end
sgtitle(tl,desc,'FontWeight','bold');
exportgraphics(f,filename,'ContentType','vector');
end

function plot_subspace_traces(selected,filename,w,plotRaw)
% Show reference error only when an actual reference was supplied (or the
% user explicitly requested the initial-U0 proxy). Auto CDnet mode has no
% true reference, so it shows update magnitude only.
hasReference=false;
for i=1:numel(selected)
    d=selected{i};
    if has_subspace_trace(d) && isfield(d.subspace,'referenceDistance') && ...
            any(isfinite(d.subspace.referenceDistance))
        hasReference=true; break;
    end
end

if hasReference
    f=figure('Visible','off','Color','w','Position',[80 80 1250 500]);
    cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
    tl=tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
    axRef=nexttile(tl); hold(axRef,'on'); grid(axRef,'on'); box(axRef,'on');
    axStep=nexttile(tl); hold(axStep,'on'); grid(axStep,'on'); box(axStep,'on');
else
    f=figure('Visible','off','Color','w','Position',[100 100 820 540]);
    cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
    tl=tiledlayout(f,1,1,'Padding','compact','TileSpacing','compact');
    axRef=[];
    axStep=nexttile(tl); hold(axStep,'on'); grid(axStep,'on'); box(axStep,'on');
end

refLabels={}; normalized=false;
for i=1:numel(selected)
    d=selected{i};
    if ~has_subspace_trace(d), continue; end
    s=d.subspace; x=d.metrics.frameNumbers;
    normalized=normalized || s.normalized;
    stride=1; if isfield(s,'sampleStride'), stride=max(1,s.sampleStride); end
    ws=max(1,round(w/stride));
    if hasReference
        plot_sampled_trace(axRef,x,s.referenceDistance,ws,plotRaw,d.algorithm);
    end
    plot_sampled_trace(axStep,x,s.stepDistance,ws,plotRaw,d.algorithm);
    if isfield(s,'referenceLabel') && ~isempty(s.referenceLabel)
        refLabels{end+1}=s.referenceLabel; %#ok<AGROW>
    end
end

if hasReference
    xlabel(axRef,'Native frame number');
    if normalized, ylabel(axRef,'Normalized chordal/projector distance');
    else, ylabel(axRef,'Chordal/projector distance'); end
    title(axRef,'Estimated subspace vs reference','FontWeight','bold');
    add_event_lines(axRef,selected{1});
    set_full_xlim(axRef,selected);
    legend(axRef,'Location','best','Interpreter','none');
end
xlabel(axStep,'Native frame number');
if normalized, ylabel(axStep,'Normalized per-update chordal distance');
else, ylabel(axStep,'Per-update chordal distance'); end
title(axStep,'Subspace update magnitude','FontWeight','bold');
add_event_lines(axStep,selected{1});
set_full_xlim(axStep,selected);
legend(axStep,'Location','best','Interpreter','none');

refLabels=unique(refLabels,'stable');
if hasReference && ~isempty(refLabels)
    refText=['Reference: ' strjoin(refLabels,'; ')];
elseif hasReference
    refText='Reference subspace supplied';
else
    refText='CDnet has no ground-truth subspace; reference-error curve omitted';
end
sgtitle(tl,sprintf('Subspace diagnostics (%s) - %s',smooth_label(w),refText), ...
    'FontWeight','bold','Interpreter','none');
exportgraphics(f,filename,'ContentType','vector');
end

function add_event_lines(ax,d)
if isfield(d,'trainingEndFrame') && isfinite(d.trainingEndFrame)
    xline(ax,double(d.trainingEndFrame),'--','training end', ...
        'HandleVisibility','off','LabelVerticalAlignment','bottom');
end
if isfield(d,'temporalROI') && numel(d.temporalROI)>=1 && isfinite(d.temporalROI(1))
    xline(ax,double(d.temporalROI(1)),':','CDnet evaluation start', ...
        'HandleVisibility','off','LabelVerticalAlignment','top');
end
end

function plot_sampled_trace(ax,x,y,w,plotRaw,name)
y=double(y(:)'); x=double(x(:)');
good=isfinite(y) & isfinite(x);
if ~any(good)
    plot(ax,nan,nan,'DisplayName',name,'LineWidth',1.35);
    return;
end
x=x(good); y=y(good);
if plotRaw
    plot(ax,x,y,'LineWidth',0.35,'HandleVisibility','off');
end
if w>1, y=movmean(y,w,'omitnan','Endpoints','shrink'); end
plot(ax,x,y,'LineWidth',1.35,'DisplayName',name);
end

function set_eval_xlim(ax,selected)
lo=Inf; hi=-Inf;
for i=1:numel(selected)
    m=selected{i}.metrics;
    good=logical(m.evalFrame(:)') & isfinite(m.frameNumbers(:)');
    if any(good)
        lo=min(lo,min(m.frameNumbers(good)));
        hi=max(hi,max(m.frameNumbers(good)));
    end
end
if isfinite(lo) && isfinite(hi) && hi>lo, xlim(ax,[lo hi]); end
end

function set_full_xlim(ax,selected)
lo=Inf; hi=-Inf;
for i=1:numel(selected)
    x=double(selected{i}.metrics.frameNumbers(:)');
    x=x(isfinite(x));
    if ~isempty(x), lo=min(lo,min(x)); hi=max(hi,max(x)); end
end
if isfinite(lo) && isfinite(hi) && hi>lo, xlim(ax,[lo hi]); end
end

function tf=has_subspace_trace(d)
tf=isstruct(d) && isfield(d,'subspace') && isstruct(d.subspace) && ...
    isfield(d.subspace,'enabled') && d.subspace.enabled && ...
    isfield(d.subspace,'stepDistance') && ~isempty(d.subspace.stepDistance);
end

function s=smooth_label(w)
if w<=1, s='unsmoothed'; else, s=sprintf('%d-frame pooled window',w); end
end

function hi=max_reasonable_ylim(ax,lo)
y=[];
for k=1:numel(ax.Children)
    if isprop(ax.Children(k),'YData'), y=[y double(ax.Children(k).YData(:)')]; end %#ok<AGROW>
end
y=y(isfinite(y));
if isempty(y), hi=lo+1; else, hi=max(lo+eps,1.05*max(y)); end
end

function close_if_valid(f)
if isgraphics(f), close(f); end
end
