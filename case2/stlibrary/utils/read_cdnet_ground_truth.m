function G = read_cdnet_ground_truth(filename)
%READ_CDNET_GROUND_TRUTH Read a CDnet GT image as canonical uint8 labels.
%
% CDnet uses labels 0 (static), 50 (shadow), 85 (non-ROI), 170
% (unknown), and 255 (moving). Some PNG readers/files can expose indexed
% palette values rather than the intended grayscale values; this routine
% resolves indexed images through their colormap before returning labels.

[X,map] = imread(filename);

if ~isempty(map)
    % MATLAB integer indexed images use zero-based stored indices; floating
    % indexed images use one-based indices. Resolve the palette explicitly
    % so downstream code always sees the intended 0..255 grayscale labels.
    if isinteger(X) || islogical(X)
        idx = double(X) + 1;
    else
        idx = double(X);
    end
    idx = min(max(round(idx),1),size(map,1));
    rgb = map(idx(:),:);
    gray = 0.2989360213*rgb(:,1) + 0.5870430745*rgb(:,2) + 0.1140209043*rgb(:,3);
    G = reshape(uint8(round(255*gray)),size(X));
else
    if ndims(X)>2
        X = 0.2989360213*double(X(:,:,1)) + ...
            0.5870430745*double(X(:,:,2)) + ...
            0.1140209043*double(X(:,:,3));
    elseif isfloat(X)
        X = double(X);
        if ~isempty(X) && max(X(:))<=1, X=255*X; end
    elseif isa(X,'uint16')
        X = 255*double(X)/double(intmax('uint16'));
    end
    G = uint8(round(double(X)));
end

% Canonicalize tiny palette/rounding deviations only. A larger deviation is
% left untouched so the evaluator can flag unexpected labels rather than
% silently converting arbitrary data.
labels = double([0 50 85 170 255]);
v = double(G(:));
d = abs(v-labels);
[minDist,which] = min(d,[],2);
snap = minDist<=2;
v(snap) = labels(which(snap));
G = reshape(uint8(v),size(G));
end
