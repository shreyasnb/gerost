function plot_comparison(T, filename)
%PLOT_COMPARISON Save compact F1/AUC/runtime comparison plots.
ok=T.Status=="ok";
if ~any(ok), return; end
T=T(ok,:);
f=figure('Visible','off','Color','w','Position',[100 100 1100 360]);
cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
nexttile(tl); bar(categorical(T.Algorithm),T.F1); ylim([0 1]); ylabel('F1'); grid on;
nexttile(tl); bar(categorical(T.Algorithm),T.AUC); ylim([0 1]); ylabel('ROC AUC'); grid on;
nexttile(tl); bar(categorical(T.Algorithm),T.Runtime); ylabel('Runtime (s)'); grid on;
title(tl,'Subspace tracking foreground/background comparison');
folder=fileparts(filename); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
[~,~,ext]=fileparts(filename);
if strcmpi(ext,'.pdf')
    exportgraphics(f,filename,'ContentType','vector');
else
    exportgraphics(f,filename,'Resolution',160);
end
end

function close_if_valid(f)
if isgraphics(f), close(f); end
end
