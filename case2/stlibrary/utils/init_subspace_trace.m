function trace = init_subspace_trace(context, T)
%INIT_SUBSPACE_TRACE Allocate only scalar subspace diagnostic traces.
trace = struct('enabled',false,'referenceDistance',[], ...
    'stepDistance',[],'referenceLabel','','referenceIsGroundTruth',false, ...
    'normalized',false,'sampleStride',1);
if ~isfield(context,'subspaceDiagnostics') || isempty(context.subspaceDiagnostics) || ...
        ~isfield(context.subspaceDiagnostics,'enabled') || ~context.subspaceDiagnostics.enabled
    return;
end
d=context.subspaceDiagnostics;
trace.enabled=true;
trace.referenceDistance=nan(1,T);
trace.stepDistance=nan(1,T);
trace.referenceLabel=d.referenceLabel;
trace.referenceIsGroundTruth=d.referenceIsGroundTruth;
trace.normalized=d.normalizeChordal;
trace.sampleStride=d.sampleStride;
end
