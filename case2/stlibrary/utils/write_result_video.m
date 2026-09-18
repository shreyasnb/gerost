function actualFile = write_result_video(seq,result,outFile,cfg)
%WRITE_RESULT_VIDEO Standard-video helper: input | background | foreground mask.
assert(isfield(result,'L') && ~isempty(result.L), ...
    'Background frames were not retained. Rerun with cfg.output.makeVideo=true or cfg.execution.forceBackground=true.');
[writer,actualFile]=create_video_writer(outFile,cfg.output.videoFrameRate);
open(writer);
cleanup=onCleanup(@()close(writer)); %#ok<NASGU>
for t=1:seq.numFrames
 I=reshape(double(seq.M(:,t)),seq.height,seq.width);
 B=reshape(double(result.L(:,t)),seq.height,seq.width); B=min(max(B,0),1);
 F=reshape(result.mask(:,t),seq.height,seq.width);
 canvas=uint8(255*[I B double(F)]); writeVideo(writer,repmat(canvas,1,1,3));
end
end
