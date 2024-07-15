% Plot histograms of raw output values.

clear; clc; close all;


% Do you want the colours to be inverted, i.e., white on
% black?
colour_inversion = false;

DefaultColours

% The name of the data "series" that is currently being
% processed.
trainser = 'BaseSimulation';
testser = 'DOE_ideal';

features = true(28,1);

seedchoice = 7;

if strcmp(trainser, 'BaseSimulation')
err_ylims = [0, 0.8; 0, 0.8];
rmse_ylims = [0, 160; 0, 80];
elseif strcmp(trainser, 'M')
err_ylims = [0, 0.9; 0, 0.9];
rmse_ylims = [0, 200; 0, 80];
elseif strcmp(trainser, 'G')
err_ylims = [0, 0.9; 0, 0.9];
rmse_ylims = [0, 80; 0, 80];
end

binlims = [0, 200; 0, 100];
xlims = [-5, 200; -2.5, 100];

% switch lo
%     case 1
%         loadtype = 'Heating';
%     case 2
%         loadtype = 'Cooling';
% end


seeds = 100;

% Define various paths
pathTop = fullfile('f:', 'allmycode', ...
    'CurrentScripts', 'GPinBS');
% pathTop = '.';

pathFIGsave = fullfile('.','figs');
if exist(pathFIGsave, 'dir') ~= 7
    mkdir(pathFIGsave)
end

% This is the processed data, stored as tables.
pathSUMdir = '.';

pathMATdir = fullfile(pathTop, ...
    sprintf('savedMATs_%s',trainser));

pathMATdir_test = fullfile(pathTop, ...
    sprintf('savedMATs_%s',testser));

pathDataTabsdir = 'datatables';

% Load the gpdata.
load_train = load(fullfile(pathDataTabsdir, sprintf('gpdata_%s.mat', trainser)));
load_test = load(fullfile(pathDataTabsdir, sprintf('gpdata_%s.mat', testser)));


% These are the dates of the latest training metadata files.
if strcmp(trainser, 'BaseSimulation')
    dated = '02-Dec-2016';
elseif strcmp(trainser, 'M')
    dated = '22-Dec-2016';
elseif strcmp(trainser, 'G')
    dated = '27-Dec-2016';
end

if strcmp(trainser, 'DOE_ideal')
    % This series is a special case because it isn't used
    % for training - only for deployment.
    load(fullfile(pathMATdir, ...
        'trainN_BaseSimulation_02-Dec-2016'));
    
    % This renaming is necessary because the meaning of
    % test_idx is different in this script.
    testidx_train = test_idx;
    
else
    load(fullfile(pathMATdir, ...
        ['trainN_', trainser,'_',dated]))
    
    % This renaming is necessary because the meaning of
    % test_idx is different in this script.
    testidx_train = test_idx;
    
end

% This is the choice of models on offer.
modlist = {'meanr', 'lin-reg', 'gp-liniso', ...
    'gp-linard', 'gp-seiso', 'gp-seard'};
modnames = {'Mean', 'Lin-Reg', 'Lin-Iso', ...
    'Lin-ARD', 'NonLin-Iso', 'NonLin-ARD'};

for lo = 1:2

runsy = load(fullfile(pathMATdir, ...
    sprintf('ystore_%s_%d_%d.mat', trainser, 1, lo)));

% Runsy and Runerr have the same structure:
% m,r,(number of data points in runsy)

ypred_coll = nan([size(runsy.ypred),seeds]);

for v = 1:seeds
    %     try    
    runsy = load(fullfile(pathMATdir, ...
        sprintf('ystore_%s_%d_%d.mat', ...
        trainser, v, lo)));
    ypred_coll(:,:,:,v) = runsy.ypred;
    
    %     catch err
    %         fprintf('%s\r\n', err.message)
    %     end
end

clear rrunsy runsy_un

clear Nval

% Find the length scale from the hyper parameter vector
% % being loaded.
% D = size(squeeze(hyp_coll(1,strcmpi(modlist, ...
%     'gp-seard'),:,1)),1) - 1;


% Get ytest. For DOE_ideal, testidx_test is all true, so
% cull_idx randomly takes out 4/5th of the data.
ytest_train = load_train.yin(testidx_train,lo);

if strcmp(trainser, 'DOE_ideal')
    ytest_coll = (repmat(ytest_train, [1, seeds]));
    ypred_coll = squeeze(ypred_coll);
else
    ytest_coll = permute(repmat(ytest_train, [1, length(N), ...
        numel(modlist), seeds]), [2 3 1 4]);
end

ydiff_coll(lo,:,:,:,:) = ytest_coll - ypred_coll;

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

ytest_test = load_test.yin(testidx_test & cullidx_test,lo);

if strcmp(testser, 'DOE_ideal')
    ytest_coll_test = permute(repmat(ytest_test, [1, length(modlist), seeds]), [2 1 3]);
    ypred_coll_test = squeeze(ypred_coll_test(1,:,:,:));
else
    ytest_coll_test = permute(repmat(ytest_test, [1, length(N), ...
        numel(modlist), seeds]), [2 3 1 4]);
end

% Keep only the Non-linear ARD model, which usually
% performs best.

ydiff_coll_test(lo,:,:,:,:) = ytest_coll_test - ypred_coll_test;

clear ytest_coll_test ypred_coll_test

end

end

%%

binedges = 0:(800/20):800;

if strcmp(trainser, testser)

plothand = figure('visible', 'on');

ax = gca;
hold(ax, 'on')

ax.Box = 'on';
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';

ax.XLabel.String = 'original outputs ($y$) $[kWh/m^2]$';
ax.YLabel.String = 'relative count';
ax.Title.String = 'Histograms of outputs';

colourorder = [orange; blue];

yorig_train = bsxfun(@plus, bsxfun(@times, load_train.yin, load_train.ystdevs), load_train.ymeans);

[rc(1,:), ed(1,:)] = histcounts(yorig_train(test_idx,1), binedges, ...
    'Normalization', 'probability');

[rc(2,:), ed(2,:)] = histcounts(yorig_train(test_idx,2), binedges, ...
    'Normalization', 'probability');

for lo = 1:2
    
    h1(lo) = bar(ed(lo,1:end-1), rc(lo,:));
    h1(lo).FaceColor = colourorder(lo,:);
    h1(lo).FaceAlpha = 1;
    
    switch lo
        case 1
            h1(lo).BarWidth = 0.8;
        case 2
            h1(lo).BarWidth = 0.4;
    end
    
end

hold(ax, 'off')

ax.XLim = [binedges(1)-(binedges(2)-binedges(1))/2, binedges(end)];
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

leg = legend(h1, {'heating','cooling'});

leg.Interpreter = 'latex';
ax.FontSize = 24;
ax.Title.FontSize = ax.FontSize+2;
leg.FontSize = ax.FontSize;

figname = sprintf('yhist_%s', trainser);

if colour_inversion
    
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


% Draw histograms of raw output values if testser is
% different from trainser.

elseif ~strcmp(trainser, testser)
    
    clear h1 rc ed
    
    % Load the gpdata file corresponding to testser first.
    
    if exist('load_test', 'var')~=1
        load_test = load(fullfile(pathDataTabsdir, ...
            sprintf('gpdata_%s.mat', testser)));
    end
    
    binedges = 0:(800/20):800;
    
    plothand = figure('visible', 'on');
    
    colourorder = [orange; blue];
    
    yorig_train = bsxfun(@plus, bsxfun(@times, ...
        load_train.yin, load_train.ystdevs), ...
        load_train.ymeans);
    yorig_test = bsxfun(@plus, bsxfun(@times, ...
        load_test.yin, load_test.ystdevs), ...
        load_test.ymeans);
    
    [rc(1,:), ed(1,:)] = histcounts(yorig_train( ...
        :,1), binedges, ...
        'Normalization', 'probability');
    
    [rc(2,:), ed(2,:)] = histcounts(yorig_train( ...
        :,2), binedges, ...
        'Normalization', 'probability');
    
    [rc(3,:), ed(3,:)] = histcounts(yorig_test( ...
        :,1), binedges, ...
        'Normalization', 'probability');
    
    [rc(4,:), ed(4,:)] = histcounts(yorig_test( ...
        :,2), binedges, ...
        'Normalization', 'probability');
    
    ii = 1;
    
    for s = 1:2
        ax(s) = subplot(2,1,s);
        ax(s) = gca;
        hold(ax(s), 'on')
        
        ax(s).Box = 'on';
        ax(s).XLabel.Interpreter = 'latex';
        ax(s).YLabel.Interpreter = 'latex';
        ax(s).Title.Interpreter = 'latex';
        
        ax(s).YLabel.String = 'relative count';
        
        ax(s).XLim = [binedges(1)-(binedges(2)-binedges(1))/2, binedges(end)];
        ax(s).XAxis.TickDirection = 'out';
        ax(s).XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
        ax(s).XTickLabel = binedges(1:2:end);
        ax(s).XAxis.MinorTickValues = binedges(2:2:end)-(binedges(2)-binedges(1))/2;
        ax(s).XMinorGrid = 'on';
        ax(s).XMinorTick = 'on';
        ax(s).YMinorGrid = 'on';
        % ax(s).YMinorTick = 'on';
        ax(s).YLim = err_ylims(s,:);
        ax(s).XGrid = 'on';
        ax(s).GridAlpha = 0.25;
        ax(s).YTick = ax(s).YLim(1):0.2:ax(s).YLim(2);
        
        ax(s).FontSize = 24;
        ax(s).Title.FontSize = ax(s).FontSize+2;
        
        
        for hc = 1:2
            
            h1(ii) = bar(ax(s), ed(ii,1:end-1), rc(ii,:));
            h1(ii).FaceColor = colourorder(hc,:);
            h1(ii).FaceAlpha = 1;
            
            switch hc
                case 1
                    h1(ii).BarWidth = 0.8;
                case 2
                    h1(ii).BarWidth = 0.4;
            end
            
            ii = ii + 1;
            
        end        
        
        leg = legend(ax(s), h1, {'heating','cooling'});
        leg.Interpreter = 'latex';
        leg.FontSize = ax(s).FontSize;        
        
        switch s
            case 1
                curr_ser = trainser(1);
            case 2
                curr_ser = testser(1);
        end
        
        ax(s).Title.String = sprintf('Histograms of outputs -- %s', curr_ser);
        
    end
    
    ax(2).XLabel.String = 'original outputs ($y$) $[kWh/m^2]$';
%     ax(2).YLim = [0, 0.8];
%     ax(2).YTick = ax(2).YLim(1):0.2:ax(2).YLim(2);
    
    hold(ax(1), 'off')
    hold(ax(2), 'off')
    
    figname = sprintf('yhist_%s_%s', ...
        trainser(1), testser(1));
    
    if colour_inversion
        
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

% Draw histograms of errors, if testser is
% different from trainser.

% Using only the results from the non-linear ARD model, 
% with 4000 data points.

clear h1 rc ed

if ~strcmp(trainser, testser)
    
    clear ypred_coll relerr_coll
    clear rnd_ytest cull_idx
    
    binedges = 0:(200/20):200;
    
    plothand = figure('visible', 'on');
    
    colourorder = [reddest; blackest];
    
    for s = 1:2
        
        ax(s) = subplot(2,1,s);
        hold(ax(s), 'on')
        
        ax(s).Box = 'on';
        ax(s).XLabel.Interpreter = 'latex';
        ax(s).YLabel.Interpreter = 'latex';
        ax(s).Title.Interpreter = 'latex';
        
        ax(s).XLabel.String = 'errors ($\varepsilon$) $[kWh/m^2]$';
        ax(s).YLabel.String = 'relative count';
        
        switch s
            case 1
                loadtype = 'Heating';
            case 2
                loadtype = 'Cooling';
        end
        
        ax(s).Title.String = sprintf('Histograms of errors -- %s', loadtype);
        
        % The first subscript is for the load type (s).
        % Also, pick the nonlin-ard model (last in list),
        % trained on 4000 data points (last in list). Use
        % seedchoice to pick only one iteration.
        errorig_train = bsxfun(@times, ...
            squeeze(ydiff_coll(s,end,end,:,seedchoice)), ...
            load_train.ystdevs(s));
        errorig_test = bsxfun(@times, ...
            squeeze(ydiff_coll_test(s,end,:,seedchoice)), ...
            load_test.ystdevs(s));
        
        [rc(1,:), ed(1,:)] = histcounts(errorig_train, ...
            binedges, ...
            'Normalization', 'probability');
        
        [rc(2,:), ed(2,:)] = histcounts(errorig_test, ...
            binedges, ...
            'Normalization', 'probability');
        
        for hc = 1:2
            
            h1(hc) = bar(ed(hc,1:end-1), rc(hc,:));
            h1(hc).FaceColor = colourorder(hc,:);
            h1(hc).FaceAlpha = 1;
            
            switch hc
                case 1
                    h1(hc).BarWidth = 0.8;
                case 2
                    h1(hc).BarWidth = 0.4;
            end
            
        end
        
        hold(ax(s), 'off')
        
        ax(s).XLim = [binedges(1)-(binedges(2)-binedges(1))/2, ...
            binedges(end)];
        ax(s).XAxis.TickDirection = 'out';
        ax(s).XTick = binedges(1:2:end)-(binedges(2)-binedges(1))/2;
        ax(s).XTickLabel = binedges(1:2:end);
        ax(s).XAxis.MinorTickValues = binedges(2:2:end) - ...
            (binedges(2)-binedges(1))/2;
        ax(s).XMinorGrid = 'on';
        ax(s).XMinorTick = 'on';
        ax(s).YMinorGrid = 'on';
        % ax.YMinorTick = 'on';
        ax(s).YLim = [0 0.8];
        ax(s).XGrid = 'on';
        ax(s).GridAlpha = 0.25;
        ax(s).YTick = ax(s).YLim(1):0.2:ax(s).YLim(2);
        
        leg = legend(h1, {trainser(1),testser(1)});
        
        leg.Interpreter = 'latex';
        ax(s).FontSize = 24;
        ax(s).Title.FontSize = ax(s).FontSize+2;
        leg.FontSize = ax(s).FontSize+2;
        
    end
    
    figname = sprintf('errhist_%s_%s', ...
        trainser(1), testser(1));
    
    if colour_inversion
        
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
