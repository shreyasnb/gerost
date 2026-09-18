function root = resolve_dataset_root(root)
%RESOLVE_DATASET_ROOT Find the directory whose children are CDnet categories.

candidates = {root, fullfile(root,'dataset'), fullfile(root,'dataset2014'), ...
    fullfile(root,'dataset2014','dataset')};
for i = 1:numel(candidates)
    c = candidates{i};
    if ~isfolder(c), continue; end
    d = dir(c);
    names = {d([d.isdir]).name};
    names = setdiff(names, {'.','..'});
    if any(ismember(names, {'baseline','dynamicBackground','cameraJitter','badWeather', ...
            'intermittentObjectMotion','lowFramerate','nightVideos','PTZ', ...
            'shadow','thermal','turbulence'})) || ...
            (isfolder(fullfile(c,'baseline')))
        root = c;
        return;
    end
end
% Synthetic datasets may use a subset of category names.
if isfolder(root)
    return;
end
error('SubspaceBenchmark:DatasetRoot', 'Could not resolve dataset root: %s', root);
end
