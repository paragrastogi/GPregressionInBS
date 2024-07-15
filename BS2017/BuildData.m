function [xin, xmeans, xstdevs, xlabels, ...
    yin, ymeans, ystdevs, ylabels] = ...
    BuildData(ser, features, varargin)

p = inputParser;
p.FunctionName = 'BuildData';

addRequired(p, 'ser', @ischar)
addRequired(p, 'features', @islogical)
addParameter(p, 'pathSUMfolder', '.', @ischar)
% This parameter, passed as a logical, builds data with the
% required number of inputs. This is generally used with ARD
% to test if the exclusion of certain parameters (usually
% based on correlation) was justified. 

parse(p, ser, features, varargin{:})

ser = p.Results.ser;
features = p.Results.features;
pathSUMfolder= p.Results.pathSUMfolder;

% If the sumtable variable is not loaded
if exist('sumtable', 'var')~=1 && ...
		exist('SummaryTable', 'var')~=1
	load(fullfile(pathSUMfolder, ...
		['SummaryTable_',ser,'.mat']))
% If the loaded tables in not, somehow, called sumtable,
% then rename it.
end

if exist('sumtable', 'var')~=1 && ...
		exist('SummaryTable', 'var')==1
	sumtable = SummaryTable;
	clear SummaryTable
end

% Throw out the field called Case, which is a duplicate of
% the field IDFname
sumtable(:,strcmp(sumtable.Properties.VariableNames, ...
	'Case')) = [];
sumtable.Properties.VariableNames = ...
	lower(sumtable.Properties.VariableNames);

% Remove rows containing NaNs but only for numeric
% variables.
numvars = varfun(@isnumeric,sumtable(1,:));
nanfind = any(isnan(sumtable{:,numvars{1,:}}),2);

% Throw out the C23 simulations. This is specific only to
% the G-series.
if strcmpi(ser, 'G') || strcmpi(ser, 'G_GEN')
    findodds = ~cellfun(@isempty, ...
        regexp(sumtable.idfname, 'C23'));
else
    findodds = false(size(sumtable,1),1);
end


% This bit is not necessary for the regression. Rather, it
% cleans up variable names and suchlike to make sure the
% script runs without bugs.

sumtable(nanfind | findodds,:) = [];

fprintf(['%d NaNs or other unsuitable data found '...
	'in response data.\r\n'], sum(nanfind | findodds))

sumtable.Properties.VariableNames(strcmp( ...
	sumtable.Properties.VariableNames, ...
	'wthrsource')) = {'wthrsrc'};
sumtable.Properties.VariableNames(strcmp( ...
	sumtable.Properties.VariableNames, ...
	'weatherfolder')) = {'wthrfolder'};
sumtable.Properties.VariableNames(strcmp( ...
	sumtable.Properties.VariableNames, ...
	'weatherfile')) = {'wthrfile'};
sumtable.Properties.VariableNames(strcmp( ...
	sumtable.Properties.VariableNames, ...
	'weatherfile')) = {'wthrfile'};
sumtable.Properties.VariableNames(strcmp( ...
	sumtable.Properties.VariableNames, ...
	'mrangtdb')) = {'mrtdb'};

% Make a vector of preferences for picking the various
% weather sources
sumtable.wthrsrcpref = NaN(size(sumtable.wthrsrc));
% Prefer typical
sumtable.wthrsrcpref(strcmp(sumtable.wthrsrc, ...
	'typical')) = 1;
sumtable.wthrsrcpref(strcmp(sumtable.wthrsrc, ...
	'actual')) = 2;
sumtable.wthrsrcpref(ismember(sumtable.wthrsrc, ...
	{'synthetic', 'rcp45', 'rcp85'})) = 3;

% Sort the table by weather source preference order, then by
% weather file name, then by IDF name
sumtable = sortrows(sumtable, ...
	{'wthrsrcpref', 'wthrfile', 'idfname'});


% Temp & Humidity Groups
tdbgrp = {'medtdb','iqrtdb', 'avtdb','mrtdb'};
tdpgrp = {'medtdp','iqrtdp', 'avtdp'};
rhgrp = {'medrh','iqrrh', 'avrh'};

% Solar
solgrp = {'avdni', 'sumdni', 'sumghi', 'iqrdni', 'iqrghi', 'avghi'};

% Building
bldgrp1 = {'wfr', 'wwr', 'tmass', 'uval'};
bldgrp2 = {'rr', 'ff', 'sumihg'};

% Infiltration
infgrp = {'suminfloss', 'suminfgain'};

% Degree days
ddgrp = {'hdd','cdd', 'avgsunperc'};

finrealpred = [ ...
	find(ismember(sumtable.Properties.VariableNames, ...
	tdbgrp)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	tdpgrp)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	solgrp)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	rhgrp)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	bldgrp1)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	bldgrp2)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	infgrp)), ...
	find(ismember(sumtable.Properties.VariableNames, ...
	ddgrp))];

% Keep only the requested features.
finrealpred = finrealpred(features);

% xin is the matrix of inputs for regression. The xmeans and
% xstdevs are for plotting and to keep track of what is
% happening with the inputs. 
[xin, xmeans, xstdevs] = zscore(sumtable{:,finrealpred});
% The xlabels are to keep track of the labels, naturally.
xlabels = [tdbgrp, tdpgrp, solgrp, rhgrp, bldgrp1, ...
    bldgrp2, infgrp, ddgrp];

% yin is the zscore of the outputs. ymeans and ystdevs serve
% the same purpose as xmeans and xstdevs.
[yin, ymeans, ystdevs] = zscore([sumtable.heatnorm, ...
    sumtable.coolnorm]);
ylabels = {'heat', 'cool'};

end