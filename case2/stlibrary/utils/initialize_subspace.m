function [U0, L0, mu] = initialize_subspace(Mtrain, rankK, centerData)
%INITIALIZE_SUBSPACE Rank-k SVD warm start shared by GREAT/GeRoST.
if nargin<3, centerData=false; end
X=double(Mtrain);
if centerData
    mu=mean(X,2); Xc=X-mu;
else
    mu=zeros(size(X,1),1); Xc=X;
end
r=min([rankK,size(Xc,1),size(Xc,2)]);
[U,S,V]=svd(Xc,'econ');
U0=U(:,1:r);
L0=U(:,1:r)*S(1:r,1:r)*V(:,1:r)' + mu;
end
