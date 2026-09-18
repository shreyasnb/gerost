function report = check_cdnet_highway(datasetRoot)
%CHECK_CDNET_HIGHWAY Fast provenance/decoding check for CDnet baseline/highway.
%
% report = check_cdnet_highway()
% report = check_cdnet_highway('/path/to/CDnet/dataset')
%
% This does NOT run a tracker. It verifies that the benchmark resolves the
% expected CDnet directories, decodes ROI/GT labels, records exact source
% files, and that load_cdnet_sequence puts the same pixels into seq.M/GT.
% It samples only three frames spanning the temporal ROI and writes a small
% diagnostic PNG under output/diagnostics/highway_check.

st_setup();
cfg=benchmark_config();
if nargin>=1 && ~isempty(datasetRoot), cfg.dataset.root=datasetRoot; end
cfg.dataset.root=resolve_dataset_root(cfg.dataset.root);
cfg.dataset.category='baseline';
cfg.dataset.sequence='highway';

seqPath=fullfile(cfg.dataset.root,'baseline','highway');
troiFile=fullfile(seqPath,'temporalROI.txt');
if ~isfile(troiFile)
    error('SubspaceBenchmark:MissingTemporalROI','Missing %s',troiFile);
end
vals=readmatrix(troiFile); vals=vals(isfinite(vals));
if numel(vals)<2, error('Invalid temporalROI.txt: %s',troiFile); end
temporal=double(vals(1:2)).';
span=max(0,temporal(2)-temporal(1));

cfg.io.frameRange=temporal;
cfg.io.frameStride=max(1,floor(span/2));
cfg.io.maxFrames=3;
cfg.io.resizeScale=1;
cfg.io.dataType='single';
seq=load_cdnet_sequence(cfg.dataset.root,'baseline','highway',cfg);

fprintf('\n=== CDnet highway data check ===\n');
fprintf('Benchmark version : %s\n', benchmark_version());
fprintf('Sequence folder   : %s\n', seq.path);
fprintf('Input folder      : %s\n', seq.inputDir);
fprintf('Ground-truth dir  : %s\n', seq.groundTruthDir);
fprintf('ROI file          : %s\n', printable_path(seq.roiFile));
fprintf('Temporal ROI file : %s\n', seq.temporalROIFile);
fprintf('Temporal ROI      : %d .. %d\n', seq.temporalROI(1),seq.temporalROI(2));
fprintf('Decoded ROI       : %d/%d pixels (%.2f%%), mode=%s\n', ...
    nnz(seq.roi),numel(seq.roi),100*nnz(seq.roi)/numel(seq.roi),seq.roiInfo.decodeMode);
fprintf('MATLAB function   : %s\n', which('load_cdnet_sequence'));
fprintf('Dispatcher        : %s\n', which('run_algorithm'));

inputMatch=true;
gtMatch=true;
rows=cell(seq.numFrames,4);
for t=1:seq.numFrames
    frameNo=seq.frameNumbers(t);
    inputFile=seq.inputFiles{t};
    gtFile=seq.groundTruthFiles{t};
    srcI=to_gray01(imread(inputFile));
    loadedI=reshape(double(seq.M(:,t)),seq.height,seq.width);
    thisInput=max(abs(srcI(:)-loadedI(:)))<2e-6;
    inputMatch=inputMatch && thisInput;

    if ~isempty(gtFile)
        srcGT=read_cdnet_ground_truth(gtFile);
        thisGT=isequal(uint8(srcGT),seq.groundTruth(:,:,t));
    else
        thisGT=false;
    end
    gtMatch=gtMatch && thisGT;
    u=unique(seq.groundTruth(:,:,t));
    fprintf('\nFrame %d\n',frameNo);
    fprintf('  input : %s\n',inputFile);
    fprintf('  GT    : %s\n',printable_path(gtFile));
    fprintf('  labels: %s\n',mat2str(double(u(:).')));
    fprintf('  loader input match: %d, GT match: %d\n',thisInput,thisGT);
    rows(t,:)={frameNo,string(inputFile),string(gtFile),string(mat2str(double(u(:).')))};
end

s=seq.gtStats;
fprintf('\nSelected-frame evaluation pixels: %d valid = %d moving + %d static + %d shadow\n', ...
    s.validPixels,s.movingPixels,s.staticPixels,s.shadowPixels);
fprintf('Unknown=%d, non-ROI=%d, unexpected=%d\n', ...
    s.unknownPixels,s.nonRoiPixels,s.unexpectedPixels);

outDir=fullfile(cfg.output.root,'diagnostics','highway_check');
if ~isfolder(outDir), mkdir(outDir); end
panelFile=fullfile(outDir,'input_gt_roi_check.png');
write_dataset_panel(seq,panelFile);
frameTable=cell2table(rows,'VariableNames',{'FrameNumber','InputFile','GroundTruthFile','DecodedLabels'});
writetable(frameTable,fullfile(outDir,'source_files.csv'));

pass = isfolder(seq.inputDir) && isfolder(seq.groundTruthDir) && ...
    ~isempty(seq.roiFile) && nnz(seq.roi)>0 && seq.gtEvalFramesLoaded>0 && ...
    seq.gtStats.validPixels>0 && inputMatch && gtMatch;

if pass
    fprintf('\nPASS: loader provenance, ROI decoding, GT decoding, and matrix/file checks are consistent.\n');
else
    fprintf('\nFAIL: one or more dataset checks failed. Inspect the values above before running trackers.\n');
end
fprintf('Diagnostic image  : %s\n',panelFile);
fprintf('Source manifest   : %s\n\n',fullfile(outDir,'source_files.csv'));

report=struct('pass',pass,'sequencePath',seq.path,'temporalROI',seq.temporalROI, ...
    'roiPixels',nnz(seq.roi),'roiCoverage',nnz(seq.roi)/numel(seq.roi), ...
    'gtStats',seq.gtStats,'inputLoaderMatch',inputMatch,'gtLoaderMatch',gtMatch, ...
    'frameNumbers',seq.frameNumbers,'inputFiles',{seq.inputFiles}, ...
    'groundTruthFiles',{seq.groundTruthFiles},'panelFile',panelFile, ...
    'sourceManifest',fullfile(outDir,'source_files.csv'),'frameTable',frameTable);
end

function s=printable_path(s)
if isempty(s), s='<missing>'; end
end

function I=to_gray01(I)
if ndims(I)==3
    I=0.2989360213*double(I(:,:,1))+0.5870430745*double(I(:,:,2))+0.1140209043*double(I(:,:,3));
else
    I=double(I);
end
if max(I(:))>1, I=I/255; end
I=min(max(I,0),1);
end

function write_dataset_panel(seq,filename)
rows=cell(1,seq.numFrames);
for t=1:seq.numFrames
    I=uint8(255*reshape(double(seq.M(:,t)),seq.height,seq.width));
    G=seq.groundTruth(:,:,t);
    R=uint8(255*seq.roi);
    spacer=255*ones(seq.height,3,'uint8');
    rows{t}=[I spacer G spacer R];
end
sep=255*ones(3,size(rows{1},2),'uint8');
canvas=rows{1};
for t=2:numel(rows), canvas=[canvas;sep;rows{t}]; end %#ok<AGROW>
imwrite(canvas,filename);
end
