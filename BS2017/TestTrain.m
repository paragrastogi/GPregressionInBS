function TestTrain(trainser, testser, lo, seeds, ...
    owrite, warm, path_save_fldr)

% This script calls the Regression Script for training AND
% testing. For deployment only, i.e., predicting on a
% new data set only, use DeployGP.m .

% This script will produce the errs_*, ystore_* and trainN*
% mat files. These files can then be used to produce the
% following figures:
% 1. RMSE vs N
% 2. RMSE comparison - non-linear vs linear, iso vs ard

% The name of the data "series" that are currently being
% processed should be in trainser (train series) and testser
% (test series, can be same as train).

% Run mode, either test-train or deploy. Not extensively
% tested as of 2016-12-20.
rmode = 'tt';

% The features that should be used in this run. 
features = true(28, 1);

% lo refers to the loadtype being fit - heating or cooling.
% 'seeds' is the number of variations of training data

% owrite will overwrite existing files or not.
% warm will do a warm start or not.

% path_save_fldr is the path to the folder where all files
% will be saved.


% These are the number of data points that will be used to
% train the model. 
N = [50; 100; 200; (500:500:1000)'; (2000:1000:4000)'];

% Choose the models that you want to run.
modchoice = true(6,1);
% modlist = {'meanr', 'gp-lin', 'lin-reg', 'gp-liniso', ...
%     'gp-linard', 'gp-seiso', 'gp-seard'};

% Running in batcher mode (true) means that, in a 'string'
% of training set sizes [N(1):N(end)], for every N(a) the
% loop will 'append' training data to the set from the
% previous step N(a-1). If batcher is false, then each set
% N(a) will be randomly sampled afresh.
batcher = true;

% Call a small housekeeping script that loads the data. It
% needs four inputs: ser, features, lo, path_save_fldr
[xin, yin] = housekeeping(trainser, lo, ...
    features, path_save_fldr);

% Repeat for test ser, if it is different.
if strcmp(testser,trainser)
    fprintf(['Train Series (%s) is the same as ', ...
        'Test Series (%s) so I''m not loading ', ...
        'unseen.\r\n'], trainser, testser)
else
    [unseen.xin, unseen.yin] = housekeeping(testser, ...
        lo, features, path_save_fldr);
end

% We will be dividing the overall data set into three parts,
% using the nomenclature and rough division proposed by
% Hastie et al. (2009, pg. 222)

% First, take out the testing data set. This is fixed for a
% given run of this script, and not 'touched' during the
% fitting procedure.

rng(size(xin,1),'twister')

% Call the mastersplitter with 60% taken out for test data
testfrac = 0.6;
[xtrain, ytrain, xtest, ytest, test_idx] = ...
    mastersplitter(xin, yin, testfrac);

% Save test_idx and N for plotting and stuff.
save(fullfile(path_save_fldr, ...
    sprintf('trainN_%s_%s', trainser, date)), ...
    'test_idx','N')

clear test_idx

% Call the gp_tt function, 'seeds' times

for s = seeds
    
    % These file names are created dynamically and stored
    % inside the gp_tt function.
    fnames{1} = sprintf('errs_%s_%d_%d.mat', trainser, s, lo);
    fnames{2} = sprintf('ystore_%s_%d_%d.mat', trainser, s, lo);
    fnames{3} = sprintf('errs_un_%s_%d_%d.mat', trainser, s, lo);
    fnames{4} = sprintf('ystore_un_%s_%d_%d.mat', trainser, s, lo);
    fnames{5} = sprintf('nlz_%s_%d_%d.mat', trainser, s, lo);

    if exist(fullfile(path_save_fldr, fnames{1}), 'file') == 2 ...
            && exist(fullfile(path_save_fldr, fnames{2}), 'file') == 2 ...
            && exist(fullfile(path_save_fldr, fnames{3}), 'file') == 2 ...
                && exist(fullfile(path_save_fldr, fnames{4}), 'file') == 2
        if owrite
            fprintf(['File name exists for variant no. %d,\r', ...
                'and I am overwriting the existing files for \r', ...
                'this iteration of variant.\r\n'], s);
        else
            fprintf(['File name exists for variant no. %d,\r', ...
                'so I am skipping this iteration of variant.\r\n'], s);
            continue
        end
    end
    
    if strcmp(trainser, testser)
        
        % Call gp_tt without unseen data
        gp_tt(s,xtrain,ytrain, ...
            xtest, ytest, N, path_save_fldr, ...
            'warm', warm, 'rmode', rmode, ...            
            'modchoice', modchoice, ...
            'batcher', batcher, 'fnames', fnames);
        
    else
        
        % Call gp_tt with unseen data
        gp_tt(s, xtrain, ytrain, xtest, ...
            ytest, N, path_save_fldr, ...
            'testser', testser, 'unseen', unseen, ...
            'warm', warm, 'rmode', rmode, ...
            'modchoice', modchoice, ...
            'batcher', batcher, 'fnames', fnames);
        
    end
    
    % End of seeds loop
end


% End of function
end
