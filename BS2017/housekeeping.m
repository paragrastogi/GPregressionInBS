function [xin, yin] = housekeeping(ser, lo, features, path_save_fldr)

if exist(sprintf('gpdata_%s.mat', ser),'file')~=2
    % If there is no processed data available, then call the
    % build data function.
    [xin, xmeans, xstdevs, xlabels, ...
        yin, ymeans, ystdevs, ylabels] = ...
        BuildData(ser, features);
    save(sprintf('gpdata_%s.mat',ser), ...
        'xin','xmeans', 'xstdevs', 'xlabels', ...
        'yin', 'ymeans', 'ystdevs', 'ylabels')
    
else
    
    load(sprintf('gpdata_%s.mat', ser))
    
end

% Keep only the relevant output column
yin = yin(:,lo);
ymeans = ymeans(lo);
ystdevs = ystdevs(lo);
ylabels = ylabels(lo);

%%%%%%% %%%%%
% Sometimes, a temporary folder must be
% created to enable multiple runs which are in danger of
% overwriting on the same files.
% path_save_fldr = [path_save_fldr, '_0N'];
%%%%%%% %%%%%

if exist(path_save_fldr, 'dir') ~=7
    mkdir(path_save_fldr)
end


% Run the GP startup script so its functions are accesible.
path_gpml = fullfile('.','gpml');
if exist(path_gpml,'dir')==7
    addpath(path_gpml)
    startup
else
    fprintf(['I didn''t find a folder for the GPML ', ...
        'toolbox at %s .\r\nI''m assuming that the ', ...
        'GPML toolbox is on the path somewhere.\r\n', ...
        'Otherwise this script will crash... ', ...
        'and burn !\r\n'], path_gpml)
end

path_minfunc1 = fullfile('.','minFunc_2012');
path_minfunc2 = fullfile('C:', 'Users', 'rasto', ...
    'Documents', 'MATLAB', 'minFunc_2012');

if exist(path_minfunc1,'dir')~=7 && ...
        exist(path_minfunc2,'dir')~=7
    fprintf(['I didn''t find a folder for minFunc', ...
        'at %s or %s.\r\nI''m assuming that the ', ...
        'toolbox is on the path somewhere.\r\n', ...
        'Otherwise this script will crash... ', ...
        'and burn !\r\n'], path_minfunc1, path_minfunc2)
else
    if exist(path_minfunc1,'dir')==7
        path_minfunc = path_minfunc1;
    elseif exist(path_minfunc2,'dir')==7
        path_minfunc = path_minfunc2;
    end
    addpath(path_minfunc)
    addpath(fullfile(path_minfunc,'minFunc'))
    addpath(fullfile(path_minfunc,'minFunc','compiled'))
    addpath(fullfile(path_minfunc,'minFunc','mex'))
    addpath(fullfile(path_minfunc,'autoDif'))
end
