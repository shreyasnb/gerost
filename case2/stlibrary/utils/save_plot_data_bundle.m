function filename = save_plot_data_bundle(plotData, outDir, cfg)
%SAVE_PLOT_DATA_BUNDLE Persist compact data needed to regenerate figures.
if nargin<2 || isempty(outDir), outDir=pwd; end
if ~isfolder(outDir), mkdir(outDir); end
name='plot_data.mat';
if nargin>=3 && isfield(cfg,'output') && isfield(cfg.output,'plotDataFileName') && ...
        ~isempty(cfg.output.plotDataFileName)
    name=char(string(cfg.output.plotDataFileName));
end
filename=fullfile(outDir,name);
save(filename,'plotData','-v7.3');
end
