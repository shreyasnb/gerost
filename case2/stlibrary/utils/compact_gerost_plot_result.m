function r = compact_gerost_plot_result(result)
%COMPACT_GEROST_PLOT_RESULT Keep only scalar histories needed for rho/lambda/xi plots.
r=struct();
if ~isstruct(result) || ~isfield(result,'state') || ~isstruct(result.state), return; end
keepState={'xiProxyHistory','pHistory','xiOperationalHistory','rhoHistory','lambdaStarHistory','lambdaHistory', ...
    'rhoNsrCap','rhoScale','xiProxyDefinition','innerMaxImplementation','bisectTol','bisectMaxIter'};
st=struct();
for i=1:numel(keepState)
    f=keepState{i};
    if isfield(result.state,f), st.(f)=result.state.(f); end
end
if isempty(fieldnames(st)), return; end
r.algorithm='GeRoST';
r.state=st;
if isfield(result,'initialization'), r.initialization=result.initialization; end
if isfield(result,'options')
    o=struct();
    names={'trainingFrames','rhoNsrCap','rhoScale','adaptiveRho'};
    for i=1:numel(names)
        if isfield(result.options,names{i}), o.(names{i})=result.options.(names{i}); end
    end
    r.options=o;
end
end
