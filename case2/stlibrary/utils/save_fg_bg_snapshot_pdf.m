function filename = save_fg_bg_snapshot_pdf(results, filename, algorithmFilter, requestedFrame)
%SAVE_FG_BG_SNAPSHOT_PDF Save original/foreground/background comparison PDF.
%
% One row is drawn per algorithm and the three columns are Original,
% Foreground score, and Background. RESULTS is the cell array returned by
% RUN_ALL_ALGORITHMS (or equivalent structs containing a .snapshot field).

if nargin<3, algorithmFilter={}; end
if nargin<4, requestedFrame=[]; end
if isstring(algorithmFilter), algorithmFilter=cellstr(algorithmFilter); end
if ischar(algorithmFilter), algorithmFilter={algorithmFilter}; end

selected={};
for i=1:numel(results)
    r=results{i};
    if ~isstruct(r) || ~isfield(r,'algorithm') || ~isfield(r,'snapshot') || isempty(r.snapshot)
        continue;
    end
    if ~isempty(algorithmFilter) && ~any(strcmpi(r.algorithm,algorithmFilter))
        continue;
    end
    selected{end+1}=r; %#ok<AGROW>
end
if isempty(selected)
    error('SubspaceBenchmark:NoSnapshotData', ...
        'No saved snapshot data are available for the requested algorithms.');
end

% All methods in one benchmark run share the same requested snapshot set.
available=double(selected{1}.snapshot.frameNumbers(:)');
if isempty(requestedFrame)
    frameNumber=available(1);
else
    requestedFrame=double(requestedFrame(1));
    [delta,j]=min(abs(available-requestedFrame));
    frameNumber=available(j);
    if delta>0
        error('SubspaceBenchmark:SnapshotFrameNotSaved', ...
            'Requested frame %g is not in the saved snapshot set [%s].', ...
            requestedFrame,strtrim(sprintf('%g ',available)));
    end
end
for i=1:numel(selected)
    if ~any(double(selected{i}.snapshot.frameNumbers)==frameNumber)
        error('SubspaceBenchmark:SnapshotFrameMismatch', ...
            'Saved algorithm snapshots do not share frame %g.',frameNumber);
    end
end

% Use one common display range for all foreground panels so amplitudes are
% visually comparable instead of independently auto-scaling each method.
allFg=[];
for i=1:numel(selected)
    s=selected{i}.snapshot;
    j=find(double(s.frameNumbers)==frameNumber,1);
    allFg=[allFg; abs(single(s.foreground(:,j)))]; %#ok<AGROW>
end
fgMax=robust_upper(allFg,0.995);
fgMax=max(double(fgMax),0.02);
if ~isfinite(fgMax) || fgMax<=0, fgMax=0.1; end

nRows=numel(selected);
f=figure('Visible','off','Color','w','Position',[100 100 1200 max(340,280*nRows)]);
cleanup=onCleanup(@()close_if_valid(f)); %#ok<NASGU>
tl=tiledlayout(f,nRows,3,'Padding','compact','TileSpacing','compact');
colormap(f,gray(256));

for i=1:nRows
    r=selected{i}; s=r.snapshot;
    j=find(double(s.frameNumbers)==frameNumber,1);
    h=double(s.height); w=double(s.width);
    if isempty(h) || isempty(w) || h*w~=numel(s.original(:,j))
        error('SubspaceBenchmark:BadSnapshotGeometry', ...
            'Snapshot geometry is missing or inconsistent for %s.',r.algorithm);
    end
    original=reshape(double(s.original(:,j)),h,w);
    foreground=reshape(abs(double(s.foreground(:,j))),h,w);
    background=reshape(double(s.background(:,j)),h,w);

    ax=nexttile(tl); imagesc(ax,original,[0 1]); axis(ax,'image','off');
    title(ax,sprintf('%s - Original',r.algorithm),'Interpreter','latex','FontWeight','bold', 'FontSize',25);

    ax=nexttile(tl); imagesc(ax,foreground,[0 fgMax]); axis(ax,'image','off');
    title(ax,'Foreground', 'Interpreter','latex','FontWeight','bold', 'FontSize',25);

    ax=nexttile(tl); imagesc(ax,background,[0 1]); axis(ax,'image','off');
    title(ax,'Background','Interpreter','latex','FontWeight','bold','FontSize',25);
end

snap=selected{1}.snapshot;
if isfield(snap,'category') && isfield(snap,'sequence') && ...
        ~isempty(snap.category) && ~isempty(snap.sequence)
    sgtitle(tl,sprintf('CDnet %s/%s - frame %d',snap.category,snap.sequence,frameNumber), ...
        'Interpreter','latex','FontWeight','bold','FontSize',25);
else
    sgtitle(tl,sprintf('Foreground/background snapshot - frame %d',frameNumber), ...
        'Interpreter','latex','FontWeight','bold','FontSize',25);
end

folder=fileparts(filename); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
exportgraphics(f,filename,'ContentType','vector');
end

function q=robust_upper(x,p)
x=double(x(:)); x=x(isfinite(x));
if isempty(x), q=0; return; end
x=sort(x);
k=max(1,min(numel(x),ceil(p*numel(x))));
q=x(k);
end

function close_if_valid(f)
if isgraphics(f), close(f); end
end
