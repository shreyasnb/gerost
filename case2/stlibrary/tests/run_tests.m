function results = run_tests()
root=fileparts(fileparts(mfilename('fullpath'))); st_setup();
results=runtests(fullfile(root,'tests')); disp(table(results));
end
