function tests = test_gerost_reduced_innermax
tests=functiontests(localfunctions);
end

function testReducedInnerMatchesReference(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); st_setup();
vendor=fullfile(root,'libs','GeRoST');
assumeTrue(testCase,isfile(fullfile(vendor,'gerost.m')),'GeRoST dependency not installed.');
algDir=fullfile(root,'algorithms','st','GeRoST');
old=path; addpath(algDir); addpath(genpath(vendor)); c=onCleanup(@()path(old)); %#ok<NASGU>

rng(7);
n=80; k=3; d=5; rho=0.08;
[Y,~]=qr(randn(n,k),0); [What,~]=qr(randn(n,d),0);
[Wref,lamRef]=gerost.inner_max(Y,What,rho,d);
assumeGreaterThan(testCase,lamRef,2);
[lamFast,WWtYfast,Nfast]=gerost_inner_max_reduced(Y,What,rho,d,1e-8,48);
WWtYref=Wref*(Wref'*Y);
Nref=Y'*WWtYref; Nref=(Nref+Nref')/2;
verifyLessThanOrEqual(testCase,abs(lamFast-lamRef),2e-6);
verifyLessThanOrEqual(testCase,norm(WWtYfast-WWtYref,'fro'),2e-5);
verifyLessThanOrEqual(testCase,norm(Nfast-Nref,'fro'),2e-5);
end
