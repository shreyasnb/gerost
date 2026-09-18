function pdfPath = save_gerost_robustness_pdf(result, seq, cfg, outDir)
%SAVE_GEROST_ROBUSTNESS_PDF Plot GeRoST raw/capped NSR, rho_t, lambda*_t.
%
% The first panel deliberately distinguishes two quantities:
%   raw xi-hat_t  = observable pre-update NSR proxy,
%   xi-tilde_t    = clipped operational proxy actually fed to the rho map.
%
% For adaptive rho, the adapter uses
%   xi-tilde_t = min(max(xi-hat_t,0), xi_max)
%   rho_t      = rhoScale * xi-tilde_t / (1-xi-tilde_t)
% followed by the algorithm's admissible-radius clipping.  Thus the raw
% xi-hat curve is EXPECTED to exceed the cap; the capped xi-tilde curve is
% the one that must flatten at the cap.  Older plot_data.mat files do not
% contain xiOperationalHistory, so this function reconstructs it exactly
% from xi-hat and rhoNsrCap and therefore does not require a benchmark rerun.
%
% xi-hat is an observable CDnet proxy, not the theoretical xi_t of the paper
% (which depends on the unknown true subspace).

if nargin < 4 || isempty(outDir), outDir = pwd; end
if ~isfolder(outDir), mkdir(outDir); end
if ~isstruct(result) || ~isfield(result,'state') || ~isstruct(result.state)
    error('SubspaceBenchmark:MissingGeRoSTState', ...
        'GeRoST robustness plotting requires result.state.');
end
st=result.state;

xiRaw=get_history(st,{'xiProxyHistory','pHistory'});
xiOperational=get_history(st,{'xiOperationalHistory'});
rho=get_history(st,{'rhoHistory'});
lambda=get_history(st,{'lambdaStarHistory','lambdaHistory'});
if isempty(xiRaw) || isempty(rho) || isempty(lambda)
    error('SubspaceBenchmark:MissingGeRoSTRobustnessTrace', ...
        'GeRoST result does not contain xi/rho/lambda histories.');
end

T=min([numel(xiRaw),numel(rho),numel(lambda)]);
xiRaw=double(xiRaw(1:T)); xiRaw=xiRaw(:)';
rho=double(rho(1:T)); rho=rho(:)';
lambda=double(lambda(1:T)); lambda=lambda(:)';

adaptiveRho=true;
if isfield(result,'options') && isfield(result.options,'adaptiveRho') && ...
        ~isempty(result.options.adaptiveRho)
    adaptiveRho=logical(result.options.adaptiveRho);
end

cap=NaN;
if isfield(st,'rhoNsrCap') && isfinite(st.rhoNsrCap)
    cap=min(double(st.rhoNsrCap),0.99);
end

% Prefer the exact operational history saved by new runs.  For older
% plot_data.mat bundles reconstruct it from the same clipping rule used in
% algorithms/st/GeRoST/run_alg.m.
if ~isempty(xiOperational)
    xiOperational=double(xiOperational(1:min(T,numel(xiOperational))));
    xiOperational=xiOperational(:)';
    if numel(xiOperational)<T
        xiOperational(end+1:T)=NaN;
    end
elseif adaptiveRho && isfinite(cap)
    xiOperational=min(max(xiRaw,0),cap);
else
    xiOperational=xiRaw;
end

if isfield(seq,'frameNumbers') && numel(seq.frameNumbers)>=T
    x=double(seq.frameNumbers(1:T)); x=x(:)';
else
    x=1:T;
end

plotCfg=struct('smoothingWindow',1,'showCap',true, ...
    'showTrainingMarker',false,'showEvaluationMarker',false, ...
    'showRawXi',true,'showOperationalXi',true);
if isfield(cfg,'diagnostics') && isfield(cfg.diagnostics,'gerostRobustness')
    plotCfg=merge_struct(plotCfg,cfg.diagnostics.gerostRobustness);
end
w=max(1,round(plotCfg.smoothingWindow));
if w>1
    % Important: operational clipping is performed BEFORE smoothing so that
    % the plotted xi-tilde represents the quantity actually used frame-wise.
    xiRawPlot=movmean(xiRaw,w,'omitnan');
    xiOperationalPlot=movmean(xiOperational,w,'omitnan');
    rhoPlot=movmean(rho,w,'omitnan');
    lambdaPlot=movmean(lambda,w,'omitnan');
else
    xiRawPlot=xiRaw;
    xiOperationalPlot=xiOperational;
    rhoPlot=rho;
    lambdaPlot=lambda;
end

if isfield(cfg.output,'gerostRobustnessPdfName') && ~isempty(cfg.output.gerostRobustnessPdfName)
    name=char(cfg.output.gerostRobustnessPdfName);
else
    name='gerost_rho_lambda_xi.pdf';
end
pdfPath=fullfile(outDir,name);

f=figure('Visible','off','Color','w','Position',[100 100 1000 600]);
cleaner=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
tl=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
if w>1
    ttl=sprintf('GeRoST robustness diagnostics (%d-frame moving mean)',w);
else
    ttl='GeRoST robustness diagnostics';
end
% title(tl,ttl,'FontWeight','bold');

ax1=nexttile(tl,1); hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
set(gca, 'FontSize', 20, 'TickLabelInterpreter','latex')
if plotCfg.showRawXi
    plot(ax1,x,xiRawPlot,'LineWidth',1.0,'DisplayName','raw $\xi_t$');
end
if plotCfg.showOperationalXi
    plot(ax1,x,xiOperationalPlot,'--','LineWidth',1.45, ...
        'DisplayName','capped $\xi_t$');
end
ylabel(ax1,'$\xi_t$','Interpreter','latex', 'FontSize',25);
title(ax1,'Instantaneous noise-to-signal ratio','Interpreter','latex','FontSize',25);
% if plotCfg.showCap && adaptiveRho && isfinite(cap)
%     yline(ax1,cap,':',sprintf('cap = %.3g',cap), ...
%         'LabelHorizontalAlignment','left','DisplayName','');
% end
legend(ax1,'Interpreter','latex','Location','best', 'BackgroundAlpha',0.5, 'FontSize',20);
add_markers(ax1,seq,result,plotCfg);

ax2=nexttile(tl,2); hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
set(gca, 'FontSize', 20, 'TickLabelInterpreter','latex')
yyaxis left
plot(ax2,x,rhoPlot,'LineWidth',1.15);
ylim([0 0.5]);
ylabel(ax2,'$\rho_t$','Interpreter','latex', 'FontSize',25);

yyaxis right
plot(ax2,x,lambdaPlot,'LineWidth',1.15);
ylim([1.98 inf]);
ylabel(ax2,'$\lambda_t^\star$','Interpreter','latex', 'FontSize',25);
xlabel(ax2,'Frame index $t$','Interpreter','latex', 'FontSize',25);
title(ax2,'Uncertainty radius and dual variable','Interpreter','latex','FontSize',25);
add_markers(ax2,seq,result,plotCfg);

set_shared_xlim([ax1 ax2],x,xiRaw,xiOperational,rho,lambda);
exportgraphics(f,pdfPath,'ContentType','vector');
end

function y=get_history(s,names)
y=[];
for i=1:numel(names)
    if isfield(s,names{i}) && ~isempty(s.(names{i}))
        y=s.(names{i}); return;
    end
end
end

function out=merge_struct(base,override)
out=base;
if ~isstruct(override), return; end
names=fieldnames(override);
for i=1:numel(names), out.(names{i})=override.(names{i}); end
end

function add_markers(ax,seq,result,c)
if c.showTrainingMarker
    trainFrame=[];
    if isfield(result,'initialization') && isfield(result.initialization,'trainingFrames') && ...
            isfield(seq,'frameNumbers') && ~isempty(seq.frameNumbers)
        j=min(max(1,round(result.initialization.trainingFrames)),numel(seq.frameNumbers));
        trainFrame=double(seq.frameNumbers(j));
    elseif isfield(result,'options') && isfield(result.options,'trainingFrames') && ...
            isfield(seq,'frameNumbers') && ~isempty(seq.frameNumbers)
        j=min(max(1,round(result.options.trainingFrames)),numel(seq.frameNumbers));
        trainFrame=double(seq.frameNumbers(j));
    end
    % if ~isempty(trainFrame)
    %     xline(ax,trainFrame,'--','DisplayName','Training end');
    % end
end
% if c.showEvaluationMarker && isfield(seq,'temporalROI') && numel(seq.temporalROI)>=1
%     xline(ax,double(seq.temporalROI(1)),'--', 'LineWidth',2,'DisplayName','Evaluation starts');
% end
end

function set_shared_xlim(ax,x,varargin)
good=false(size(x));
for i=1:numel(varargin)
    y=varargin{i}; y=y(:)'; y=y(1:min(numel(y),numel(x)));
    good(1:numel(y))=good(1:numel(y)) | isfinite(y);
end
if any(good)
    lo=min(x(good)); hi=max(x(good));
else
    lo=min(x); hi=max(x);
end
if isfinite(lo) && isfinite(hi) && hi>lo
    for k=1:numel(ax), xlim(ax(k),[lo hi]); end
end
end

function close_if_valid(f)
if isgraphics(f), close(f); end
end
