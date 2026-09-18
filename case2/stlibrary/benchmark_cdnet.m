function allResults = benchmark_cdnet(cfg)
%BENCHMARK_CDNET Run all configured algorithms over multiple CDnet sequences.

if nargin < 1 || isempty(cfg), cfg = benchmark_config(); end
st_setup();
index = list_cdnet_sequences(cfg.dataset.root);

if isfield(cfg.dataset, 'categories') && ~any(strcmpi(cfg.dataset.categories, 'all'))
    index = index(ismember(lower(string({index.category})), lower(string(cfg.dataset.categories))));
end
if isfield(cfg.dataset, 'sequences') && ~any(strcmpi(cfg.dataset.sequences, 'all'))
    index = index(ismember(lower(string({index.sequence})), lower(string(cfg.dataset.sequences))));
end

allTables = cell(numel(index),1);
runInfo = cell(numel(index),1);
for i = 1:numel(index)
    local = cfg;
    local.dataset.category = index(i).category;
    local.dataset.sequence = index(i).sequence;
    fprintf('\n=== Sequence %d/%d: %s/%s ===\n', i, numel(index), index(i).category, index(i).sequence);
    s = run_all_algorithms(local);
    T = s.table;
    T.Category = repmat(string(index(i).category), height(T), 1);
    T.Sequence = repmat(string(index(i).sequence), height(T), 1);
    allTables{i} = T;
    runInfo{i} = s.outputDir;
end

if isempty(allTables)
    Tall = table();
else
    Tall = vertcat(allTables{:});
end
if ~isfolder(cfg.output.root), mkdir(cfg.output.root); end
writetable(Tall, fullfile(cfg.output.root, 'cdnet_all_results.csv'));
save(fullfile(cfg.output.root, 'cdnet_all_results.mat'), 'Tall', 'runInfo');
allResults = struct('table', Tall, 'outputDirs', {runInfo});
end
