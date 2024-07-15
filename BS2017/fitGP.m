function varargout = fitGP(hypin, model, xtrain, ytrain, varargin)

p = inputParser;
p.FunctionName = 'fitGP';

% hyper-parameters
addRequired(p,'hypin',@(x) (isstruct(x) | isnumeric(x)))
% Model type to be trained
addRequired(p,'model',@ischar)
% Training inputs
addRequired(p,'xtrain',@isnumeric)
addRequired(p,'ytrain',@isnumeric)
% Test inputs
addParameter(p,'xtest',[],@isnumeric)
% addParameter(p,'ytest',[],@isnumeric)
% % Validation inputs
% addParameter(p,'xval',[],@isnumeric)
% addParameter(p,'yval',[],@isnumeric)
% addParameter(p,'polydegin',2,@isnumeric)
addParameter(p,'gpmode', 'train', @ischar)

% Do you want the optimiser to also change the noise
% variance (sn)?
addParameter(p,'optsn',false,@islogical)
addParameter(p, 'silence', true, @islogical)

% addParameter(p, 'delta', 0, @isnumeric)


parse(p, hypin, model, xtrain, ytrain, varargin{:})

hypin = p.Results.hypin;
model = lower(p.Results.model);
xtrain = p.Results.xtrain;
ytrain = p.Results.ytrain;
xtest = p.Results.xtest;
% ytest = p.Results.ytest;
gpmode = p.Results.gpmode;
% xval = p.Results.xval;
% yval = p.Results.yval;
silence = p.Results.silence;
optsn = p.Results.optsn;
% delta = p.Results.delta;

if isempty(xtest)
    if ~silence
    fprintf(['You skipped the validation data. ', ...
        'I''m assuming this is a run to optimise ', ...
        'hyper-parameters (inside an MLE routine).\r\n'])
    end
    gpmode = 'train';
end

if ~silence
switch gpmode
    case 'train'
    fprintf('fitGP function call is in "train" mode.\r\n')
    case 'test'
    fprintf('fitGP function call is in "test" mode.\r\n')
    case 'deploy'
    fprintf('fitGP function call is in "deploy" mode.\r\n')
end
end

% % Set the noise variance to a constant. Using zero here, for
% % example, will mean that the function will use exp(0)=1.
% sn = 0;

switch model
    
    case 'meanr'
        if ~silence
        fprintf(['This call will just return the ', ...
            'mean of the traininig data\r\n'])
        end
        
    case 'lin-reg'
        
        % Plain linear regression
        % Estimate beta
        [~, D] = size(xtrain);
        lambda = hypin;
        Lambda = diag([1e-4; diag(lambda*eye(D-1))]);
        % The formulation below is a variation on the
        % classic OLS solution. Lambda is the penalty
        % parameter seen in ridge regression.
        Beta=(xtrain'*xtrain + Lambda)\(xtrain'*ytrain);
        % predict on the test decisions
        ytemp = xtest*Beta;
        
    case 'gp-lin'
        % Create a struct of hyperparameters for passing to
        % the GP function.
        % Covariance    
        func.cov = {@covLIN}; hyp.cov = [];
        % Mean
        func.mean = {@meanZero}; hyp.mean = [];
        % Likelihood
        func.lik = {@likGauss}; hyp.lik = hypin;
        
    case 'gp-liniso'
        % specify the model
        func.cov = {@covLINiso}; hyp.cov = hypin(1);
        func.mean = {@meanZero}; hyp.mean = [];
        func.lik = {@likGauss}; hyp.lik = 0;
        
    case 'gp-seiso'
        % specify the model
        func.cov = {@covSEiso}; hyp.cov = hypin(:);
        func.mean = {@meanZero}; hyp.mean = [];
        func.lik = {@likGauss}; hyp.lik = 0;
        
    case 'gp-seard'
        % specify the model
        func.cov = {@covSEard}; hyp.cov = hypin(:);
        func.mean = {@meanZero}; hyp.mean = [];
        func.lik = {@likGauss}; hyp.lik = 0;
            
    case 'gp-linard'
        % specify the model
        func.cov = {@covLINard}; hyp.cov = hypin(:);
        func.mean = {@meanZero}; hyp.mean = [];
        func.lik = {@likGauss}; hyp.lik = 0;
                
end

% hyp.lik is ALWAYS zero. 

switch gpmode
    case 'train'
        
    switch model
        
    case 'meanr'
    % This just returns the mode of the incoming y-data
    if ~silence
        fprintf(['meanr cannot be called in ', ...
            'training mode. Returning the mode ', ...
            'of training y data.\r\n'])
    end
    nlz = nan;
    dnlz = nan;

    case 'lin-reg'
        
    if ~silence
        fprintf(['Lin-Reg cannot be called in ', ...
            'training mode. Returning the ', ...
            'linear fit and NaN.\r\n'])
    end
    nlz = nan;
    dnlz = nan;

    case 'gp-lin'
        
        [nlz, df] = gp(hyp, ...
            'infExact', func.mean, ...
            func.cov, func.lik, xtrain, ytrain);
        dnlz = df.lik;
        % Since gp-lin function takes only one input - the
        % noise variance (sn) - the manual override used in
        % the other calls is not used here. That is, the
        % 'optimisation' phase of this function will
        % optimise the noise variance.

    case {'gp-liniso','gp-seiso','gp-linard','gp-seard'}
        
        [nlz, df] = gp(hyp, 'infExact', ...
            func.mean, func.cov, func.lik, xtrain, ytrain);
        
        % No regulariser is used. (02 December 2016)
        df.cov = df.cov(:); 
        
        if ~optsn
            % The likelihood hyperparameter (noise variance)
            % is not minimized.
            df.lik = 0;
        end
        
        dnlz = df.cov(:);
        
    end
    
    varargout{1} = nlz;
    varargout{2} = dnlz;
    

case 'test'
    
    switch model
        
    case 'meanr'
    % This just returns the mode of the incoming y-data
    ymu = repmat(nanmean(ytrain), size(xtest,1), 1);

    case 'lin-reg'
    ymu = ytemp;

    case {'gp-lin','gp-liniso','gp-seiso','gp-linard','gp-seard'}
    ymu = gp(hyp, 'infExact', func.mean, ...
        func.cov, func.lik, xtrain, ytrain, xtest);
    
    end
       
    varargout{1} = ymu;
    
case 'deploy'
        
    switch model
        
    case 'meanr'
    % This just returns the mode of the incoming y-data
    ymu = repmat(nanmean(ytrain), size(xtest,1), 1);

    case 'lin-reg'
    ymu = ytemp;

    case { 'gp-lin','gp-liniso','gp-seiso','gp-linard','gp-seard'}
    [ymu, varargout{2}, varargout{3}, ...
        varargout{4}, varargout{5}, varargout{6}] = ...
        gp(hyp, 'infExact', ...
        func.mean, func.cov, func.lik, ...
        xtrain, ytrain, xtest);
    end
    
    varargout{1} = ymu;
        
end

end