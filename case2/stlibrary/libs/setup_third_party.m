function report = setup_third_party(varargin)
%SETUP_THIRD_PARTY Fetch open-source algorithm dependencies into libs/.
%   setup_third_party
%   setup_third_party('Force', true)
%
% Git is preferred because it preserves upstream license files and source
% provenance. A normal Git installation on PATH is required.

p = inputParser;
p.addParameter('Force', false, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});
force = p.Results.Force;

libsRoot = fileparts(mfilename('fullpath'));
[status, ~] = system('git --version');
if status ~= 0
    error('SubspaceBenchmark:GitRequired', ...
        'Git is required. Install Git, ensure git is on PATH, then rerun setup_third_party.');
end

items = {};
items{end+1} = fetch_repo('ReProCS', 'https://github.com/praneethmurthy/ReProCS.git', ...
    fullfile(libsRoot,'ReProCS'), 'master', force);
items{end+1} = fetch_repo('GeRoST', 'https://github.com/shreyasnb/GeRoST.git', ...
    fullfile(libsRoot,'GeRoST'), 'main', force);
items{end+1} = fetch_repo('Manopt', 'https://github.com/NicolasBoumal/manopt.git', ...
    fullfile(libsRoot,'manopt'), 'master', force);

% GRASTA is copied from the LRSLibrary ST/GRASTA directory so the benchmark
% uses the same source family as the requested reference library.
cacheRoot = fullfile(libsRoot, '.cache');
if ~isfolder(cacheRoot), mkdir(cacheRoot); end
lrsCache = fullfile(cacheRoot, 'lrslibrary');
lrsInfo = fetch_repo('LRSLibrary-cache', 'https://github.com/andrewssobral/lrslibrary.git', ...
    lrsCache, 'master', force);
grastaSrc = fullfile(lrsCache, 'algorithms','st','GRASTA');
grastaDst = fullfile(libsRoot,'GRASTA');
if force && isfolder(grastaDst), rmdir(grastaDst,'s'); end
if ~isfolder(grastaDst)
    assert(isfolder(grastaSrc), 'GRASTA source was not found in the LRSLibrary checkout.');
    copyfile(grastaSrc, grastaDst);
end
items{end+1} = struct('name','GRASTA','path',grastaDst,'status','ready','revision',lrsInfo.revision);

st_setup();
missing = check_dependencies(fileparts(libsRoot));
if ~isempty(missing)
    warning('SubspaceBenchmark:DependencyCheck', 'Still missing: %s', strjoin(missing, ', '));
end
report = struct2table([items{:}]);
disp(report);
writetable(report, fullfile(libsRoot,'installed_versions.csv'));
fid=fopen(fullfile(libsRoot,'installed_versions.txt'),'w');
if fid>=0
    c=onCleanup(@()fclose(fid)); %#ok<NASGU>
    for i=1:height(report), fprintf(fid,'%s %s\n',char(string(report.name(i))),char(string(report.revision(i)))); end
end
end

function info = fetch_repo(name, url, dest, branch, force)
if force && isfolder(dest)
    rmdir(dest, 's');
end
if ~isfolder(dest)
    parent = fileparts(dest);
    if ~isfolder(parent), mkdir(parent); end
    cmd = sprintf('git clone --depth 1 --branch "%s" "%s" "%s"', branch, url, dest);
    fprintf('Fetching %s...\n', name);
    [status, output] = system(cmd);
    if status ~= 0
        error('SubspaceBenchmark:GitCloneFailed', 'Could not fetch %s:\n%s', name, output);
    end
    state = 'cloned';
else
    state = 'already-present';
end
[revStatus, revision] = system(sprintf('git -C "%s" rev-parse HEAD', dest));
if revStatus~=0, revision='unknown'; else, revision=strtrim(revision); end
info = struct('name',name,'path',dest,'status',state,'revision',revision);
end
