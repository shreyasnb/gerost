function tests = test_synthetic_loader
tests=functiontests(localfunctions);
end
function testLoad(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); cfg=benchmark_config(); cfg.io.maxFrames=15;
seq=load_cdnet_sequence(fullfile(root,'dataset','synthetic_demo'),'baseline','synthetic_square',cfg);
verifyEqual(testCase,seq.numFrames,15); verifyTrue(testCase,seq.hasGroundTruth); verifySize(testCase,seq.M,[seq.height*seq.width 15]);
end

function testIndexedCdnetGroundTruthDecoding(testCase)
labels=uint8([0 50 85 170 255]);
X=uint8(0:4);
map=repmat(double(labels(:))/255,1,3);
f=[tempname '.png'];
cleanup=onCleanup(@() delete_if_exists(f)); %#ok<NASGU>
imwrite(X,map,f,'png');
G=read_cdnet_ground_truth(f);
verifyEqual(testCase,G,labels);
end


function testIndexedCdnetRoiDecoding(testCase)
% Palette index zero can map to white. Raw X>0 would incorrectly produce
% an all-false ROI; read_cdnet_roi must decode the colormap first.
X=zeros(8,9,'uint8');
map=[1 1 1; 0 0 0];
f=[tempname '.bmp'];
cleanup=onCleanup(@() delete_if_exists(f)); %#ok<NASGU>
imwrite(X,map,f,'bmp');
[roi,info]=read_cdnet_roi(f);
verifyTrue(testCase,all(roi(:)));
verifyEqual(testCase,info.coverage,1,'AbsTol',1e-12);
verifyTrue(testCase,info.hasColormap);
end

function testNativeFrameRangeSelection(testCase)
root=fileparts(fileparts(mfilename('fullpath')));
cfg=benchmark_config();
cfg.io.frameRange=[20 24];
cfg.io.maxFrames=inf;
cfg.io.frameStride=1;
seq=load_cdnet_sequence(fullfile(root,'dataset','synthetic_demo'),'baseline','synthetic_square',cfg);
verifyEqual(testCase,seq.frameNumbers,20:24);
verifyEqual(testCase,seq.numFrames,5);
verifyEqual(testCase,numel(seq.inputFiles),5);
verifyEqual(testCase,numel(seq.groundTruthFiles),5);
end

function delete_if_exists(f)
if isfile(f), delete(f); end
end
