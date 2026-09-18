function actualFile = make_comparison_video(seq, results, filename, cfg)
%MAKE_COMPARISON_VIDEO Write a mosaic: input plus binary masks for each method.
[writer,actualFile]=create_video_writer(filename,cfg.output.videoFrameRate);
open(writer);
cleanup=onCleanup(@()close(writer)); %#ok<NASGU>
cols=1+numel(results); tileW=seq.width; tileH=seq.height;
for t=1:seq.numFrames
    input=uint8(255*reshape(double(seq.M(:,t)),tileH,tileW));
    canvas=zeros(tileH,tileW*cols,'uint8'); canvas(:,1:tileW)=input;
    for a=1:numel(results)
        bw=uint8(255*reshape(results{a}.mask(:,t),tileH,tileW));
        canvas(:,a*tileW+(1:tileW))=bw;
    end
    writeVideo(writer,repmat(canvas,1,1,3));
end
end
