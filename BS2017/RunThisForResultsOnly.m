% RunThisEmti

ser = 'BaseSimulation';

% This MAT file contains xin and yin, and their
% corresponding means and stdevs. These values are
% standardised from the physical values, so the means and
% stdevs can be used to recover the originals. The cell
% arrays xlabels and ylabels have, well, labels.
load('gpdata_BaseSimulation.mat')


% Load type (output variable), convention.
% 1 --> heating
% 2 --> cooling
% Which load type do you want to load?
lo = 1;

% These are the seeds (bootstrap samples) you want loaded.
seeds = 1:100;
% If vector, then all the seeds in the vector are loaded.

pathMATfolder = 'Data';

% Load a standalone MAT file that contains some useful
% information like the index of test values.
% Find all the trainN* dated files.
findfile = dir(fullfile(pathMATfolder, 'trainN*'));
% If there are more than one, pick the latest one
if size(findfile,1)>=1
    for d = 1:size(findfile,1)
        datefile = datenum(findfile(d).date);
        if d == 1
            datestore = datefile;
            indstore = d;
        else
            if datefile>datestore
                datestore = datefile;
                indstore = d;
            end
        end
    end
    load(fullfile(pathMATfolder, findfile(indstore).name))
else
    % Training parameters were not saved, e.g., in a
    % 'deployment' run
    N = 4000;
    test_idx = true(size(yin,1),1);
end

% Assign ytest.
ytest = yin(test_idx,lo);

% This is the choice of models on offer.
modlist = {'meanr', 'lin-reg', 'gp-liniso', ...
    'gp-linard', 'gp-seiso', 'gp-seard'};
modnames = {'Mean', 'Lin-Reg', 'Lin-Iso', ...
    'Lin-ARD', 'NonLin-Iso', 'NonLin-ARD'};

% Load results for the relevant seeds
[mae_coll, rmse_coll, hyp_coll, ypred_coll] = ...
    LoadResults(ser, seeds, lo, pathMATfolder);

% The hyp_coll contains hyperparameters. Its dimensions are:
% N x m x D x seeds
% Training set sizes x models x number of hyperparamters x
% number of seeds
% The max hyperparameters are in the ARD model - 28 + 1 + 1
% The rest have less, of course, so they contain a lot of
% nans.

% Taking out the SE-ISO hyper-parameters
hyp_seiso = squeeze(hyp_coll(:,strcmp(modlist,'seiso'),:,:));