clear; clc; close all;

% Choose load type
lo = 1;

% Choose a random seed to plot. There are 100 model variants
% trained in each case, using different random seeds from 1
% to 100. It doesn't really matter which seed you choose
% since they should all be equivalent.
seedchoice = 7;

% Do you want the colours to be inverted, i.e., white on
% black?
colour_inversion = false;

DefaultColours

% The name of the data "series" that is currently being
% processed.
trainser = 'BaseSimulation';
testser = 'BaseSimulation';

features = true(28,1);

err_ylims = [0, 0.7; 0, 0.7];
rmse_ylims = [0, 160; 0, 80];

binlims = [0, 200; 0, 100];
xlims = [-5, 200; -2.5, 100];

switch lo
    case 1
        loadtype = 'Heating';
    case 2
        loadtype = 'Cooling';
end

% clear yin

seeds = 100;

% This changes the kind of data that is picked up (i.e., the
% files located in the extrax folder have extra covariates)
% and the save/read paths.

% Load type (output variable).
% 1 --> heating
% 2 --> cooling

% Define various paths

% The drive on which you would like to manipulate data.
% Should preferably not be C:, since the data might be quite
% large.
% drive = 'E:';

% % Save figure files

pathFIGsave = fullfile('.','figs');
if exist(pathFIGsave, 'dir') ~= 7
    mkdir(pathFIGsave)
end


% This is the processed data, stored as tables.
pathSUMdir = '.';

pathTop = fullfile('f:', 'allmycode', ...
    'CurrentScripts', 'GPinBS');
% pathTop = '.';

pathMATdir = fullfile(pathTop, ...
    sprintf('savedMATs_%s', trainser));

if ~strcmp(trainser, testser)
    pathMATdir_test = fullfile(pathTop, ...
        sprintf('savedMATs_%s', testser));
end

pathDataTabsdir = fullfile(pathTop, 'datatables');

% These are the dates of the latest training metadata files.
if strcmp(trainser, 'BaseSimulation')
    dated = '02-Dec-2016';
elseif strcmp(trainser, 'M')
    dated = '22-Dec-2016';
elseif strcmp(trainser, 'G')
    dated = '27-Dec-2016';
end

load(fullfile(pathMATdir, ...
    ['trainN_', trainser,'_',dated]))

% This renaming is necessary because the meaning of
% test_idx is different in this script.
testidx_train = test_idx;


% Load the xin, yin, etc. for the training series.
load_train = load(fullfile(pathDataTabsdir, ...
    sprintf('gpdata_%s.mat', trainser)));

size_yin_train = size(load_train.yin,1);

if ~strcmp(trainser, testser)
    % Load the gpdata file corresponding to test series.
    load_test = load(fullfile(pathDataTabsdir, ...
        sprintf('gpdata_%s.mat', testser)));
    size_yin_test = size(load_test.yin,1);
else
    load_test = load_train;
    size_yin_test = size(load_train.yin,1);
end

if strcmp(testser, 'DOE_ideal')
    % THe DOE_ideal array is too big to handle, so this
    % script will only a subset (randomly select a quarter
    % of the points).
    rnd_ytest = randsample(size_yin_test, ...
        round(size_yin_test/5));
    cullidx_test = false(size_yin_test,1);
    cullidx_test(rnd_ytest) = true;
    % The testidx_test is all true, since there was no
    % training data.
    testidx_test = true(size_yin_test, 1);
else
    % Use the testidx_test that was loaded.
    % No cull is needed since the arrays are small enough.
    cullidx_test = true(size_yin_test,1);
end

% cullidx_train = true(size_yin_train, 1);

% Get ytest. For DOE_ideal, testidx_test is all true, so
% cull_idx randomly takes out 4/5th of the data.
ytest_train = load_train.yin(testidx_train,lo);
ytest_test = load_test.yin(testidx_test & cullidx_test,lo);

% In other cases, restate cull_idx so it works with the
% ypred vectors, which are the same lengths as ytest.
if ~strcmp(testser, 'DOE_ideal')
    cullidx_test = true(size(ytest_test,1),1);
end
% Otherwise cull_idx will keep (or throw out) the same
% elements of ypred as ytest.

% This is the choice of models on offer.
modlist = {'meanr', 'lin-reg', 'gp-liniso', ...
    'gp-linard', 'gp-seiso', 'gp-seard'};
modnames = {'Mean', 'Lin-Reg', 'Lin-Iso', ...
    'Lin-ARD', 'NonLin-Iso', 'NonLin-ARD'};

runserr = load(fullfile(pathMATdir, ...
    sprintf('errs_%s_%d_%d.mat', trainser, 1, lo)));
runsy = load(fullfile(pathMATdir, ...
    sprintf('ystore_%s_%d_%d.mat', trainser, 1, lo)));

% Runsy and Runerr have the same structure:
% m,r,(number of data points in runsy)

mae_coll = nan([size(runserr.mae),seeds]);
rmse_coll = nan([size(runserr.rmse),seeds]);
hyp_coll = nan([size(runserr.hyp),seeds]);
ypred_coll = nan([size(runsy.ypred),seeds]);

for v = 1:seeds
    %     try
    runserr = load(fullfile(pathMATdir, ...
        sprintf('errs_%s_%d_%d.mat', ...
        trainser, v, lo)));
    mae_coll(:,:,v) = runserr.mae;
    rmse_coll(:,:,v) = runserr.rmse;
    hyp_coll(:,:,:,v) = runserr.hyp;
    
    runsy = load(fullfile(pathMATdir, ...
        sprintf('ystore_%s_%d_%d.mat', ...
        trainser, v, lo)));
    ypred_coll(:,:,:,v) = runsy.ypred;
    
    %     catch err
    %         fprintf('%s\r\n', err.message)
    %     end
end

clear runserr runsy 
clear Nval

% Find the length scale from the hyper parameter vector
% being loaded.
D = size(squeeze(hyp_coll(1,strcmpi(modlist, ...
    'gp-seard'),:,1)),1) - 1;

rmsestat.x50 = quantile(rmse_coll,.5,3);
maestat.x50 = quantile(mae_coll,.5,3);

rmsestat.x25 = quantile(rmse_coll,.25,3);
maestat.x25 = quantile(mae_coll,.25,3);

rmsestat.x75 = quantile(rmse_coll,.75,3);
maestat.x75 = quantile(mae_coll,.75,3);

if strcmp(trainser, 'DOE_ideal')
    ytest_coll = (repmat(ytest_train, [1, seeds]));
    ypred_coll = squeeze(ypred_coll);
else
    ytest_coll = permute(repmat(ytest_train, [1, length(N), ...
        numel(modlist), seeds]), [2 3 1 4]);
end

ydiff_coll = ytest_coll - ypred_coll;

% relerr_coll = ydiff_coll ./ ytest_coll;

clear ypred_coll ytest_coll


% % %
if ~strcmp(trainser, testser)
    
if exist('load_test', 'var')~=1
    load_test = load(fullfile(pathDataTabsdir, ...
        sprintf('gpdata_%s.mat', testser)));
end

size_yin_test = size(load_test.yin,1);

if strcmp(testser, 'DOE_ideal')
    % THe DOE_ideal array is too big to handle, so this
    % script will only a subset (randomly select a quarter
    % of the points).
    rnd_ytest = randsample(size_yin_test, ...
        round(size_yin_test/5));
    cullidx_test = false(size_yin_test,1);
    cullidx_test(rnd_ytest) = true;
    % The testidx_test is all true, since there was no training
    % data.
    testidx_test = true(size_yin_test, 1);
else
    % Use the testidx_test that was loaded.
    % No cull is needed since the arrays are small enough.
    cullidx_test = true(size_yin_test,1);
end

ytest_test = load_test.yin(testidx_test & cullidx_test,lo);

runsy_test = load(fullfile(pathMATdir_test, ...
    sprintf('ystore_%s_%d_%d.mat', testser, 1, lo)));
ypred_coll_test = nan([size(runsy_test.ypred( ...
    :,:,cullidx_test)), seeds]);

for v = 1:seeds
    %     try
    runsy_test = load(fullfile(pathMATdir_test, ...
        sprintf('ystore_%s_%d_%d.mat', ...
        testser, v, lo)));
    ypred_coll_test(:,:,:,v) = ...
        runsy_test.ypred(:,:,cullidx_test);
    
    %     catch err
    %         fprintf('%s\r\n', err.message)
    %     end
end

clear runsy_test


if strcmp(testser, 'DOE_ideal')
    ytest_coll_test = permute(repmat(ytest_test, [1, length(modlist), seeds]), [2 1 3]);
    ypred_coll_test = squeeze(ypred_coll_test(1,:,:,:));
else
    ytest_coll_test = permute(repmat(ytest_test, [1, length(N), ...
        numel(modlist), seeds]), [2 3 1 4]);
end

% Keep only the Non-linear ARD model, which usually
% performs best.

ydiff_coll_test = ytest_coll_test - ypred_coll_test;

clear ytest_coll_test ypred_coll_test

end
%%

% RMSE evolution with training data size

% Skip for DOE_ideal since there was no training phase.

if ~strcmp(trainser, 'DOE_ideal')
    
    % Skip the lin-reg case
    modchoice = [true; false; true(4,1)];
    
    label_y = 'rmse';
    colourorder = [grey; orange; red; blue; blackest];
    markers = {'o','square','^','v','diamond'};
    
    plothand = figure('visible', 'on');
    
    ax = gca;
    hold(ax, 'on')
    
    ax.XLabel.Interpreter = 'latex';
    ax.YLabel.Interpreter = 'latex';
    ax.Title.Interpreter = 'latex';
    
    ax.XLabel.String = '\# of training data points';
    ax.YLabel.String = sprintf('%s [$kWh/m^2$]', label_y);
    
    ax.YLim = rmse_ylims(lo,:);
    ax.XLim = [0, N(end)];
    
    ax.XTick = N;
    ax.XTickLabel{2} = ' ';
    ax.XTickLabel{3} = ' ';
    
    ax.YTick = [0:20:ax.YLim(end)];
    
    ax.XGrid = 'on';
    % ax.YMinorTick = 'on';
    ax.YAxis.MinorTickValues = [10:20:ax.YLim(end)];
    ax.Title.String = sprintf('RMSE vs $N_{train}$ for %s', loadtype);
    
    for m = 1:length(modlist)
        if modchoice(m)
            errlims(m) = fill([N;flipud(N)], ...
                [rmsestat.x75(:,m) * ...
                load_train.ystdevs(lo); ...
                flipud(rmsestat.x25(:,m) * ...
                load_train.ystdevs(lo))], ...
                grey, 'LineStyle','none');
        else
            continue
        end
    end
    
    err50 = plot(N, rmsestat.x50(:, modchoice) * ...
        load_train.ystdevs(lo));
    
    errlims(~modchoice) = [];
    
    for k = 1:length(err50)
        err50(k).LineWidth = 4;
        err50(k).Marker = markers{k};
        err50(k).Color = colourorder(k,:);
        err50(k).MarkerFaceColor = whitest;
        err50(k).MarkerSize = 16;
        errlims(k).FaceColor = colourorder(k,:);
        errlims(k).FaceAlpha = 0.5;
    end
    
    leg = legend(err50, modnames(modchoice));
    leg.Interpreter = 'latex';
    leg.Units = 'normalized';
    leg.Location = 'northeast';
    
    ax.FontSize = 24;
    leg.FontSize = ax.FontSize+2;
    ax.Title.FontSize = ax.FontSize+2;
    
    figname = sprintf('%s_%d_%s', label_y, lo, trainser(1));
    
    if colour_inversion
        
        err50(end).Color = whitest;
        errlims(end).FaceColor = whitest;
        
        plothand.Color = blackest;
        ax.Color = blackest;
        ax.YColor = whitest;
        ax.XColor = whitest;
        ax.Title.Color = whitest;
        plothand.InvertHardcopy = 'off';
        
        leg.Color = blackest;
        leg.TextColor = whitest;
        leg.Box = 'on';
        
        figname = [figname, '-inv'];
        
    end
    
    SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
        'changecolours', false, 'printfig', false, ...
        'orient', 'landscape')
    
end
%%

% Comparing training data set sizes - 100 and 4000.

clear rc ed h1


binedges = binlims(lo,1) : range(binlims(lo,:))/20 : ...
    binlims(lo,2);

plothand = figure('visible', 'on');

ax = gca;
hold(ax, 'on')

n = 1;

nchoice = [false, true, false(1,5), true];

colourorder = [reddest; blackest];

if strcmp(trainser, 'DOE_ideal')
    yplot = abs(squeeze(ydiff_coll(:, ...
        seedchoice)))*load_train.ystdevs(lo);
else
    yplot = abs(squeeze(ydiff_coll(:,end,:, ...
        seedchoice)))*load_train.ystdevs(lo);
end

for r = 1:length(N)
    
    if ~nchoice(r)
        continue
    end
    
    [rc(n,:), ed(n,:)] = histcounts(yplot(r,:), ...
        binedges, 'Normalization', 'probability');
    
    h1(n) = bar(ed(n,1:end-1), rc(n,:));
    h1(n).FaceColor = colourorder(n,:);
    h1(n).FaceAlpha = 1;
    
    h1(n).EdgeColor = h1(n).FaceColor;
    
    n = n + 1;
end

h1(1).BarWidth = 0.8;
h1(2).BarWidth = 0.3;

hold(ax, 'off')

ax.Box = 'on';
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';
ax.XLabel.String = 'pred. error ($\varepsilon$) $[kWh/m^2]$';
ax.YLabel.String = 'relative count';
ax.Title.String = 'Histograms of errors for $N = 100, 4000$';
ax.XLim = xlims(lo,:);
ax.XAxis.TickDirection = 'out';
ax.XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
ax.XTickLabel = binedges(1:2:end);
ax.XAxis.MinorTickValues = binedges(2:2:end)-(binedges(2)-binedges(1))/2;
ax.XMinorGrid = 'on';
ax.XMinorTick = 'on';
ax.YLim = err_ylims(lo,:);
ax.XGrid = 'on';
ax.GridAlpha = 0.25;
ax.YTick = ax.YLim(1):0.1:ax.YLim(2);
ax.YMinorGrid = 'on';
% ax.YMinorTick = 'on';

leglabs = cell(length(N),1);
for n = 1:length(N)
    if nchoice(n)
        leglabs{n} = num2str(N(n));
    end
end

leglabs(~nchoice) = [];

leg = legend(h1, leglabs);

leg.Interpreter = 'latex';
ax.FontSize = 24;
% ax.Title.FontSize = ax.FontSize+2;
leg.FontSize = ax.FontSize+2;

figname = sprintf('errhist_N_%d_%s', lo, trainser(1));

SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
    'changecolours', false, 'printfig', false, ...
    'orient', 'landscape')


if ~strcmp(trainser, testser)
    
    fprintf(['Not plotting N_{train} = 100 vs 4000 ', ...
        'comparison for test series.\r\n'])
    
end

%%

% Compare Linear and Non-Linear ARD.

clear ed rc h1

plothand = figure('visible', 'on');

ax = gca;
hold(ax, 'on')

n = 1;

mchoice = [false, false, false, true, false, true];

colourorder = [reddest; blackest];

if strcmp(trainser, 'DOE_ideal')
    yplot = abs(squeeze(ydiff_coll(:, ...
        seedchoice)))*load_train.ystdevs(lo);
else
    yplot = abs(squeeze(ydiff_coll(end,:,:, ...
        seedchoice)))*load_train.ystdevs(lo);
end

for m = 1:length(modlist)
    
    if ~mchoice(m)
        continue
    end
    
    [rc(n,:), ed(n,:)] = histcounts(yplot(m,:), ...
        binedges, 'Normalization', 'probability');
    
    h1(n) = bar(ed(n,1:end-1), rc(n,:));
    h1(n).FaceColor = colourorder(n,:);
    h1(n).FaceAlpha = 1;
    h1(n).EdgeColor = h1(n).FaceColor;
    
    n = n + 1;
end

h1(1).BarWidth = 0.8;
h1(2).BarWidth = 0.3;

hold(ax, 'off')

ax.Box = 'on';
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';
ax.XLabel.String = 'pred. error ($\varepsilon$) $[kWh/m^2]$';
ax.YLabel.String = 'relative count';
ax.Title.String = 'Histograms of errors for Linear \& Non-Linear ARD';
ax.XLim = xlims(lo,:);
ax.XAxis.TickDirection = 'out';
ax.XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
ax.XTickLabel = binedges(1:2:end);
ax.XAxis.MinorTickValues = binedges(2:2:end)-(binedges(2)-binedges(1))/2;
ax.XMinorGrid = 'on';
ax.XMinorTick = 'on';
ax.YMinorGrid = 'on';
% ax.YMinorTick = 'on';
ax.YLim = err_ylims(lo,:);
ax.XGrid = 'on';
ax.GridAlpha = 0.25;
ax.YTick = ax.YLim(1):0.1:ax.YLim(2);

leglabs = modnames;
leglabs(~mchoice) = [];
leg = legend(h1, leglabs);
leg.Interpreter = 'latex';
ax.FontSize = 24;
leg.FontSize = ax.FontSize+2;
% ax.Title.FontSize = ax.FontSize+2;

figname = sprintf('errhist_ardcomp_%d_%s', lo, trainser(1));

SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
    'changecolours', false, 'printfig', false, ...
    'orient', 'landscape')

% Compare linear and non-linear ISO.

clear ed rc h1

plothand = figure('visible', 'on');

ax = gca;
hold(ax, 'on')

n = 1;

mchoice = [false, false, true, false, true, false];

colourorder = [reddest; blackest];

if strcmp(trainser, 'DOE_ideal')
    yplot = abs(squeeze(ydiff_coll(:, ...
        seedchoice)))*load_train.ystdevs(lo);
else
    yplot = abs(squeeze(ydiff_coll(end,:,:, ...
        seedchoice)))*load_train.ystdevs(lo);
end

for m = 1:length(modlist)
    
    if ~mchoice(m)
        continue
    end
    
    [rc(n,:), ed(n,:)] = histcounts(yplot(m,:), ...
        binedges, 'Normalization', 'probability');
    
    h1(n) = bar(ed(n,1:end-1), rc(n,:));
    h1(n).FaceColor = colourorder(n,:);
    h1(n).FaceAlpha = 1;
    h1(n).EdgeColor = h1(n).FaceColor;
    
    n = n + 1;
end

h1(1).BarWidth = 0.8;
h1(2).BarWidth = 0.3;

hold(ax, 'off')

ax.Box = 'on';
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';
ax.XLabel.String = 'pred. error ($\varepsilon$) $[kWh/m^2]$';
ax.YLabel.String = 'relative count';
ax.Title.String = 'Histograms of errors for Linear \& Non-Linear ISO';
ax.XLim = xlims(lo,:);
ax.XAxis.TickDirection = 'out';
ax.XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
ax.XTickLabel = binedges(1:2:end);
ax.XAxis.MinorTickValues = binedges(2:2:end)-(binedges(2)-binedges(1))/2;
ax.XMinorGrid = 'on';
ax.XMinorTick = 'on';
ax.YMinorGrid = 'on';
% ax.YMinorTick = 'on';
ax.YLim = err_ylims(lo,:);
ax.XGrid = 'on';
ax.GridAlpha = 0.25;
ax.YTick = ax.YLim(1):0.1:ax.YLim(2);

leglabs = modnames;
leglabs(~mchoice) = [];
leg = legend(h1, leglabs);
leg.Interpreter = 'latex';
ax.FontSize = 24;
leg.FontSize = ax.FontSize+2;
% ax.Title.FontSize = ax.FontSize+2;

figname = sprintf('errhist_isocomp_%d_%s', lo, trainser(1));

SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
    'changecolours', false, 'printfig', false, ...
    'orient', 'landscape')

%%

if ~strcmp(trainser, testser)
    
    % Compare Linear and Non-Linear ARD.
    
    clear ed rc h1
    
    plothand = figure('visible', 'on');
    
    ax = gca;
    hold(ax, 'on')
    
    n = 1;
    
    mchoice = [false, false, false, true, false, true];
    
    colourorder = [reddest; blackest];
    
    if strcmp(testser, 'DOE_ideal')
        yplot = abs(squeeze(ydiff_coll_test(:, :, ...
            seedchoice)))*load_train.ystdevs(lo);
    else
        yplot = abs(squeeze(ydiff_coll_test(end,:,:, ...
            seedchoice)))*load_train.ystdevs(lo);
    end
    
    for m = 1:length(modlist)
        
        if ~mchoice(m)
            continue
        end
        
        [rc(n,:), ed(n,:)] = histcounts(yplot(m,:), ...
            binedges, 'Normalization', 'probability');
        
        h1(n) = bar(ed(n,1:end-1), rc(n,:));
        h1(n).FaceColor = colourorder(n,:);
        h1(n).FaceAlpha = 1;
        h1(n).EdgeColor = h1(n).FaceColor;
        
        n = n + 1;
    end
    
    h1(1).BarWidth = 0.8;
    h1(2).BarWidth = 0.3;
    
    hold(ax, 'off')
    
    ax.Box = 'on';
    ax.XLabel.Interpreter = 'latex';
    ax.YLabel.Interpreter = 'latex';
    ax.Title.Interpreter = 'latex';
    ax.XLabel.String = 'pred. error ($\varepsilon$) $[kWh/m^2]$';
    ax.YLabel.String = 'relative count';
    ax.Title.String = 'Histograms of errors for Linear \& Non-Linear ARD';
    ax.XLim = xlims(lo,:);
    ax.XAxis.TickDirection = 'out';
    ax.XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
    ax.XTickLabel = binedges(1:2:end);
    ax.XAxis.MinorTickValues = binedges(2:2:end) - ...
        (binedges(2)-binedges(1))/2;
    ax.XMinorGrid = 'on';
    ax.XMinorTick = 'on';
    ax.YMinorGrid = 'on';
    % ax.YMinorTick = 'on';
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.GridAlpha = 0.25;
    
    if strcmp(testser, 'DOE_ideal')
        switch lo
            case 1
                ax.YLim = [0, 0.5];
            case 2
                ax.YLim = [0, 0.2];
        end
    end
    
    ax.YTick = ax.YLim(1):0.1:ax.YLim(2);
    
    leglabs = modnames;
    leglabs(~mchoice) = [];
    leg = legend(h1, leglabs);
    leg.Interpreter = 'latex';
    ax.FontSize = 24;
    leg.FontSize = ax.FontSize+2;
    % ax.Title.FontSize = ax.FontSize+2;
    
    figname = sprintf('errhist_ardcomp_%d_%s', lo, testser(1));
    
    SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
        'changecolours', false, 'printfig', false, ...
        'orient', 'landscape')
    
    %
    % Compare linear and non-linear ISO.
    
    clear ed rc h1
    
    plothand = figure('visible', 'on');
    
    ax = gca;
    hold(ax, 'on')
    
    n = 1;
    
    mchoice = [false, false, true, false, true, false];
    
    colourorder = [reddest; blackest];
    
    if strcmp(trainser, 'DOE_ideal')
        yplot = abs(squeeze(ydiff_coll(:, ...
            seedchoice)))*load_train.ystdevs(lo);
    else
        yplot = abs(squeeze(ydiff_coll(end,:,:, ...
            seedchoice)))*load_train.ystdevs(lo);
    end
    
    for m = 1:length(modlist)
        
        if ~mchoice(m)
            continue
        end
        
        [rc(n,:), ed(n,:)] = histcounts(yplot(m,:), ...
            binedges, 'Normalization', 'probability');
        
        h1(n) = bar(ed(n,1:end-1), rc(n,:));
        h1(n).FaceColor = colourorder(n,:);
        h1(n).FaceAlpha = 1;
        h1(n).EdgeColor = h1(n).FaceColor;
        
        n = n + 1;
    end
    
    h1(1).BarWidth = 0.8;
    h1(2).BarWidth = 0.3;
    
    hold(ax, 'off')
    
    ax.Box = 'on';
    ax.XLabel.Interpreter = 'latex';
    ax.YLabel.Interpreter = 'latex';
    ax.Title.Interpreter = 'latex';
    ax.XLabel.String = 'pred. error ($\varepsilon$) $[kWh/m^2]$';
    ax.YLabel.String = 'relative count';
    ax.Title.String = 'Histograms of errors for Linear \& Non-Linear ISO';
    ax.XLim = xlims(lo,:);
    ax.XAxis.TickDirection = 'out';
    ax.XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
    ax.XTickLabel = binedges(1:2:end);
    ax.XAxis.MinorTickValues = binedges(2:2:end)-(binedges(2)-binedges(1))/2;
    ax.XMinorGrid = 'on';
    ax.XMinorTick = 'on';
    ax.YMinorGrid = 'on';
    % ax.YMinorTick = 'on';
    ax.YLim = err_ylims(lo,:);
    ax.XGrid = 'on';
    ax.GridAlpha = 0.25;
    ax.YTick = ax.YLim(1):0.1:ax.YLim(2);
    
    leglabs = modnames;
    leglabs(~mchoice) = [];
    leg = legend(h1, leglabs);
    leg.Interpreter = 'latex';
    ax.FontSize = 24;
    leg.FontSize = ax.FontSize+2;
    % ax.Title.FontSize = ax.FontSize+2;
    
    figname = sprintf('errhist_isocomp_%d_%s', lo, testser(1));
    
    SaveThatFig(plothand, fullfile(pathFIGsave, figname), ...
        'changecolours', false, 'printfig', false, ...
        'orient', 'landscape')
    
end
