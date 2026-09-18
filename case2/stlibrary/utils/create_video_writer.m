function [writer, actualFile, profile] = create_video_writer(requestedFile, frameRate)
%CREATE_VIDEO_WRITER Create a VideoWriter using a profile supported locally.
%
% Linux MATLAB installations commonly do not expose the MPEG-4 profile.
% Prefer MPEG-4 when available; otherwise fall back to Motion JPEG AVI and
% change the output extension to .avi rather than throwing a profile error.

if nargin<2 || isempty(frameRate), frameRate=12; end
profiles = VideoWriter.getProfiles();
if isempty(profiles)
    error('SubspaceBenchmark:NoVideoWriterProfiles', ...
        'VideoWriter reports no available output profiles on this system.');
end
names = string({profiles.Name});

if any(strcmpi(names,'MPEG-4'))
    profile='MPEG-4';
    [folder,name,~]=fileparts(requestedFile);
    actualFile=fullfile(folder,[name '.mp4']);
elseif any(strcmpi(names,'Motion JPEG AVI'))
    profile='Motion JPEG AVI';
    [folder,name,~]=fileparts(requestedFile);
    actualFile=fullfile(folder,[name '.avi']);
elseif any(strcmpi(names,'Uncompressed AVI'))
    profile='Uncompressed AVI';
    [folder,name,~]=fileparts(requestedFile);
    actualFile=fullfile(folder,[name '.avi']);
else
    profile=char(names(1));
    [folder,name,~]=fileparts(requestedFile);
    actualFile=fullfile(folder,[name '.avi']);
end

writer=VideoWriter(actualFile,profile);
writer.FrameRate=frameRate;
end
