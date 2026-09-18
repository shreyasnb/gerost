function [lambdaStar, WWtY, Nhat, info] = gerost_inner_max_reduced(Y, What, rho, d, tol, maxIter)
%GEROST_INNER_MAX_REDUCED Low-rank inner maximization for GeRoST.
%
% Algebraically equivalent to gerost.inner_max for lambda > 2, but all
% bisection eigendecompositions are performed in span([Y, What]), whose
% dimension is at most k+d. The ambient n-by-(k+d) basis is constructed
% once per inner solve instead of once per bisection function evaluation.
%
% Outputs WWtY = Wstar*(Wstar'*Y) and Nhat=(Y'*Wstar)*(Wstar'*Y), which are
% exactly the quantities needed by the GeRoST gradient/Lipschitz update.
% When the constraint is inactive (lambdaStar == 2), WWtY/Nhat are empty
% because the caller follows the configured fallback gradient.

if nargin < 5 || isempty(tol), tol = 1e-6; end
if nargin < 6 || isempty(maxIter), maxIter = 32; end

tol=max(double(tol),eps);
maxIter=max(1,round(maxIter));
k=size(Y,2);
LAMBDA_MIN=2+1e-6;

% B_t(lambda) = lambda*What*What' - Y*Y' has range contained in
% span([Y,What]). Since What is already orthonormal, only orthogonalize the
% component of Y outside What. This constructs the ambient basis ONCE per
% inner solve and requires orth() on at most n-by-k rather than n-by-(d+k).
Yperp=Y-What*(What'*Y);
Qperp=orth(Yperp);
Q=[What,Qperp];
qrank=size(Q,2);
if qrank < d
    error('SubspaceBenchmark:GeRoSTReducedBasis', ...
        'Reduced GeRoST basis has dimension %d < requested d=%d.',qrank,d);
end
QY=Q'*Y;
QW=Q'*What;

lamLo=LAMBDA_MIN;
lamHi=2+sqrt(k)/max(rho,1e-10);
[~,dcLo]=topd_small(QY,QW,lamLo,d);
hLo=dcLo-rho;

info=struct('basisDimension',qrank,'bisectionIterations',0, ...
    'constraintActive',false,'distance',dcLo,'lambdaLo',lamLo,'lambdaHi',lamHi);

if hLo <= 0
    lambdaStar=2.0;
    WWtY=[];
    Nhat=[];
    return;
end

[~,dcHi]=topd_small(QY,QW,lamHi,d);
hHi=dcHi-rho;
if hHi >= 0
    lambdaStar=lamHi;
else
    for iter=1:maxIter
        lamMid=(lamLo+lamHi)/2;
        [~,dcMid]=topd_small(QY,QW,lamMid,d);
        if dcMid-rho > 0
            lamLo=lamMid;
        else
            lamHi=lamMid;
        end
        info.bisectionIterations=iter;
        if abs(lamHi-lamLo) <= tol
            break;
        end
    end
    lambdaStar=(lamLo+lamHi)/2;
end

% Construct only the action P_Wstar*Y; the full n-by-d Wstar matrix is not
% needed by the outer gradient. This avoids another large intermediate.
[Z,dcFinal]=topd_small(QY,QW,lambdaStar,d);
C=Z'*QY;                    % Wstar' * Y
WWtY=Q*(Z*C);               % Wstar * (Wstar' * Y)
Nhat=C'*C;                  % Y' * P_Wstar * Y
Nhat=(Nhat+Nhat')/2;
info.constraintActive=lambdaStar>2;
info.distance=dcFinal;
end

function [Z,dc]=topd_small(QY,QW,lambda,d)
M=-QY*QY' + lambda*(QW*QW');
M=(M+M')/2;
[V,D]=eig(M,'vector');
[~,idx]=sort(real(D),'descend');
Z=V(:,idx(1:d));
% Match the upstream chordal-distance computation, but in the tiny
% reduced coordinates. Singular values should lie in [0,1]; min() keeps
% roundoff from making the square-root argument slightly negative.
C=Z'*QW;
svals=svd(C);
overlap=sum(min(svals,1).^2);
dc=sqrt(max(d-overlap,0));
end
