function name = normalize_algorithm_name(name)
%NORMALIZE_ALGORITHM_NAME Canonicalize benchmark algorithm identifiers.
s = lower(strtrim(char(name)));
switch s
    case 'grasta', name='GRASTA';
    case {'reprocs','re-procs'}, name='ReProCS';
    case 'great', name='GREAT';
    case {'gerost','ge-rost'}, name='GeRoST';
    otherwise, error('Unknown algorithm: %s', s);
end
end
