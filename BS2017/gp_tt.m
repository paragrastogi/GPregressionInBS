function gp_tt(seed, xtrain, ytrain, ...
    xtest, ytest, N, path_save_fldr, varargin)

p = inputParser;
p.FunctionName = 'gp_tt';

% Number of gp models to train. This is for the case
% when the training data set is enormous and must be split
% into subsets for training. It needs to be >1 to get
% variance of error metrics.
addRequired(p,'seed',@isnumeric)

addRequired(p,'xtrain',@ismatrix)
addRequired(p,'ytrain',@(x) (ismatrix(x) || isvector(x)))
addRequired(p,'xtest',@ismatrix)
addRequired(p,'ytest',@(x) (ismatrix(x) || isvector(x)))

% Test series, must be passed with unseen
addParameter(p, 'testser', '', @ischar)

% struct containinig 'unseen' data, usually from a different
% series. Will only be used if testser ~= trainser.
addParameter(p, 'unseen', struct(), @isstruct)

% Running in batcher mode (true) means that, in a 'string'
% of training set sizes [N(1):N(end)], for every N(a) the
% loop will 'append' training data to the set from the
% previous step N(a-1). If batcher is false, then each set
% N(a) will be randomly sampled afresh.
addParameter(p, 'batcher', false, @islogical)

% A vector (or single number) giving the size(s) of the
% subsets of training data used for each seed.
addRequired(p,'N',@isnumeric)

% Path to save the outputs
addRequired(p,'path_save_fldr',@ischar)

% Choice of models to run, default is to run all
addParameter(p,'modchoice', true(6,1), @islogical)

% Hyperparameters are already fixed.
addParameter(p,'hypfix',[],@isnumeric)
% Run mode can be -- (1) test-train, (2) deploy. Deploy
% requires fixed hyperparameters (hypfix).
addParameter(p,'rmode','tt',@ischar)

% Start the optimisation warm or not. If true, then the MLE
% uses the previous trainin data set's hyperparameters as
% the starting points for minFunc.
addParameter(p,'warm', false, @islogical)

addParameter(p, 'fnames', {'a','b','c','d'}, @iscellstr)

addParameter(p, 'optsn', false, @islogical)

parse(p, seed, xtrain, ytrain, ...
    xtest, ytest, N, path_save_fldr, varargin{:})

% trainser = p.Results.trainser;
seed = p.Results.seed;
xtrain = p.Results.xtrain;
ytrain = p.Results.ytrain;
xtest = p.Results.xtest;
ytest = p.Results.ytest;
N = p.Results.N;
path_save_fldr = p.Results.path_save_fldr;
modchoice = p.Results.modchoice;
unseen = p.Results.unseen;
warm = p.Results.warm;
rmode = p.Results.rmode;
batcher = p.Results.batcher;
fnames = p.Results.fnames;
hypfix = p.Results.hypfix;
optsn = p.Results.optsn;

diary(fullfile(path_save_fldr, ...
    sprintf('Run_%s_%d.txt', date, seed)))

% This script creates linear regression and GP models on a
% given data set. The data set should be passed to this
% script.

% Load types (output variable). 
% 1 --> heating
% 2 --> cooling


% Path to save figure files
pathFIGsave = fullfile('..','figs');
if exist(pathFIGsave, 'dir') ~= 7
    mkdir(pathFIGsave)
end


% This is the choice of models on offer.
modlist = {'meanr', 'gp-liniso', 'lin-reg', ...
    'gp-linard', 'gp-seiso', 'gp-seard'};

% Find the index of 'gp-lin' since it will be needed to call
% the lin-reg model.
gplin_idx = strcmpi(modlist,'gp-liniso');
    

% This is the number of hyperparameters that will be
% required by each function above.
hypnum = [0;1;0;size(xtrain,2);2;size(xtrain,2)+1]; 
if optsn 
    % The noise variance is not passed as a hyperparameter.
    hypnum = hypnum + 1;
end
% This is the seed value that will be passed as a start
% point to the minimise function.
hypseed = 0;

% % % Set delta here
% delta = 0*size(xtrain,1);
% % % 

% Pre-allocate the storage variables here.
ypred = zeros(length(N),length(modlist),size(ytest,1));
rmse = zeros(length(N),length(modlist));
mae = zeros(length(N),length(modlist));
hyp = zeros(length(N),length(modlist),max(hypnum));

if strcmp(rmode, 'hypcontour')
    nlz = zeros(length(N),length(modlist));
    % dnlz = zeros(length(N),length(modlist));
end

% Expected to test on 'new' data
if ~isempty(fieldnames(unseen))
   ypred_un = zeros(length(N),length(modlist), ...
       size(unseen.xin,1)); 
   rmse_un = zeros(length(N),length(modlist));
   mae_un = zeros(length(N),length(modlist));
end

% train_var_idx = false(size(xtrain,1));
train_var_idx_coll = false(length(N), size(xtrain,1));

switch rmode
    case {'tt', 'deploy'}
        % Set random seed so that it is predictable
        rng(seed, 'twister')

    case {'hypcontour'}
        rng(1, 'twister')
end

for r = 1:length(N)
    
    fprintf('N is %d\r\n', N(r))

% Size of training data set for this iteration is N(r), and
% the 'added' length is N(r) - N(r-1).

% Randomly select the data points that will be used to train
% all the models in this fit. Each seed is a different
% path. The size of the training data set is set for
% this iteration of the inner loop (N(r)). The training data
% sets picked for each iteration of this loop are not
% neccessarily mutually exclusive, i.e., it is possible to
% pick the same points in different variants.

switch rmode
    case {'tt', 'hypcontour'}
        if ~batcher || r == 1
            % Sample from the large training set. Size is N(r)
            train_idx = randi(size(xtrain,1), N(r), 1);
            % Store the new indices
            train_var_idx_coll(r,train_idx) = true;
        else
            % Sample an additional N(r) - N(r-1) points
            idx_temp = randi(size(xtrain,1), N(r) - N(r-1), 1);
            % Add them to the points from the previous step
            train_idx = [train_idx; idx_temp];
            % Store the new indices
            train_var_idx_coll(r,train_idx) = true;
        end
        
    case 'deploy'
        train_idx = true(size(ytrain));
end

for m = 1:length(modlist)
    
    
    fprintf('Model is %s\r\n', modlist{m})

% for lo = 1:2
    
if ~modchoice(m)
    
    % This model was not asked for
    fprintf('Ignoring model type %s\r\n', modlist{m})
    continue

end

% Learn the hyperparameters for the GP models. This is
% done by minimising negative log-marginal likelihood (i.e.,
% maximising log-marginal likelihood)

% In GP-lin the hyperparameter entered is the signal
% variance. The MLE often crashes for large data sets.

switch rmode
    
    case 'tt'
        
    if strcmp(modlist{m},'lin-reg')
        % The Linear Regression model, which forms the
        % 'baseline' against which all models will be
        % checked, has already been specific using a
        % linear kernel input to the GP function above.
        % This call is just to verify that the GP
        % function with a linear kernel behaves exactly
        % the same as a linear regression with a penalty
        % parameter = 1/sqrt(sf). hypin = ;
        fprintf(['Not calling training routine for ', ...
            'linear regression. \n\r', ...
            'Going to use (1/sf^2) from gp-lin.\r\n'])
        % The linear regression doesn't get a trained
        % hyper-parameter. Instead, use the reciprocal
        % of the square of the hyperparameter from
        % gp-lin. So make sure that GP-LIN precedes this
        % call. Get the sn from gp-lin (using
        % gplin_idx), from the same seed (v), and from
        % the same kind of load (lo). The last index is
        % the number of hyperparamters, which is not
        % used in this call.
        hypin = squeeze(hyp(r,gplin_idx,:));
        % Remove the NaNs from hypin, if they exist,
        % before taking the reciprocal of the square
        hypin = 1/(hypin(~isnan(hypin))^2);

    elseif strcmp(modlist{m},'meanr')
        hypin = nan;

    else
        % The hyperparameters are trained using MLE, and
        % the minimisation function needs a starting
        % point. Occasionally, the starting point is
        % inappropriate or, more likely, the covariance
        % matrix is ill-conditioned (which happens when
        % two observations have very similar x or input
        % values). If that happens then well, nothing
        % much to do except tweak things a bit! Here,
        % the starting choice is a small number and the
        % number of iterations allowed is pretty large.

        if warm
            % The starting point for the MLE optimiser are
            % the hyper-parameters that were found in the
            % previous iteration (i.e., previous choice of
            % training data set size)
            if r == 1
                % First run, so the guess is random
                hypguess = hypseed.*ones(hypnum(m),1);
            else
                % Use the hyper-parameters from the
                % previous training data size step.
                hypguess = squeeze(hyp(r-1,m,1:hypnum(m)));
            end
        else
            hypguess = hypseed.*ones(hypnum(m),1);
        end

        % Noise variance is zero inside fitGP, i.e., the cov
        % function inside receives sn = exp(0) = 1.

        try
            % Try to optimise the hyperparameters using
            % minFunc. Limit the number of iterations to
            % 100.
            options = struct();
            options.MaxIter = 100;
            hypin = minFunc(@fitGP, hypguess, options, ...
                modlist{m}, xtrain(train_idx,:), ...
                ytrain(train_idx), ...
                'gpmode', 'train'); %, 'delta', delta/N(r));
        catch err
            % If the minimization doesn't work, reset
            % the hyperparameters to the initial guesses
            fprintf('%s\r\n', err.message)
            hypin = hypguess;
        end

        drawnow

    end
    
    case {'deploy', 'hypcontour'}
        % Use the hyperparameters that were fed to the
        % function.
        if strcmp(modlist{m},'lin-reg')
            hypin = 1 / ( hypfix(gplin_idx, ...
                1:hypnum(gplin_idx))^2 );
        else
            hypin = hypfix(m,1:hypnum(m));
        end
        
end

% Now fit the data to the X of the testing set and
% calculate the prediction/loss over the testing set.

if strcmp(rmode, 'hypcontour')
    % Only the hypcontour mode needs both rmse AND nlz
    % outputs.
    [nlz_temp, ~] = fitGP(hypin, modlist{m}, ...
        xtrain(train_idx,:), ...
        ytrain(train_idx), ...
        'xtest', xtest, 'gpmode', 'train'); 
    nlz(r,m) = nlz_temp;
end


% try

% Predict on the test set.
ypred_temp = fitGP(hypin, modlist{m}, ...
    xtrain(train_idx,:), ...
    ytrain(train_idx), ...
    'xtest', xtest, 'gpmode', 'test'); 

% catch err
%     fprintf('%s\r\n',err.message)
%     ypred_temp = nan(size(xtest,1),1);
% end

% Save the output, hyper-parameters, and errors
ypred(r,m,:) = ypred_temp;

% Save hyper-parameters and errors for unseen data from
% training series.
hyp(r,m,:) = [hypin(:); nan(max(hypnum)-length(hypin),1)];
[mae(r,m), ~] = maeloss(ypred_temp, ytest(:));
[rmse(r,m), ~] = rmseloss(ypred_temp, ytest(:));

% This part will now predict on 'unseen' data. This should
% be data from another 'case study' or 'building series'.
if ~isempty(fieldnames(unseen))

try
    % Predict on the test set.
    ypred_un_temp = fitGP(hypin, modlist{m}, ...
        xtrain(train_idx,:), ...
        ytrain(train_idx), ...
        'xtest', unseen.xin, ...
        'gpmode', 'test'); %, 'delta', delta);

catch err
    fprintf('%s\r\n',err.message)
    ypred_un_temp = nan(size(unseen.xin,1),1);
end

% Save the output, hyper-parameters, and errors
ypred_un(r,m,:) = ypred_un_temp;

[mae_un(r,m), ~] = maeloss(ypred_un_temp, unseen.yin(:));

[rmse_un(r,m), ~] = rmseloss(ypred_un_temp, ...
    unseen.yin(:));


clear ypred_temp ypred_un_temp

end
    
drawnow

end

drawnow

end

drawnow
    
save(fullfile(path_save_fldr, fnames{1}), ...
    'mae','rmse','hyp', 'train_var_idx_coll')
save(fullfile(path_save_fldr, fnames{2}), ...
    'ypred', '-v7.3')

if ~isempty(fieldnames(unseen))
save(fullfile(path_save_fldr, fnames{3}), ...
    'mae_un','rmse_un')
save(fullfile(path_save_fldr, fnames{4}), ...
    'ypred_un', '-v7.3')
end

% Only save the negative lml if plotting hyperparameter
% contours later.
if strcmp(rmode, 'hypcontour')
    save(fullfile(path_save_fldr, fnames{5}), ...
    'nlz')
end

diary off

end
