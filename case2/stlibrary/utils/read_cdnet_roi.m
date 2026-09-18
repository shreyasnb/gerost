function [roi, info] = read_cdnet_roi(filename)
%READ_CDNET_ROI Decode a CDnet ROI mask, including indexed BMP/PNG files.
%
% [roi,info] = READ_CDNET_ROI(filename) returns a logical spatial ROI.
% CDnet ROI.bmp files can be indexed images. Looking only at the raw index
% matrix can turn a white, full-frame ROI into all false when palette index
% zero maps to white. Decode the palette first, then threshold luminance.

[X,map] = imread(filename);
rawClass = class(X);
rawMin = double(min(X(:)));
rawMax = double(max(X(:)));

if ~isempty(map)
    if isinteger(X) || islogical(X)
        idx = double(X) + 1;
    else
        idx = double(X);
    end
    idx = min(max(round(idx),1),size(map,1));
    rgb = map(idx(:),:);
    lum = 0.2989360213*rgb(:,1) + 0.5870430745*rgb(:,2) + 0.1140209043*rgb(:,3);
    gray = reshape(lum,size(X));
    decodeMode = 'indexed-colormap';
else
    if ndims(X)>2
        Xd = double(X);
        gray = 0.2989360213*Xd(:,:,1) + 0.5870430745*Xd(:,:,2) + 0.1140209043*Xd(:,:,3);
    else
        gray = double(X);
    end
    if isa(X,'uint16')
        gray = gray/double(intmax('uint16'));
    elseif islogical(X)
        gray = double(gray);
    elseif isinteger(X)
        gray = gray/double(intmax(class(X)));
    elseif ~isempty(gray) && max(gray(:))>1
        gray = gray/255;
    end
    decodeMode = 'direct';
end

gray = min(max(double(gray),0),1);
roi = gray > 0.5;

info = struct();
info.filename = filename;
info.rawClass = rawClass;
info.rawMin = rawMin;
info.rawMax = rawMax;
info.hasColormap = ~isempty(map);
info.colormapRows = size(map,1);
info.decodeMode = decodeMode;
info.grayMin = min(gray(:));
info.grayMax = max(gray(:));
info.roiPixels = nnz(roi);
info.totalPixels = numel(roi);
info.coverage = nnz(roi)/max(numel(roi),1);
end
