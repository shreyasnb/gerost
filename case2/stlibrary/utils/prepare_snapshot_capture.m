function [idx, slotMap, background] = prepare_snapshot_capture(context, n, T)
%PREPARE_SNAPSHOT_CAPTURE Allocate only the requested background columns.
%
% [idx, slotMap, background] = PREPARE_SNAPSHOT_CAPTURE(context,n,T)
% returns the requested local frame indices, a T-element lookup mapping a
% local frame index to its snapshot column, and an n-by-numel(idx) array.
% When no snapshots were requested all three outputs are effectively empty.

idx=[];
slotMap=zeros(1,T);
background=[];
if ~isfield(context,'snapshotIndices') || isempty(context.snapshotIndices)
    return;
end
idx=unique(round(context.snapshotIndices(:)'),'stable');
idx=idx(idx>=1 & idx<=T);
if isempty(idx), return; end
slotMap(idx)=1:numel(idx);
if isfield(context,'scoreClass') && ~isempty(context.scoreClass)
    cls=context.scoreClass;
else
    cls='single';
end
background=zeros(n,numel(idx),cls);
end
