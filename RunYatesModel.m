function Results = RunYatesModel(MopRange, StartYear, EndYear, varargin)
% RunYatesModel - Run Yates equilibrium model and compare to survey observations
%
% SYNTAX:
%   Results = RunYatesModel(MopRange, StartYear, EndYear)
%   Results = RunYatesModel(MopRange, StartYear, EndYear, 'param', value, ...)
%
% INPUTS:
%   MopRange  - [MopStart MopEnd] or single MOP number
%   StartYear - Start year for analysis
%   EndYear   - End year for analysis
%
% OPTIONAL PARAMETERS (name-value pairs):
%   'ShorelineElev' - 'MHW' (default), 'MHHW', or 'MSL'
%   'MopPath'       - Path to SM mat files (default: '/volumes/group/MOPS/')
%   'a'             - Equilibrium energy slope (default: -0.0045)
%   'b'             - Equilibrium energy intercept (default: 0.07)
%   'Cplus'         - Accretion coefficient (default: -1.16)
%   'Cminus'        - Erosion coefficient (default: -1.38)
%   'PlotResults'   - true (default) or false
%   'SaveResults'   - true (default) or false
%
% OUTPUT:
%   Results - Struct containing model results and skill metrics
%
% EXAMPLE:
%   Results = RunYatesModel([581 590], 2016, 2024);
%   Results = RunYatesModel(582, 2018, 2024, 'ShorelineElev', 'MSL');
%   Results = RunYatesModel([580 590], 2016, 2025, 'MopPath', '/Volumes/group/MOPS/');
%
% NOTES:
%   - Requires 'intersections.m' function (in MOPS toolbox)
%   - Reads beach widths from SM (Survey Morphology) mat files
%   - Wave data fetched from CDIP MOP THREDDS server
%
% Reference: Yates, M.L., Guza, R.T., & O'Reilly, W.C. (2009)
%
% See also: YatesEquilibriumModelComparison, intersections

%% Parse inputs
p = inputParser;
addRequired(p, 'MopRange', @isnumeric);
addRequired(p, 'StartYear', @isnumeric);
addRequired(p, 'EndYear', @isnumeric);
addParameter(p, 'ShorelineElev', 'MHW', @ischar);
addParameter(p, 'MopPath', '/volumes/group/MOPS/', @ischar);
addParameter(p, 'a', -0.0045, @isnumeric);
addParameter(p, 'b', 0.07, @isnumeric);
addParameter(p, 'Cplus', -1.16, @isnumeric);
addParameter(p, 'Cminus', -1.38, @isnumeric);
addParameter(p, 'PlotResults', true, @islogical);
addParameter(p, 'SaveResults', false, @islogical);
parse(p, MopRange, StartYear, EndYear, varargin{:});

% Handle single MOP case
if numel(MopRange) == 1
    MopRange = [MopRange MopRange];
end

ShorelineElev = p.Results.ShorelineElev;
a = p.Results.a;
b = p.Results.b;
Cplus = p.Results.Cplus;
Cminus = p.Results.Cminus;
mpath = p.Results.MopPath;

% MOP station for wave data
MopNumber = round(mean(MopRange));
stn = ['D' num2str(MopNumber,'%4.4i')];

%% Load shoreline survey data from SM files
fprintf('Loading shoreline survey data from SM files...\n');

% Tide elevation for beach width definition (NAVD88)
switch upper(ShorelineElev)
    case 'MHW'
        Zcontour = 1.344;
    case 'MHHW'
        Zcontour = 1.566;
    case 'MSL'
        Zcontour = 0.774;
    otherwise
        error('ShorelineElev must be MHW, MHHW, or MSL');
end

% Collect beach width data from all MOPs in range
allDates = [];
allWidths = [];

for m = MopRange(1):MopRange(2)
    smfile = [mpath 'M' num2str(m,'%5.5i') 'SM.mat'];
    
    if exist(smfile, 'file')
        load(smfile, 'SM');
        
        for n = 1:length(SM)
            X1D = SM(n).X1D;
            Z1D = SM(n).Z1Dmean;
            
            if ~isempty(X1D) && ~isempty(Z1D) && any(~isnan(Z1D))
                xWidth = intersections([-50 200], [Zcontour Zcontour], X1D, Z1D);
                
                if ~isempty(xWidth)
                    allDates = [allDates; SM(n).Datenum];
                    allWidths = [allWidths; min(xWidth)];
                end
            end
        end
    end
end

% Remove outliers
TF = isoutlier(allWidths);
allWidths(TF) = NaN;

% Filter by time range
timeIdx = allDates >= datenum(StartYear,1,1) & allDates <= datenum(EndYear,12,31);
survDateNum = allDates(timeIdx);
survWidth = allWidths(timeIdx);

% Calculate spatial mean width for each survey date
[uniqueDates, ~, dateGroup] = unique(survDateNum);
spatialMeanWidth = accumarray(dateGroup, survWidth, [], @(x) mean(x,'omitnan'));

% Remove NaN values and sort
validIdx = ~isnan(spatialMeanWidth);
uniqueDates = uniqueDates(validIdx);
spatialMeanWidth = spatialMeanWidth(validIdx);
[uniqueDates, sortIdx] = sort(uniqueDates);
spatialMeanWidth = spatialMeanWidth(sortIdx);

meanS = mean(spatialMeanWidth, 'omitnan');
fprintf('Mean %s shoreline: %.1f m, %d survey dates\n', ...
    ShorelineElev, meanS, length(uniqueDates));

%% Load MOP wave data
fprintf('Loading MOP wave data...\n');
urlbase = 'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';

try
    % Hindcast
    dsurl = strcat(urlbase, stn, '_hindcast.nc');
    wavehs_hind = ncread(dsurl, 'waveHs');
    wavetime_hind = ncread(dsurl, 'waveTime');
    wavetime_hind = datetime(wavetime_hind, 'ConvertFrom', 'posixTime', ...
        'TimeZone', 'America/Los_Angeles');
    
    % Try nowcast too
    try
        dsurl = strcat(urlbase, stn, '_nowcast.nc');
        wavehs_now = ncread(dsurl, 'waveHs');
        wavetime_now = ncread(dsurl, 'waveTime');
        wavetime_now = datetime(wavetime_now, 'ConvertFrom', 'posixTime', ...
            'TimeZone', 'America/Los_Angeles');
        wavetime = [wavetime_hind; wavetime_now];
        wavehs = [wavehs_hind; wavehs_now];
    catch
        wavetime = wavetime_hind;
        wavehs = wavehs_hind;
    end
    
    E = (wavehs/4).^2;
catch ME
    error('Failed to load wave data: %s', ME.message);
end

%% Run Yates model
fprintf('Running Yates model...\n');
nSurveys = length(uniqueDates);
modelWidth = NaN(nSurveys, 1);
modelWidth(1) = spatialMeanWidth(1);

allModelTime = [];
allModelWidth = [];

for ns = 2:nSurveys
    t1 = datetime(uniqueDates(ns-1), 'ConvertFrom', 'datenum', ...
        'TimeZone', 'America/Los_Angeles');
    t2 = datetime(uniqueDates(ns), 'ConvertFrom', 'datenum', ...
        'TimeZone', 'America/Los_Angeles');
    
    waveIdx = find(wavetime >= t1 & wavetime <= t2);
    
    if isempty(waveIdx)
        modelWidth(ns) = modelWidth(ns-1);
        continue;
    end
    
    S = modelWidth(ns-1) - meanS;
    intervalTime = wavetime(waveIdx);
    intervalWidth = NaN(length(waveIdx), 1);
    
    for i = 1:length(waveIdx)
        wi = waveIdx(i);
        Eeq = a * S + b;
        deltaE = E(wi) - Eeq;
        
        if deltaE > 0
            dSdt = Cminus * sqrt(E(wi)) * deltaE;
        else
            dSdt = Cplus * sqrt(E(wi)) * deltaE;
        end
        
        S = S + dSdt;
        intervalWidth(i) = S + meanS;
    end
    
    modelWidth(ns) = intervalWidth(end);
    allModelTime = [allModelTime; intervalTime];
    allModelWidth = [allModelWidth; intervalWidth];
end

%% Calculate metrics
observed = spatialMeanWidth;
predicted = modelWidth;
divergence = predicted - observed;
accumDivergence = cumsum(divergence, 'omitnan');

validPairs = ~isnan(observed) & ~isnan(predicted);
obs = observed(validPairs);
pred = predicted(validPairs);

RMSE = sqrt(mean((obs - pred).^2));
MAE = mean(abs(obs - pred));
bias = mean(pred - obs);
R2 = 1 - sum((obs - pred).^2) / sum((obs - mean(obs)).^2);

fprintf('RMSE=%.2fm, MAE=%.2fm, Bias=%.2fm, R²=%.3f\n', RMSE, MAE, bias, R2);

%% Store results
Results.MopRange = MopRange;
Results.ShorelineElev = ShorelineElev;
Results.StartYear = StartYear;
Results.EndYear = EndYear;
Results.YatesParams = struct('a', a, 'b', b, 'Cplus', Cplus, 'Cminus', Cminus);
Results.MeanShoreline = meanS;
Results.SurveyDates = uniqueDates;
Results.SurveyDatetimes = datetime(uniqueDates, 'ConvertFrom', 'datenum', ...
    'TimeZone', 'America/Los_Angeles');
Results.ObservedWidth = observed;
Results.PredictedWidth = predicted;
Results.Divergence = divergence;
Results.AccumDivergence = accumDivergence;
Results.ContinuousModelTime = allModelTime;
Results.ContinuousModelWidth = allModelWidth;
Results.WaveTime = wavetime;
Results.WaveEnergy = E;
Results.RMSE = RMSE;
Results.MAE = MAE;
Results.Bias = bias;
Results.R2 = R2;

%% Plot if requested
if p.Results.PlotResults
    PlotYatesResults(Results);
end

%% Save if requested
if p.Results.SaveResults
    outfile = sprintf('YatesModelResults_MOP%d-%d_%d-%d.mat', ...
        MopRange(1), MopRange(2), StartYear, EndYear);
    save(outfile, 'Results');
    fprintf('Saved to %s\n', outfile);
end

end

%% =======================================================================
function PlotYatesResults(R)
% Helper function to plot Yates model results

figure('Position', [50 50 1200 800], 'Color', 'w');

survDT = R.SurveyDatetimes;

% Panel 1: Wave Energy
subplot(3,1,1);
plot(R.WaveTime, R.WaveEnergy, 'b-', 'LineWidth', 0.5);
hold on;
for ns = 1:length(survDT)
    xline(survDT(ns), 'k--', 'LineWidth', 0.3);
end
ylabel('Wave Energy (m²)');
title(sprintf('Wave Energy (Hs/4)² - MOP %d', round(mean(R.MopRange))));
xlim([survDT(1) survDT(end)]);
grid on;

% Panel 2: Beach Width comparison
subplot(3,1,2);
if ~isempty(R.ContinuousModelTime)
    plot(R.ContinuousModelTime, R.ContinuousModelWidth, 'b-', 'LineWidth', 1);
    hold on;
end
plot(survDT, R.ObservedWidth, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
hold on;
plot(survDT, R.PredictedWidth, 'bs', 'MarkerSize', 6, 'MarkerFaceColor', 'b');
yline(R.MeanShoreline, 'k--', 'LineWidth', 1.5);
ylabel(sprintf('%s Width (m)', R.ShorelineElev));
title(sprintf('Yates Model vs Observed (MOPs %d-%d) | RMSE=%.1fm, R²=%.2f', ...
    R.MopRange(1), R.MopRange(2), R.RMSE, R.R2));
xlim([survDT(1) survDT(end)]);
legend('Model', 'Observed', 'Predicted', 'Mean', 'Location', 'best');
grid on;

% Panel 3: Accumulated divergence
subplot(3,1,3);
area(survDT, R.AccumDivergence, 'FaceColor', [0.8 0.8 1], 'EdgeColor', 'b');
hold on;
yline(0, 'k-', 'LineWidth', 1);
ylabel('Cumulative Error (m)');
xlabel('Time');
title('Accumulated Model Divergence');
xlim([survDT(1) survDT(end)]);
grid on;

sgtitle(sprintf('Yates Equilibrium Model Comparison (%d-%d)', ...
    R.StartYear, R.EndYear), 'FontSize', 13, 'FontWeight', 'bold');

end
