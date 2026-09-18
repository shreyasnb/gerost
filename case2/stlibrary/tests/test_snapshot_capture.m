function tests = test_snapshot_capture
tests=functiontests(localfunctions);
end

function testRequestedColumnsOnly(testCase)
context=struct('snapshotIndices',[2 7],'scoreClass','single');
[idx,map,bg]=prepare_snapshot_capture(context,12,10);
verifyEqual(testCase,idx,[2 7]);
verifyEqual(testCase,map(2),1);
verifyEqual(testCase,map(7),2);
verifyEqual(testCase,nnz(map),2);
verifySize(testCase,bg,[12 2]);
verifyClass(testCase,bg,'single');
end

function testNoRequestIsEmpty(testCase)
context=struct('scoreClass','single');
[idx,map,bg]=prepare_snapshot_capture(context,12,10);
verifyEmpty(testCase,idx);
verifyEqual(testCase,map,zeros(1,10));
verifyEmpty(testCase,bg);
end
