function trace = record_subspace_trace(trace, diagCfg, U, Uprevious, t)
%RECORD_SUBSPACE_TRACE Record scalar reference and step chordal distances.
if ~isfield(trace,'enabled') || ~trace.enabled, return; end
stride=max(1,round(diagCfg.sampleStride));
if mod(t-1,stride)~=0 && t~=numel(trace.referenceDistance), return; end
if nargin<4 || isempty(Uprevious), Uprevious=U; end
if diagCfg.computeStepDistance
    trace.stepDistance(t)=subspace_chordal_distance(U,Uprevious,diagCfg.normalizeChordal);
end
switch lower(diagCfg.referenceType)
    case 'fixed'
        trace.referenceDistance(t)=subspace_chordal_distance( ...
            U,diagCfg.reference,diagCfg.normalizeChordal);
    case 'history'
        trace.referenceDistance(t)=subspace_chordal_distance( ...
            U,diagCfg.referenceHistory(:,:,t),diagCfg.normalizeChordal);
    otherwise
        trace.referenceDistance(t)=NaN;
end
end
