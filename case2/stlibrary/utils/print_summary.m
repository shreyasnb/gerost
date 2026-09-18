function print_summary(T)
%PRINT_SUMMARY Display the most useful benchmark columns.
if isempty(T), return; end
vars={'Algorithm','Status','F1','AUC','Precision','Recall','Runtime','FPS','Threshold'};
vars=vars(ismember(vars,T.Properties.VariableNames));
disp(T(:,vars));
end
