function mask = apply_foreground_postprocess(mask, h, w, cfg)
%APPLY_FOREGROUND_POSTPROCESS Optional identical morphology for all methods.
mask=logical(mask);
if ~cfg.foreground.useMorphology || cfg.foreground.minArea<=0, return; end
if exist('bwareaopen','file')~=2
    warning('Image Processing Toolbox bwareaopen not found; skipping morphology.'); return;
end
for t=1:size(mask,2)
    bw=reshape(mask(:,t),h,w);
    bw=bwareaopen(bw,cfg.foreground.minArea,8);
    mask(:,t)=bw(:);
end
end
