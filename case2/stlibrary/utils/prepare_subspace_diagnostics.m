function d = prepare_subspace_diagnostics(seq, sharedInit, cfg)
%PREPARE_SUBSPACE_DIAGNOSTICS Resolve a true/reference subspace for traces.
%
% CDnet does not provide a ground-truth latent subspace. In referenceMode
% 'auto', an explicit true/reference basis is used when available; otherwise
% no reference-error curve is produced. Use referenceMode='initial' only when
% you explicitly want drift from the shared U0 (a proxy, not ground truth).
%
% Optional true/reference inputs can be supplied in cfg.diagnostics.subspace:
%   trueSubspace          n-by-r
%   trueSubspaceHistory   n-by-r-by-T
%   referenceSubspace     n-by-r
%   referenceHistory      n-by-r-by-T
%
% A synthetic sequence struct may also expose trueSubspace or
% trueSubspaceHistory fields. Mode 'true' requires a true basis; mode
% 'provided' requires one of the generic reference fields.

n = size(seq.M,1); T = seq.numFrames;
d = struct('enabled',false,'referenceType','none','reference',[], ...
    'referenceHistory',[],'referenceLabel','', ...
    'referenceIsGroundTruth',false,'normalizeChordal',true, ...
    'sampleStride',1,'computeStepDistance',true);

if ~isfield(cfg,'output') || ~isfield(cfg.output,'makeTimeMetricPdfs') || ...
        ~cfg.output.makeTimeMetricPdfs
    return;
end
if ~isfield(cfg,'diagnostics') || ~isfield(cfg.diagnostics,'subspace') || ...
        ~cfg.diagnostics.subspace.enabled
    return;
end
s = cfg.diagnostics.subspace;
if ~isfield(s,'referenceMode') || isempty(s.referenceMode), s.referenceMode='auto'; end
if ~isfield(s,'normalizeChordal') || isempty(s.normalizeChordal), s.normalizeChordal=true; end
if ~isfield(s,'sampleStride') || isempty(s.sampleStride), s.sampleStride=1; end
if ~isfield(s,'computeStepDistance') || isempty(s.computeStepDistance), s.computeStepDistance=true; end
mode = lower(string(s.referenceMode));
if ~any(mode == ["auto","true","provided","initial","none"])
    error('SubspaceBenchmark:BadSubspaceReferenceMode', ...
        'subspace referenceMode must be auto, true, provided, initial, or none.');
end

d.enabled = true;
d.normalizeChordal = logical(s.normalizeChordal);
d.sampleStride = max(1,round(s.sampleStride));
d.computeStepDistance = logical(s.computeStepDistance);
if mode == "none"
    return;
end

% Gather candidate truth/reference objects without copying them unnecessarily.
trueHist = field_or_empty(s,'trueSubspaceHistory');
trueFixed = field_or_empty(s,'trueSubspace');
refHist = field_or_empty(s,'referenceHistory');
refFixed = field_or_empty(s,'referenceSubspace');
if isempty(trueHist) && isfield(seq,'trueSubspaceHistory'), trueHist=seq.trueSubspaceHistory; end
if isempty(trueHist) && isfield(seq,'trueSubspaces'), trueHist=seq.trueSubspaces; end
if isempty(trueFixed) && isfield(seq,'trueSubspace'), trueFixed=seq.trueSubspace; end

if mode == "true" || mode == "auto"
    if ~isempty(trueHist)
        validate_history(trueHist,n,T,'trueSubspaceHistory');
        d.referenceType='history'; d.referenceHistory=trueHist;
        d.referenceLabel='true subspace'; d.referenceIsGroundTruth=true;
        return;
    elseif ~isempty(trueFixed)
        validate_fixed(trueFixed,n,'trueSubspace');
        d.referenceType='fixed'; d.reference=trueFixed;
        d.referenceLabel='true subspace'; d.referenceIsGroundTruth=true;
        return;
    elseif mode == "true"
        error('SubspaceBenchmark:MissingTrueSubspace', ...
            'referenceMode=true requires trueSubspace or trueSubspaceHistory.');
    end
end

if mode == "provided" || mode == "auto"
    if ~isempty(refHist)
        validate_history(refHist,n,T,'referenceHistory');
        d.referenceType='history'; d.referenceHistory=refHist;
        d.referenceLabel=custom_label(s,'provided reference subspace');
        return;
    elseif ~isempty(refFixed)
        validate_fixed(refFixed,n,'referenceSubspace');
        d.referenceType='fixed'; d.reference=refFixed;
        d.referenceLabel=custom_label(s,'provided reference subspace');
        return;
    elseif mode == "provided"
        error('SubspaceBenchmark:MissingReferenceSubspace', ...
            'referenceMode=provided requires referenceSubspace or referenceHistory.');
    end
end

% Do not silently turn the shared initialization into a pseudo-ground-truth
% curve in auto mode. On CDnet that quantity is only drift from U0 and can
% be visually dramatic without implying tracking error. It remains available
% explicitly via referenceMode='initial'.
if mode == "initial"
    d.referenceType='fixed';
    d.reference=sharedInit.U0;
    d.referenceLabel='common initial subspace (drift proxy; not ground truth)';
    d.referenceIsGroundTruth=false;
elseif mode == "auto"
    d.referenceType='none';
    d.reference=[];
    d.referenceHistory=[];
    d.referenceLabel='';
    d.referenceIsGroundTruth=false;
end
end

function v=field_or_empty(s,f)
if isfield(s,f), v=s.(f); else, v=[]; end
end

function label=custom_label(s,defaultLabel)
if isfield(s,'referenceLabel') && ~isempty(s.referenceLabel)
    label=char(string(s.referenceLabel));
else
    label=defaultLabel;
end
end

function validate_fixed(U,n,name)
if ndims(U)~=2 || size(U,1)~=n || isempty(U) || any(~isfinite(U(:)))
    error('SubspaceBenchmark:BadSubspaceReference', ...
        '%s must be a finite n-by-r basis with n=%d.',name,n);
end
end

function validate_history(U,n,T,name)
if ndims(U)~=3 || size(U,1)~=n || size(U,3)~=T || isempty(U) || any(~isfinite(U(:)))
    error('SubspaceBenchmark:BadSubspaceReferenceHistory', ...
        '%s must be finite n-by-r-by-T with n=%d and T=%d.',name,n,T);
end
end
