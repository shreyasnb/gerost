function d = subspace_chordal_distance(U, V, normalizeDistance)
%SUBSPACE_CHORDAL_DISTANCE Projector/chordal distance between column spaces.
%
% The inputs are treated as bases for subspaces, not as already-perfectly
% orthonormal matrices. A thin QR is therefore applied before the distance
% is computed. This makes diagnostics invariant to harmless basis scaling
% and protects against numerical loss of orthogonality in long tracker runs.
%
% For equal-dimensional orthonormal bases this is
%       sqrt(r - ||U'*V||_F^2)
% which equals ||UU' - VV'||_F / sqrt(2).
%
% If the dimensions differ, the symmetric projector-distance extension is
%       sqrt((rU+rV)/2 - ||U'*V||_F^2).
%
% When normalizeDistance is true, divide by sqrt((rU+rV)/2).

if nargin < 3 || isempty(normalizeDistance), normalizeDistance = false; end
if isempty(U) || isempty(V), d = NaN; return; end
if size(U,1) ~= size(V,1)
    error('SubspaceBenchmark:SubspaceDimensionMismatch', ...
        'Subspace bases must have the same ambient dimension.');
end
U = double(U); V = double(V);
if any(~isfinite(U(:))) || any(~isfinite(V(:)))
    d = NaN; return;
end

% Orthonormalize the represented column spaces. QR is cheap because tracker
% ranks are small and diagnostic time is excluded from benchmark runtime.
[Uq,Ru] = qr(U,0);
[Vq,Rv] = qr(V,0);
rU = numerical_rank_from_r(Ru,size(U,1),size(U,2));
rV = numerical_rank_from_r(Rv,size(V,1),size(V,2));
if rU==0 || rV==0, d=NaN; return; end
Uq=Uq(:,1:rU); Vq=Vq(:,1:rV);

crossSq = norm(Uq' * Vq, 'fro')^2;
d2 = max(0, 0.5*(rU+rV) - crossSq);
d = sqrt(d2);
if normalizeDistance
    scale = sqrt(max(0.5*(rU+rV), eps));
    d = d / scale;
end
end

function r = numerical_rank_from_r(R,m,n)
if isempty(R), r=0; return; end
s=abs(diag(R));
if isempty(s), r=0; return; end
tol=max(m,n)*eps(max(s));
r=sum(s>tol);
end
