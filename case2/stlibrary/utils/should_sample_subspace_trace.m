function tf = should_sample_subspace_trace(trace,t)
%SHOULD_SAMPLE_SUBSPACE_TRACE True when this frame needs chordal diagnostics.
if ~isstruct(trace) || ~isfield(trace,'enabled') || ~trace.enabled
    tf=false; return;
end
stride=1;
if isfield(trace,'sampleStride') && ~isempty(trace.sampleStride)
    stride=max(1,round(trace.sampleStride));
end
T=numel(trace.referenceDistance);
tf=(mod(t-1,stride)==0) || (t==T);
end
