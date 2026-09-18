function seq = load_cdnet_sequence(datasetRoot, category, sequence, cfg)
%LOAD_CDNET_SEQUENCE Load a CDnet sequence into a pixels-by-frames matrix.
%
% The returned struct records the exact source input/GT/ROI/temporal-ROI
% paths so diagnostic code can verify the data provenance used by the
% algorithm dispatcher.

root = resolve_dataset_root(datasetRoot);
seqPath = fullfile(root, category, sequence);
if ~isfolder(seqPath)
    error('SubspaceBenchmark:SequenceMissing', 'CDnet sequence not found: %s', seqPath);
end
inputDir = fullfile(seqPath,'input');
gtDir = fullfile(seqPath,'groundtruth');

% Read the native temporal ROI before frame selection so callers can select
% a short native frame range around the evaluation interval.
troiFile=fullfile(seqPath,'temporalROI.txt');
temporal=[];
if isfile(troiFile)
    vals=readmatrix(troiFile); vals=vals(isfinite(vals));
    if numel(vals)>=2, temporal=double(vals(1:2)).'; end
end

files = dir(fullfile(inputDir,'in*.*'));
files = files(~[files.isdir]);
if isempty(files), error('No input frames found in %s', inputDir); end
[~, order] = sort({files.name}); files = files(order);
frameNumbers = nan(1,numel(files));
for i=1:numel(files)
    tok = regexp(files(i).name, 'in(\d+)', 'tokens', 'once');
    if ~isempty(tok), frameNumbers(i)=str2double(tok{1}); end
end
validNum = ~isnan(frameNumbers);
files = files(validNum); frameNumbers = frameNumbers(validNum);
sourceFrameCount = numel(files);

% Optional native CDnet frame-number range, e.g. [462 481]. This is applied
% before stride/maxFrames and is useful for fast real-dataset smoke tests.
frameRange=[];
if isfield(cfg,'io') && isfield(cfg.io,'frameRange') && ~isempty(cfg.io.frameRange)
    frameRange=double(cfg.io.frameRange(:).');
    if numel(frameRange)~=2 || any(~isfinite(frameRange))
        error('SubspaceBenchmark:BadFrameRange', 'cfg.io.frameRange must be empty or [first last].');
    end
    frameRange=sort(round(frameRange));
    keep=frameNumbers>=frameRange(1) & frameNumbers<=frameRange(2);
    files=files(keep); frameNumbers=frameNumbers(keep);
end
if isempty(files)
    error('SubspaceBenchmark:NoSelectedFrames', ...
        'No input frames remain after applying cfg.io.frameRange.');
end

stride = max(1, round(cfg.io.frameStride));
sel = 1:stride:numel(files);
if isfinite(cfg.io.maxFrames), sel = sel(1:min(numel(sel),round(cfg.io.maxFrames))); end
files = files(sel); frameNumbers = frameNumbers(sel);
if isempty(files), error('SubspaceBenchmark:NoSelectedFrames','No frames selected.'); end

first = imread(fullfile(inputDir, files(1).name));
first = to_gray_double(first);
scale = cfg.io.resizeScale;
if scale ~= 1, first = imresize(first, scale, 'bilinear'); end
[h,w] = size(first); n = h*w; T = numel(files);

switch lower(cfg.io.dataType)
    case 'single', M = zeros(n,T,'single');
    otherwise, M = zeros(n,T,'double');
end
GT = zeros(h,w,T,'uint8');
gtLoaded = false(1,T);
inputPaths=cell(1,T);
gtPaths=repmat({''},1,T);

for t=1:T
    inputPaths{t}=fullfile(inputDir,files(t).name);
    I = to_gray_double(imread(inputPaths{t}));
    if scale ~= 1, I = imresize(I, [h w], 'bilinear'); end
    M(:,t) = cast(I(:), class(M));
    if isfolder(gtDir)
        gtFile = find_numbered_file(gtDir, 'gt', frameNumbers(t));
        if ~isempty(gtFile)
            G = read_cdnet_ground_truth(gtFile);
            if scale ~= 1, G=imresize(G,[h w],'nearest'); end
            GT(:,:,t)=uint8(G);
            gtLoaded(t)=true;
            gtPaths{t}=gtFile;
        end
    end
end

% Decode ROI through its palette. Raw indexed BMP values are not themselves
% luminance values and can otherwise incorrectly produce an all-false ROI.
roi = true(h,w);
roiFile='';
roiInfo=struct('filename','','decodeMode','implicit-full-frame','roiPixels',h*w, ...
    'totalPixels',h*w,'coverage',1,'hasColormap',false);
roiCandidates = {'ROI.bmp','ROI.png','ROI.jpg'};
for i=1:numel(roiCandidates)
    f=fullfile(seqPath,roiCandidates{i});
    if isfile(f)
        [R,roiInfo]=read_cdnet_roi(f);
        if scale~=1,R=imresize(R,[h w],'nearest');end
        roi=logical(R); roiFile=f;
        roiInfo.roiPixels=nnz(roi);
        roiInfo.totalPixels=numel(roi);
        roiInfo.coverage=nnz(roi)/max(numel(roi),1);
        break;
    end
end

if isempty(temporal), temporal = [frameNumbers(1) frameNumbers(end)]; end
temporalEvalFrame = frameNumbers>=temporal(1) & frameNumbers<=temporal(2);
metricEvalFrame = temporalEvalFrame & gtLoaded;

seq = struct();
seq.projectRoot = cfg.projectRoot;
seq.datasetRoot = root;
seq.path = seqPath;
seq.inputDir = inputDir;
seq.groundTruthDir = gtDir;
seq.inputFiles = inputPaths;
seq.groundTruthFiles = gtPaths;
seq.roiFile = roiFile;
seq.roiInfo = roiInfo;
seq.temporalROIFile = troiFile;
seq.category = category;
seq.name = sequence;
seq.M = M;
seq.groundTruth = GT;
seq.roi = roi;
seq.temporalROI = temporal;
seq.temporalEvalFrame = temporalEvalFrame;
seq.evalFrame = metricEvalFrame;
seq.frameNumbers = frameNumbers;
seq.sourceFrameCount = sourceFrameCount;
seq.frameRangeRequested = frameRange;
seq.frameStride = stride;
seq.height = h;
seq.width = w;
seq.numFrames = T;
gtFiles=dir(fullfile(gtDir,'gt*.*'));
seq.groundTruthFilesPresent = isfolder(gtDir) && any(~[gtFiles.isdir]);
seq.gtFramesLoaded = nnz(gtLoaded);
seq.gtEvalFramesExpected = nnz(temporalEvalFrame);
seq.gtEvalFramesLoaded = nnz(metricEvalFrame);
seq.hasGroundTruth = any(gtLoaded);
seq.gtStats = cdnet_gt_stats(GT,roi,metricEvalFrame,seq.hasGroundTruth);
end

function stats = cdnet_gt_stats(GT,roi,evalFrame,hasGT)
stats=struct('validPixels',0,'movingPixels',0,'staticPixels',0, ...
    'shadowPixels',0,'unknownPixels',0,'nonRoiPixels',0,'unexpectedPixels',0, ...
    'roiPixelsPerFrame',nnz(roi));
if ~hasGT, return; end
for t=find(evalFrame)
    g=GT(:,:,t);
    in=roi;
    stats.movingPixels=stats.movingPixels+nnz(in & g==255);
    stats.staticPixels=stats.staticPixels+nnz(in & g==0);
    stats.shadowPixels=stats.shadowPixels+nnz(in & g==50);
    stats.unknownPixels=stats.unknownPixels+nnz(in & g==170);
    stats.nonRoiPixels=stats.nonRoiPixels+nnz(in & g==85);
    known=(g==0 | g==50 | g==85 | g==170 | g==255);
    stats.unexpectedPixels=stats.unexpectedPixels+nnz(in & ~known);
end
stats.validPixels=stats.movingPixels+stats.staticPixels+stats.shadowPixels;
end

function I = to_gray_double(I)
if ndims(I)==3
    if size(I,3)>=3
        I = 0.2989360213*double(I(:,:,1)) + 0.5870430745*double(I(:,:,2)) + 0.1140209043*double(I(:,:,3));
    else
        I = double(I(:,:,1));
    end
else
    I=double(I);
end
if isa(I,'double')
    mx=max(I(:)); if mx>1, I=I/255; end
end
I=min(max(I,0),1);
end

function f = find_numbered_file(folder, prefix, number)
patterns = {sprintf('%s%06d.png',prefix,number), sprintf('%s%06d.bmp',prefix,number), ...
    sprintf('%s%06d.jpg',prefix,number), sprintf('%s%06d.jpeg',prefix,number)};
f='';
for k=1:numel(patterns)
    p=fullfile(folder,patterns{k}); if isfile(p), f=p; return; end
end
d=dir(fullfile(folder,sprintf('%s%06d.*',prefix,number)));
if ~isempty(d), f=fullfile(folder,d(1).name); end
end
