function [xtrain, ytrain, xtest, ytest, test_idx] = ...
    mastersplitter(xin, yin, testfrac)

% Changing the last number of this function call will change
% the relative size of the training and testing sets. For
% example, 0.5 means that the master testing set is composed
% of 50% of the total data points.

if testfrac>1
    testfrac = testfrac/100;
    fprintf(['Hey, how is the testfrac bigger than '...
        'one? I''m assuming you put in percentage, ', ...
        'so I have divided by 100.\r\n'])
end

test_size = round(size(xin,1)*testfrac);
test_idx = false(size(xin,1),1);
test_idx(randi(size(xin,1),test_size,1)) = true;

% Take x and y for testing
xtest = xin(test_idx,:);
ytest = yin(test_idx,:);

% Take the remaining data for training and validation.
xtrain = xin(~test_idx,:);
ytrain = yin(~test_idx,:);

% % % % % % % %

% Delete the composite matrices, they can be recomposed
% later.
clear xin yin

end