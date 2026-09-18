function index = list_cdnet_sequences(datasetRoot)
%LIST_CDNET_SEQUENCES Return category/sequence pairs under a CDnet root.

datasetRoot = resolve_dataset_root(datasetRoot);
index = struct('category', {}, 'sequence', {}, 'path', {});
catDirs = dir(datasetRoot);
for i = 1:numel(catDirs)
    if ~catDirs(i).isdir || startsWith(catDirs(i).name,'.'), continue; end
    catPath = fullfile(datasetRoot, catDirs(i).name);
    seqDirs = dir(catPath);
    for j = 1:numel(seqDirs)
        if ~seqDirs(j).isdir || startsWith(seqDirs(j).name,'.'), continue; end
        seqPath = fullfile(catPath, seqDirs(j).name);
        if isfolder(fullfile(seqPath,'input'))
            index(end+1) = struct('category',catDirs(i).name, ... %#ok<AGROW>
                'sequence',seqDirs(j).name,'path',seqPath);
        end
    end
end
end
