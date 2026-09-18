function seq = load_video_file(filename, cfg)
%LOAD_VIDEO_FILE Read a standard video into the benchmark sequence structure.

vr = VideoReader(filename);
frames = {};
count=0; maxFrames=cfg.io.maxFrames; stride=max(1,round(cfg.io.frameStride)); rawIdx=0;
while hasFrame(vr)
    rawIdx=rawIdx+1; frame=readFrame(vr);
    if mod(rawIdx-1,stride)~=0, continue; end
    count=count+1;
    I=gray01(frame);
    if cfg.io.resizeScale~=1, I=imresize(I,cfg.io.resizeScale,'bilinear'); end
    frames{count}=I; %#ok<AGROW>
    if isfinite(maxFrames) && count>=maxFrames, break; end
end
assert(count>0,'No video frames read from %s',filename);
[h,w]=size(frames{1}); M=zeros(h*w,count);
for t=1:count, M(:,t)=frames{t}(:); end
seq=struct('projectRoot',cfg.projectRoot,'path',filename,'category','video','name', ...
    string(get_basename(filename)),'M',M,'groundTruth',zeros(h,w,count,'uint8'), ...
    'roi',true(h,w),'temporalROI',[1 count],'evalFrame',true(1,count), ...
    'frameNumbers',1:count,'height',h,'width',w,'numFrames',count,'hasGroundTruth',false);
end
function I=gray01(F)
F=double(F); if size(F,3)>=3, I=.2989360213*F(:,:,1)+.5870430745*F(:,:,2)+.1140209043*F(:,:,3); else,I=F(:,:,1);end
I=I/255;
end
function b=get_basename(f), [~,b,~]=fileparts(f); end
