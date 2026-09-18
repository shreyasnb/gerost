function save_algorithm_result(result, seq, cfg, outDir)
%SAVE_ALGORITHM_RESULT Persist result and optional per-frame masks/background.
algDir=fullfile(outDir,result.algorithm); if ~isfolder(algDir),mkdir(algDir);end
if cfg.output.saveMat
    compact=result;
    % Strip runtime class state/function handles; keep parameters and metrics.
    compact=rmfield_if_exists(compact,{'tracker','state','nativeSparse'});
    if ~cfg.output.saveBackground, compact=rmfield_if_exists(compact,{'L'}); end
    if ~cfg.output.saveMasks, compact=rmfield_if_exists(compact,{'mask','nativeMask'}); end
    compact=rmfield_if_exists(compact,{'S'});
    if ~cfg.output.saveScores, compact=rmfield_if_exists(compact,{'score'}); end
    saveTrace=isfield(cfg,'diagnostics') && isfield(cfg.diagnostics,'saveTraceData') && cfg.diagnostics.saveTraceData;
    if ~saveTrace, compact=rmfield_if_exists(compact,{'diagnostics'}); end
    sequenceInfo=rmfield_if_exists(seq,{'M','groundTruth'});
    % Avoid accidentally embedding a large supplied true/reference subspace
    % trajectory in every result.mat when only the final PDFs are wanted.
    cfg=strip_reference_arrays(cfg,saveTrace);
    save(fullfile(algDir,'result.mat'),'compact','sequenceInfo','cfg','-v7.3');
end
if cfg.output.saveMasks
    maskDir=fullfile(algDir,'masks'); if ~isfolder(maskDir),mkdir(maskDir);end
    for t=1:seq.numFrames
        imwrite(uint8(255*reshape(result.mask(:,t),seq.height,seq.width)), ...
            fullfile(maskDir,sprintf('bin%06d.png',seq.frameNumbers(t))));
    end
end
end
function s=rmfield_if_exists(s,names)
for i=1:numel(names), if isfield(s,names{i}),s=rmfield(s,names{i});end,end
end

function cfg=strip_reference_arrays(cfg,keep)
if keep || ~isfield(cfg,'diagnostics') || ~isfield(cfg.diagnostics,'subspace'), return; end
names={'trueSubspace','trueSubspaceHistory','referenceSubspace','referenceHistory'};
for i=1:numel(names)
    if isfield(cfg.diagnostics.subspace,names{i})
        cfg.diagnostics.subspace.(names{i})=[];
    end
end
end
