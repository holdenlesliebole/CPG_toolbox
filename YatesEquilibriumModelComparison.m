% YatesEquilibriumModelComparison.m
%
% Compares Yates et al. (2009) equilibrium beach width model predictions 
% with observed survey data for a specified MOP range. Starts from an 
% initial survey and runs the model forward through time, comparing
% predicted beach widths with subsequent survey observations.
%
% The Yates model relates shoreline change to wave energy:
%   dS/dt = C * sqrt(E) * (E - Eeq)
% where:
%   S = shoreline position (beach width)
%   E = wave energy (Hs/4)^2
%   Eeq = equilibrium energy for current shoreline position (Eeq = a*S + b)
%   C = response coefficients (Cplus for accretion, Cminus for erosion)
%
% Reference: Yates, M.L., Guza, R.T., & O'Reilly, W.C. (2009)
%            Equilibrium shoreline response: Observations and modeling.
%            JGR Oceans, 114, C09014.
%
% Holden Leslie-Bole & Copilot, Feb 2025
%--------------------------------------------------------------------------

clear all; close all;

%% ===== USER SETTINGS =====

% MOP Range to analyze (can be a single MOP or range)
MopRange = [576 589];  % Example: Torrey Pines area

% Use mean MOP number for wave data retrieval
MopNumber = round(mean(MopRange));
stn = ['D' num2str(MopNumber,'%4.4i')];

% Time range for analysis (adjust based on available data)
StartYear = 2016;  % Start year for analysis
EndYear = 2025;    % End year for analysis

% Shoreline elevation definition (NAVD88)
% Options: 'MHW' (0.774m), 'MHHW' (1.344m), 'MSL' (0m)
ShorelineElev = 'MHW';  

% Yates Model Coefficients (from Torrey Pines calibration, Yates et al. 2009)
Yates.b = 0.07;           % Equilibrium energy intercept
Yates.a = -0.0045;        % Equilibrium energy slope
Yates.Cminus = -1.38;     % Erosion coefficient (E > Eeq)
Yates.Cplus = -1.16;      % Accretion coefficient (E < Eeq)

% Ludka et al. coefficients (alternative calibration)
Ludka.b = 0.06;           % Equilibrium energy intercept
Ludka.a = -0.004;         % Equilibrium energy slope  
Ludka.Cminus = -1.2;      % Erosion coefficient (E > Eeq)
Ludka.Cplus = -1.0;       % Accretion coefficient (E < Eeq)

% B.3: Asymmetric Recovery Model
% Models slower recovery by making Cplus time-varying based on recent storm history
% After large events, recovery is initially slow then speeds up
Asymmetric.b = 0.06;
Asymmetric.a = -0.004;
Asymmetric.Cminus = -1.2;           % Erosion coefficient (same as Ludka)
Asymmetric.Cplus_base = -0.5;       % Base accretion coefficient (slower than Ludka)
Asymmetric.Cplus_max = -1.2;        % Max accretion coefficient (matches erosion)
Asymmetric.tau_recovery = 60;       % Recovery timescale (days)
Asymmetric.Ethresh_storm = 0.15;    % Storm threshold for triggering slow recovery

% B.4: Profile Shape Tracking - track beach slope as state variable
% Slope affects equilibrium position (steeper beach = narrower equilibrium)
SlopeModel.b = 0.06;
SlopeModel.a = -0.004;
SlopeModel.Cminus = -1.2;
SlopeModel.Cplus = -1.0;
SlopeModel.slopeWeight = 5;         % How much slope deviation affects equilibrium (m per unit slope)
SlopeModel.targetSlope = 0.05;      % Reference beach slope (~1:20)

% B.5: Multi-contour tracking elevations
MultiContour.elevations = [0.774, 1.344, 1.566];  % MSL, MHW, MHHW (NAVD88)
MultiContour.labels = {'MSL', 'MHW', 'MHHW'};
MultiContour.enabled = true;        % Set false to skip multi-contour analysis

%% ===== LOAD SHORELINE SURVEY DATA FROM SM FILES =====
% Gets beach widths directly from SM (Survey Morphology) mat files
% using profile intersection with specified tide elevation.

fprintf('Loading shoreline survey data from SM files...\n');

% Path to MOP SM files (adjust if needed)
mpath = '/volumes/group/MOPS/';

% Tide elevation for beach width definition (NAVD88)
switch ShorelineElev
    case 'MHW'
        Zcontour = 1.344;  % MHW in NAVD88
    case 'MHHW'
        Zcontour = 1.566;  % MHHW in NAVD88
    case 'MSL'
        Zcontour = 0.774;  % MSL in NAVD88
end

% Collect beach width data from all MOPs in range
allDates = [];
allMops = [];
allWidths = [];
allSlopes = [];  % B.4: Beach face slopes

for m = MopRange(1):MopRange(2)
    smfile = [mpath 'M' num2str(m,'%5.5i') 'SM.mat'];
    
    if exist(smfile, 'file')
        load(smfile, 'SM');
        fprintf('  MOP %d: %d surveys\n', m, length(SM));
        
        for n = 1:length(SM)
            % Get profile data
            X1D = SM(n).X1D;
            % Use Z1Dmean for spatial averaging, or Z1Dtransect for single transect
            Z1D = SM(n).Z1Dmean;  
            
            if ~isempty(X1D) && ~isempty(Z1D) && any(~isnan(Z1D))
                % Find intersection with contour elevation
                xWidth = intersections([-50 200], [Zcontour Zcontour], X1D, Z1D);
                
                if ~isempty(xWidth)
                    % Use minimum (landward-most) intersection as beach width
                    allDates = [allDates; SM(n).Datenum];
                    allMops = [allMops; m];
                    allWidths = [allWidths; min(xWidth)];
                    
                    % B.4: Extract beach face slope for profile shape tracking
                    % Estimate slope between MSL and MHW elevations
                    xMSL = intersections([-50 200], [0.774 0.774], X1D, Z1D);
                    xMHW = intersections([-50 200], [1.344 1.344], X1D, Z1D);
                    if ~isempty(xMSL) && ~isempty(xMHW)
                        dx = min(xMHW) - min(xMSL);
                        dz = 1.344 - 0.774;  % 0.57m elevation difference
                        if dx > 0
                            allSlopes = [allSlopes; dz/dx];
                        else
                            allSlopes = [allSlopes; NaN];
                        end
                    else
                        allSlopes = [allSlopes; NaN];
                    end
                else
                    % Need to add NaN slope if we skip this observation
                    % (handled by not adding anything here)
                end
            end
        end
    else
        fprintf('  MOP %d: SM file not found\n', m);
    end
end

fprintf('Collected %d beach width observations\n', length(allWidths));

% Remove outliers
TF = isoutlier(allWidths);
allWidths(TF) = NaN;

% B.4: Remove slope outliers too
if ~isempty(allSlopes)
    TFslope = isoutlier(allSlopes);
    allSlopes(TFslope) = NaN;
end

% Filter by time range
timeIdx = allDates >= datenum(StartYear,1,1) & allDates <= datenum(EndYear,12,31);
survDateNum = allDates(timeIdx);
survMop = allMops(timeIdx);
survWidth = allWidths(timeIdx);
survSlope = allSlopes(timeIdx);  % B.4: Filtered slopes

% Calculate spatial mean width for each unique survey date
[uniqueDates, ~, dateGroup] = unique(survDateNum);
spatialMeanWidth = accumarray(dateGroup, survWidth, [], @(x) mean(x,'omitnan'));

% B.4: Calculate spatial mean slope for each survey date
spatialMeanSlope = accumarray(dateGroup, survSlope, [], @(x) mean(x,'omitnan'));

% Remove dates with NaN mean widths
validIdx = ~isnan(spatialMeanWidth);
uniqueDates = uniqueDates(validIdx);
spatialMeanWidth = spatialMeanWidth(validIdx);
spatialMeanSlope = spatialMeanSlope(validIdx);  % B.4: Keep slope aligned

% Sort by date
[uniqueDates, sortIdx] = sort(uniqueDates);
spatialMeanWidth = spatialMeanWidth(sortIdx);
spatialMeanSlope = spatialMeanSlope(sortIdx);  % B.4: Keep slope aligned

% Calculate mean shoreline position (equilibrium reference)
meanS = mean(spatialMeanWidth, 'omitnan');
meanSlope = mean(spatialMeanSlope, 'omitnan');  % B.4: Mean slope
fprintf('Mean %s shoreline position: %.1f m\n', ShorelineElev, meanS);
fprintf('Mean beach face slope: %.3f (1:%.0f)\n', meanSlope, 1/meanSlope);
fprintf('Found %d unique survey dates for MOP range %d-%d\n', ...
    length(uniqueDates), MopRange(1), MopRange(2));

%% ===== LOAD MOP WAVE DATA =====

fprintf('Loading MOP wave data from THREDDS...\n');

% Create URL for MOP hindcast data
urlbase = 'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';
urlend = '_hindcast.nc';
dsurl = strcat(urlbase, stn, urlend);

try
    % Read hindcast wave data
    wavehs_hind = ncread(dsurl, 'waveHs');
    wavetime_hind = ncread(dsurl, 'waveTime');
    wavetime_hind = datetime(wavetime_hind, 'ConvertFrom', 'posixTime', ...
        'TimeZone', 'America/Los_Angeles');
    
    % Also try to get nowcast data for more recent times
    urlend = '_nowcast.nc';
    dsurl = strcat(urlbase, stn, urlend);
    
    try
        wavehs_now = ncread(dsurl, 'waveHs');
        wavetime_now = ncread(dsurl, 'waveTime');
        wavetime_now = datetime(wavetime_now, 'ConvertFrom', 'posixTime', ...
            'TimeZone', 'America/Los_Angeles');
        
        % Concatenate hindcast and nowcast
        wavetime = [wavetime_hind; wavetime_now];
        wavehs = [wavehs_hind; wavehs_now];
    catch
        wavetime = wavetime_hind;
        wavehs = wavehs_hind;
        fprintf('Note: Only hindcast data available\n');
    end
    
    % Convert to wave energy
    E = (wavehs/4).^2;
    
    fprintf('Wave data loaded: %s to %s\n', ...
        datestr(wavetime(1)), datestr(wavetime(end)));
    
catch ME
    error('Failed to load MOP wave data: %s', ME.message);
end

%% ===== RUN EQUILIBRIUM MODELS FROM FIRST SURVEY =====

% Run Yates, Ludka, Asymmetric Recovery, and Slope-dependent models
modelNames = {'Yates', 'Ludka', 'Asymmetric', 'SlopeModel'};
modelParams = {Yates, Ludka, Asymmetric, SlopeModel};
modelColors = {[0 0.4 0.8], [0.9 0.5 0], [0.6 0.2 0.8], [0.2 0.7 0.3]}; % Blue, Orange, Purple, Green
nModels = length(modelNames);

nSurveys = length(uniqueDates);

% Initialize storage for all models
for m = 1:nModels
    Models(m).name = modelNames{m};
    Models(m).params = modelParams{m};
    Models(m).color = modelColors{m};
    Models(m).modelWidth = NaN(nSurveys, 1);
    Models(m).modelWidth(1) = spatialMeanWidth(1);
    Models(m).allModelTime = [];
    Models(m).allModelWidth = [];
    Models(m).modelSlope = NaN(nSurveys, 1);  % B.4: Track slope
    Models(m).modelSlope(1) = spatialMeanSlope(1);
end

% B.3: Initialize storm history tracking for asymmetric model
lastStormTime = datetime(uniqueDates(1), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
lastStormEnergy = 0;

% Run all models
for m = 1:nModels
    fprintf('Running %s equilibrium model...\n', modelNames{m});
    params = modelParams{m};
    
    % B.3: Reset storm tracking for each model
    lastStormTime = datetime(uniqueDates(1), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    
    % Loop through survey intervals
    for ns = 2:nSurveys
        
        % Get start and end times for this interval
        t1 = datetime(uniqueDates(ns-1), 'ConvertFrom', 'datenum', ...
            'TimeZone', 'America/Los_Angeles');
        t2 = datetime(uniqueDates(ns), 'ConvertFrom', 'datenum', ...
            'TimeZone', 'America/Los_Angeles');
        
        % Find wave data indices for this interval
        waveIdx = find(wavetime >= t1 & wavetime <= t2);
        
        if isempty(waveIdx)
            if m == 1  % Only warn once
                warning('No wave data for interval %s to %s', datestr(t1), datestr(t2));
            end
            Models(m).modelWidth(ns) = Models(m).modelWidth(ns-1);
            Models(m).modelSlope(ns) = Models(m).modelSlope(ns-1);
            continue;
        end
        
        % Initialize shoreline position relative to mean
        S = Models(m).modelWidth(ns-1) - meanS;
        
        % B.4: Initialize slope state for slope-dependent model
        currentSlope = Models(m).modelSlope(ns-1);
        if isnan(currentSlope)
            currentSlope = meanSlope;
        end
        
        % Store continuous trajectory for this interval
        intervalTime = wavetime(waveIdx);
        intervalWidth = NaN(length(waveIdx), 1);
        
        % Step through hourly wave data using equilibrium equations
        for i = 1:length(waveIdx)
            wi = waveIdx(i);
            currentTime = wavetime(wi);
            
            % Model-specific equilibrium calculations
            if strcmp(modelNames{m}, 'Asymmetric')
                % B.3: Asymmetric Recovery Model
                % Equilibrium energy (same as standard)
                Eeq = params.a * S + params.b;
                deltaE = E(wi) - Eeq;
                
                % Check for storm events and update storm history
                if E(wi) > params.Ethresh_storm
                    lastStormTime = currentTime;
                    lastStormEnergy = E(wi);
                end
                
                % Calculate time-varying Cplus based on recovery phase
                daysSinceStorm = days(currentTime - lastStormTime);
                recoveryFactor = 1 - exp(-daysSinceStorm / params.tau_recovery);
                Cplus_current = params.Cplus_base + (params.Cplus_max - params.Cplus_base) * recoveryFactor;
                
                % Shoreline change rate with asymmetric recovery
                if deltaE > 0
                    dSdt = params.Cminus * sqrt(E(wi)) * deltaE;  % Erosion (normal)
                else
                    dSdt = Cplus_current * sqrt(E(wi)) * deltaE;  % Accretion (time-varying)
                end
                
            elseif strcmp(modelNames{m}, 'SlopeModel')
                % B.4: Slope-dependent equilibrium model
                % Slope deviation from target affects equilibrium position
                slopeDeviation = currentSlope - params.targetSlope;
                slopeCorrection = params.slopeWeight * slopeDeviation;
                
                % Modified equilibrium energy (steeper beach -> lower Eeq -> wider equilibrium)
                Eeq = params.a * S + params.b - slopeCorrection * params.a;
                deltaE = E(wi) - Eeq;
                
                % Standard shoreline change rate
                if deltaE > 0
                    dSdt = params.Cminus * sqrt(E(wi)) * deltaE;
                else
                    dSdt = params.Cplus * sqrt(E(wi)) * deltaE;
                end
                
                % Update slope state: erosion steepens, accretion flattens
                slopeChange = -0.0001 * dSdt;  % Slope adjusts opposite to width change
                currentSlope = currentSlope + slopeChange;
                currentSlope = max(0.02, min(0.10, currentSlope));  % Bound slope
                
            else
                % Standard Yates/Ludka model
                % Eq. 4: equilibrium energy for current shoreline
                Eeq = params.a * S + params.b;
                
                % Eq. 3: difference from equilibrium
                deltaE = E(wi) - Eeq;
                
                % Eq. 2: shoreline change rate
                if deltaE > 0
                    dSdt = params.Cminus * sqrt(E(wi)) * deltaE;  % Erosion
                else
                    dSdt = params.Cplus * sqrt(E(wi)) * deltaE;   % Accretion
                end
            end
            
            % Update shoreline position (hourly timestep)
            S = S + dSdt;
            intervalWidth(i) = S + meanS;
        end
        
        % Store final model prediction for this survey date
        Models(m).modelWidth(ns) = intervalWidth(end);
        Models(m).modelSlope(ns) = currentSlope;  % B.4: Store slope state
        
        % Append to continuous trajectory
        Models(m).allModelTime = [Models(m).allModelTime; intervalTime];
        Models(m).allModelWidth = [Models(m).allModelWidth; intervalWidth];
    end
end

% For backward compatibility, keep Yates results in original variable names
modelWidth = Models(1).modelWidth;
allModelTime = Models(1).allModelTime;
allModelWidth = Models(1).allModelWidth;

%% ===== CALCULATE MODEL SKILL METRICS =====

observed = spatialMeanWidth;

fprintf('\n===== MODEL SKILL METRICS =====\n');
for m = 1:nModels
    predicted = Models(m).modelWidth;
    
    % Remove NaN values for statistics
    validPairs = ~isnan(observed) & ~isnan(predicted);
    obs = observed(validPairs);
    pred = predicted(validPairs);
    
    % Accumulated divergence (running sum of errors)
    Models(m).divergence = predicted - observed;
    Models(m).accumDivergence = cumsum(Models(m).divergence, 'omitnan');
    
    % Skill metrics
    Models(m).RMSE = sqrt(mean((obs - pred).^2));
    Models(m).MAE = mean(abs(obs - pred));
    Models(m).bias = mean(pred - obs);
    Models(m).R2 = 1 - sum((obs - pred).^2) / sum((obs - mean(obs)).^2);
    
    fprintf('\n--- %s Model ---\n', Models(m).name);
    fprintf('RMSE:     %.2f m\n', Models(m).RMSE);
    fprintf('MAE:      %.2f m\n', Models(m).MAE);
    fprintf('Bias:     %.2f m\n', Models(m).bias);
    fprintf('R²:       %.3f\n', Models(m).R2);
end
fprintf('================================\n');

% For backward compatibility
divergence = Models(1).divergence;
accumDivergence = Models(1).accumDivergence;
RMSE = Models(1).RMSE;
MAE = Models(1).MAE;
bias = Models(1).bias;
R2 = Models(1).R2;

%% ===== PLOT RESULTS =====

figure('Position', [50 50 1200 900], 'Color', 'w');

% --- Panel 1: Wave Energy Time Series ---
subplot(4,1,1);
plot(wavetime, E, 'b-', 'LineWidth', 0.5);
hold on;
survDT = datetime(uniqueDates, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
for ns = 1:nSurveys
    plot([survDT(ns) survDT(ns)], [0 max(E)], 'k--', 'LineWidth', 0.5);
end
ylabel('Wave Energy (m²)');
title(sprintf('MOP %s Wave Energy (Hs/4)² and Survey Dates', stn));
xlim([survDT(1) survDT(end)]);
grid on;
legend('E = (Hs/4)²', 'Survey Dates', 'Location', 'northwest');

% --- Panel 2: Beach Width - Observed vs Modeled ---
subplot(4,1,2);
hold on;

% Plot continuous model trajectories for all models
for m = 1:nModels
    plot(Models(m).allModelTime, Models(m).allModelWidth, '-', ...
        'Color', Models(m).color, 'LineWidth', 1, ...
        'DisplayName', sprintf('%s Model', Models(m).name));
end

% Plot observed survey widths
plot(survDT, observed, 'ko', 'MarkerSize', 3, 'MarkerFaceColor', 'k', ...
    'DisplayName', 'Observed');

% Plot model predictions at survey times
for m = 1:nModels
    plot(survDT, Models(m).modelWidth, 's', 'MarkerSize', 2, ...
        'Color', Models(m).color, 'MarkerFaceColor', Models(m).color, ...
        'HandleVisibility', 'off');
end

% Plot mean shoreline
plot([survDT(1) survDT(end)], [meanS meanS], 'k--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Mean Shoreline (%.1fm)', meanS));

ylabel(sprintf('%s Beach Width (m)', ShorelineElev));
title(sprintf('Equilibrium Models vs Observed Shoreline (MOPs %d-%d)', ...
    MopRange(1), MopRange(2)));
xlim([survDT(1) survDT(end)]);
grid on;
legend('Location', 'best');

% --- Panel 3: Model Error (Predicted - Observed) ---
subplot(4,1,3);
hold on;
barWidth = 0.25;
barOffsets = linspace(-0.3, 0.3, nModels);
for m = 1:nModels
    bar(survDT + days(barOffsets(m)*5), Models(m).divergence, barWidth, ...
        'FaceColor', Models(m).color, 'EdgeColor', Models(m).color, 'FaceAlpha', 0.7, ...
        'DisplayName', Models(m).name);
end
plot([survDT(1) survDT(end)], [0 0], 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
ylabel('Error (m)');
title('Model Error (Predicted - Observed)');
legend('Location', 'best');
xlim([survDT(1) survDT(end)]);
grid on;

% --- Panel 4: Accumulated Divergence ---
subplot(4,1,4);
hold on;
for m = 1:nModels
    plot(survDT, Models(m).accumDivergence, '-', 'Color', Models(m).color, ...
        'LineWidth', 2, 'DisplayName', sprintf('%s (RMSE=%.1fm)', Models(m).name, Models(m).RMSE));
end
plot([survDT(1) survDT(end)], [0 0], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
ylabel('Accumulated Error (m)');
xlabel('Time');
title('Accumulated Model Divergence from Observations');
xlim([survDT(1) survDT(end)]);
grid on;
legend('Location', 'best');

% Add annotation with model parameters
annotation('textbox', [0.01 0.01 0.24 0.07], ...
    'String', sprintf('Yates: a=%.4f, b=%.2f, C⁺=%.2f, C⁻=%.2f', ...
    Yates.a, Yates.b, Yates.Cplus, Yates.Cminus), ...
    'FontSize', 7, 'BackgroundColor', 'w', 'EdgeColor', modelColors{1});
annotation('textbox', [0.26 0.01 0.24 0.07], ...
    'String', sprintf('Ludka: a=%.4f, b=%.2f, C⁺=%.2f, C⁻=%.2f', ...
    Ludka.a, Ludka.b, Ludka.Cplus, Ludka.Cminus), ...
    'FontSize', 7, 'BackgroundColor', 'w', 'EdgeColor', modelColors{2});
annotation('textbox', [0.51 0.01 0.24 0.07], ...
    'String', sprintf('Asymm: τ=%.0fd, C⁺base=%.2f', ...
    Asymmetric.tau_recovery, Asymmetric.Cplus_base), ...
    'FontSize', 7, 'BackgroundColor', 'w', 'EdgeColor', modelColors{3});
annotation('textbox', [0.76 0.01 0.23 0.07], ...
    'String', sprintf('Slope: wt=%.0f, target=%.2f', ...
    SlopeModel.slopeWeight, SlopeModel.targetSlope), ...
    'FontSize', 7, 'BackgroundColor', 'w', 'EdgeColor', modelColors{4});

% Adjust spacing
sgtitle(sprintf('Equilibrium Model Comparison: MOPs %d-%d (%d-%d)', ...
    MopRange(1), MopRange(2), StartYear, EndYear), 'FontSize', 14, 'FontWeight', 'bold');

%% ===== FIGURE 2: Scatter Plot and Error Distribution =====

figure('Position', [100 100 1400 450], 'Color', 'w');

% --- Panel 1: Scatter plot for all models ---
subplot(1,3,1);
hold on;

% Get axis limits from all data
allPred = [];
for m = 1:nModels
    allPred = [allPred; Models(m).modelWidth];
end
minVal = min([min(observed) min(allPred)]) - 5;
maxVal = max([max(observed) max(allPred)]) + 5;

% Plot all models
for m = 1:nModels
    validPairs = ~isnan(observed) & ~isnan(Models(m).modelWidth);
    scatter(observed(validPairs), Models(m).modelWidth(validPairs), 40, ...
        'MarkerFaceColor', Models(m).color, 'MarkerEdgeColor', Models(m).color, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', Models(m).name);
end

% 1:1 line
plot([minVal maxVal], [minVal maxVal], 'k-', 'LineWidth', 2, 'DisplayName', '1:1 Line');

xlabel(sprintf('Observed %s Width (m)', ShorelineElev));
ylabel(sprintf('Predicted %s Width (m)', ShorelineElev));
title('Observed vs Predicted');
axis equal;
xlim([minVal maxVal]);
ylim([minVal maxVal]);
grid on;
legend('Location', 'northwest');

% --- Panel 2: Error histograms ---
subplot(1,3,2);
hold on;
edges = linspace(-20, 20, 21);
for m = 1:nModels
    histogram(Models(m).divergence, edges, 'FaceColor', Models(m).color, ...
        'FaceAlpha', 0.4, 'EdgeColor', Models(m).color, 'DisplayName', Models(m).name);
end
xline(0, 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
xlabel('Model Error (m)');
ylabel('Count');
title('Distribution of Errors');
legend('Location', 'best');
grid on;

% --- Panel 3: Skill comparison bar chart ---
subplot(1,3,3);
metrics = zeros(3, nModels);
for m = 1:nModels
    metrics(1, m) = Models(m).RMSE;
    metrics(2, m) = Models(m).MAE;
    metrics(3, m) = abs(Models(m).bias);
end
b = bar(metrics);
for m = 1:nModels
    b(m).FaceColor = Models(m).color;
end
set(gca, 'XTickLabel', {'RMSE', 'MAE', '|Bias|'});
ylabel('Error (m)');
title('Model Skill Comparison');
legend({Models.name}, 'Location', 'best');
grid on;

% Add R² values as text
r2str = '';
for m = 1:nModels
    r2str = [r2str sprintf('%s=%.3f  ', Models(m).name, Models(m).R2)];
end
text(0.5, 0.95, ['R²: ' r2str], 'Units', 'normalized', 'FontSize', 9, 'HorizontalAlignment', 'center');

sgtitle(sprintf('Model Skill Comparison: MOPs %d-%d', MopRange(1), MopRange(2)), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% ===== FIGURE 3: Error Evolution Over Time =====

figure('Position', [150 150 1000 400], 'Color', 'w');

% Calculate time since start (in years)
timeSinceStart = years(survDT - survDT(1));

% Plot error magnitude vs time
subplot(1,2,1);
hold on;
for m = 1:nModels
    scatter(timeSinceStart, abs(Models(m).divergence), 40, ...
        'MarkerFaceColor', Models(m).color, 'MarkerEdgeColor', Models(m).color, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', Models(m).name);
    % Trend line
    validTime = ~isnan(abs(Models(m).divergence));
    p = polyfit(timeSinceStart(validTime), abs(Models(m).divergence(validTime)), 1);
    xfit = linspace(0, max(timeSinceStart), 100);
    yfit = polyval(p, xfit);
    plot(xfit, yfit, '-', 'Color', Models(m).color, 'LineWidth', 2, ...
        'HandleVisibility', 'off');
end
xlabel('Years Since Initial Survey');
ylabel('Absolute Error |Predicted - Observed| (m)');
title('Error Magnitude vs Forecast Horizon');
grid on;
legend('Location', 'best');

% Plot cumulative error vs time
subplot(1,2,2);
hold on;
for m = 1:nModels
    plot(timeSinceStart, Models(m).accumDivergence, '-', 'Color', Models(m).color, ...
        'LineWidth', 2, 'DisplayName', Models(m).name);
end
plot([0 max(timeSinceStart)], [0 0], 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel('Years Since Initial Survey');
ylabel('Cumulative Error (m)');
title('Cumulative Model Drift Over Time');
legend('Location', 'best');
grid on;

sgtitle('How Model Error Evolves With Time', 'FontSize', 12, 'FontWeight', 'bold');

%% ===== FIGURE 4: ERROR DIAGNOSTICS - Seasonal & Conditional Analysis =====

fprintf('\n===== ERROR DIAGNOSTICS =====\n');

figure('Position', [200 100 1400 900], 'Color', 'w');

% --- Calculate antecedent wave statistics for each survey ---
% For each survey, compute wave stats in preceding N days
lookbackDays = [30, 60, 90, 180]; % Multiple lookback windows
antecedentEmean = NaN(nSurveys, length(lookbackDays));
antecedentEmax = NaN(nSurveys, length(lookbackDays));
antecedentEsum = NaN(nSurveys, length(lookbackDays));
daysSinceStorm = NaN(nSurveys, 1);
stormThreshold = quantile(E, 0.95); % Top 5% wave energy = "storm"

for ns = 2:nSurveys
    survTime = datetime(uniqueDates(ns), 'ConvertFrom', 'datenum', ...
        'TimeZone', 'America/Los_Angeles');
    
    for lb = 1:length(lookbackDays)
        lookbackStart = survTime - days(lookbackDays(lb));
        idx = find(wavetime >= lookbackStart & wavetime <= survTime);
        if ~isempty(idx)
            antecedentEmean(ns, lb) = mean(E(idx), 'omitnan');
            antecedentEmax(ns, lb) = max(E(idx));
            antecedentEsum(ns, lb) = sum(E(idx), 'omitnan');
        end
    end
    
    % Find days since last storm event
    stormIdx = find(E > stormThreshold & wavetime <= survTime);
    if ~isempty(stormIdx)
        lastStormTime = wavetime(stormIdx(end));
        daysSinceStorm(ns) = days(survTime - lastStormTime);
    end
end

% --- Panel 1: Seasonal Error Breakdown ---
subplot(2,3,1);
hold on;

% Define seasons
survMonth = month(survDT);
winterIdx = survMonth <= 3 | survMonth >= 10;  % Oct-Mar
summerIdx = survMonth >= 4 & survMonth <= 9;   % Apr-Sep

seasonLabels = {'Winter (Oct-Mar)', 'Summer (Apr-Sep)'};
seasonIdx = {winterIdx, summerIdx};

barData = NaN(2, nModels); % [seasons x models]
for m = 1:nModels
    for s = 1:2
        idx = seasonIdx{s};
        if any(idx)
            barData(s, m) = sqrt(mean(Models(m).divergence(idx).^2, 'omitnan'));
        end
    end
end

b = bar(barData);
for m = 1:nModels
    b(m).FaceColor = modelColors{m};
end
set(gca, 'XTickLabel', seasonLabels);
ylabel('RMSE (m)');
title('Seasonal Model Skill');
legend(modelNames, 'Location', 'best');
grid on;

% Print seasonal stats
fprintf('\nSeasonal RMSE:\n');
for m = 1:nModels
    fprintf('  %s: Winter=%.2fm, Summer=%.2fm\n', modelNames{m}, barData(1,m), barData(2,m));
end

% --- Panel 2: Error vs Antecedent Wave Energy (30-day) ---
subplot(2,3,2);
hold on;
for m = 1:nModels
    validIdx = ~isnan(antecedentEmean(:,1)) & ~isnan(Models(m).divergence);
    scatter(antecedentEmean(validIdx,1), Models(m).divergence(validIdx), 40, ...
        'MarkerFaceColor', modelColors{m}, 'MarkerEdgeColor', modelColors{m}, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', modelNames{m});
end
yline(0, 'k--', 'LineWidth', 1);
xlabel('Mean Wave Energy (30-day prior, m²)');
ylabel('Model Error (m)');
title('Error vs Antecedent Wave Energy');
legend('Location', 'best');
grid on;

% --- Panel 3: Error vs Days Since Storm ---
subplot(2,3,3);
hold on;
for m = 1:nModels
    validIdx = ~isnan(daysSinceStorm) & ~isnan(Models(m).divergence);
    scatter(daysSinceStorm(validIdx), Models(m).divergence(validIdx), 40, ...
        'MarkerFaceColor', modelColors{m}, 'MarkerEdgeColor', modelColors{m}, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', modelNames{m});
end
yline(0, 'k--', 'LineWidth', 1);
xlabel('Days Since Storm Event');
ylabel('Model Error (m)');
title(sprintf('Error vs Recovery Time (storm = E > %.2f m²)', stormThreshold));
legend('Location', 'best');
grid on;

% --- Panel 4: Error During Erosion vs Accretion Periods ---
subplot(2,3,4);
hold on;

% Classify periods by observed beach change
obsChange = [0; diff(observed)];
erosionIdx = obsChange < -1;   % Beach narrowed by >1m
accretionIdx = obsChange > 1;  % Beach widened by >1m
stableIdx = ~erosionIdx & ~accretionIdx;

conditionLabels = {'Erosion', 'Stable', 'Accretion'};
conditionIdx = {erosionIdx, stableIdx, accretionIdx};

barData2 = NaN(3, nModels);
for m = 1:nModels
    for c = 1:3
        idx = conditionIdx{c};
        if any(idx)
            barData2(c, m) = mean(Models(m).divergence(idx), 'omitnan');
        end
    end
end

b2 = bar(barData2);
for m = 1:nModels
    b2(m).FaceColor = modelColors{m};
end
set(gca, 'XTickLabel', conditionLabels);
ylabel('Mean Error (m)');
title('Error by Beach Change Type');
legend(modelNames, 'Location', 'best');
grid on;
yline(0, 'k--', 'LineWidth', 1);

fprintf('\nError by beach change type (mean bias):\n');
for m = 1:nModels
    fprintf('  %s: Erosion=%.2fm, Stable=%.2fm, Accretion=%.2fm\n', ...
        modelNames{m}, barData2(1,m), barData2(2,m), barData2(3,m));
end

% --- Panel 5: Error Autocorrelation ---
subplot(2,3,5);
hold on;
maxLag = min(15, floor(nSurveys/3));
for m = 1:nModels
    err = Models(m).divergence;
    validErr = err(~isnan(err));
    if length(validErr) > maxLag + 2
        [acf, lags] = xcorr(validErr - mean(validErr), maxLag, 'coeff');
        % Plot only positive lags
        posLagIdx = lags >= 0;
        plot(lags(posLagIdx), acf(posLagIdx), 'o-', 'Color', modelColors{m}, ...
            'LineWidth', 1.5, 'MarkerFaceColor', modelColors{m}, ...
            'DisplayName', modelNames{m});
    end
end
yline(0, 'k-', 'LineWidth', 1);
% Add 95% confidence bounds
if nSurveys > 10
    confBound = 1.96 / sqrt(nSurveys);
    yline(confBound, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    yline(-confBound, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
end
xlabel('Lag (surveys)');
ylabel('Autocorrelation');
title('Error Autocorrelation (drift detection)');
legend('Location', 'best');
grid on;

% --- Panel 6: Binned Error by Wave Energy Quantile ---
subplot(2,3,6);
hold on;

% Bin surveys by antecedent energy quantiles
nBins = 4;
Equantiles = quantile(antecedentEmean(:,1), linspace(0, 1, nBins+1));
binLabels = cell(1, nBins);
binRMSE = NaN(nBins, nModels);

for bin = 1:nBins
    binIdx = antecedentEmean(:,1) >= Equantiles(bin) & ...
             antecedentEmean(:,1) < Equantiles(bin+1);
    binLabels{bin} = sprintf('Q%d', bin);
    
    for m = 1:nModels
        validIdx = binIdx & ~isnan(Models(m).divergence);
        if any(validIdx)
            binRMSE(bin, m) = sqrt(mean(Models(m).divergence(validIdx).^2));
        end
    end
end

b3 = bar(binRMSE);
for m = 1:nModels
    b3(m).FaceColor = modelColors{m};
end
set(gca, 'XTickLabel', binLabels);
xlabel('Antecedent Energy Quartile (Q1=calm, Q4=energetic)');
ylabel('RMSE (m)');
title('Model Skill by Wave Climate');
legend(modelNames, 'Location', 'best');
grid on;

sgtitle(sprintf('Error Diagnostics: MOPs %d-%d (%d-%d)', ...
    MopRange(1), MopRange(2), StartYear, EndYear), 'FontSize', 14, 'FontWeight', 'bold');

%% ===== FIGURE 5: Time-Lagged Error Analysis =====

figure('Position', [250 150 1200 500], 'Color', 'w');

% --- Panel 1: Error vs cumulative wave energy since last survey ---
subplot(1,3,1);
hold on;

% Calculate cumulative E between consecutive surveys
cumEbetween = NaN(nSurveys, 1);
for ns = 2:nSurveys
    t1 = datetime(uniqueDates(ns-1), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    t2 = datetime(uniqueDates(ns), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    idx = find(wavetime >= t1 & wavetime <= t2);
    if ~isempty(idx)
        cumEbetween(ns) = sum(E(idx));
    end
end

for m = 1:nModels
    validIdx = ~isnan(cumEbetween) & ~isnan(Models(m).divergence);
    scatter(cumEbetween(validIdx), Models(m).divergence(validIdx), 40, ...
        'MarkerFaceColor', modelColors{m}, 'MarkerEdgeColor', modelColors{m}, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', modelNames{m});
end
yline(0, 'k--', 'LineWidth', 1);
xlabel('Cumulative Wave Energy Between Surveys (m²·hr)');
ylabel('Model Error (m)');
title('Error vs Inter-Survey Wave Exposure');
legend('Location', 'best');
grid on;

% --- Panel 2: Predicted vs Observed CHANGE (not absolute position) ---
subplot(1,3,2);
hold on;

obsChange = [NaN; diff(observed)];
for m = 1:nModels
    predChange = [NaN; diff(Models(m).modelWidth)];
    validIdx = ~isnan(obsChange) & ~isnan(predChange);
    
    scatter(obsChange(validIdx), predChange(validIdx), 40, ...
        'MarkerFaceColor', modelColors{m}, 'MarkerEdgeColor', modelColors{m}, ...
        'MarkerFaceAlpha', 0.5, 'DisplayName', modelNames{m});
    
    % Compute skill for changes
    changeRMSE = sqrt(mean((obsChange(validIdx) - predChange(validIdx)).^2));
    fprintf('%s change prediction RMSE: %.2f m\n', modelNames{m}, changeRMSE);
end

% 1:1 line
allPredChange = [];
for m = 1:nModels
    allPredChange = [allPredChange; diff(Models(m).modelWidth)];
end
axLim = max(abs([obsChange; allPredChange])) * 1.1;
plot([-axLim axLim], [-axLim axLim], 'k-', 'LineWidth', 2);
xlabel('Observed Beach Width Change (m)');
ylabel('Predicted Beach Width Change (m)');
title('Change Prediction Skill');
legend('Location', 'best');
axis equal;
xlim([-axLim axLim]);
ylim([-axLim axLim]);
grid on;

% --- Panel 3: Erosion vs Accretion Event Skill ---
subplot(1,3,3);
hold on;

% Separate erosion and accretion events
erosionEvents = obsChange < -2;  % Significant erosion
accretionEvents = obsChange > 2; % Significant accretion

eventLabels = {'Erosion Events', 'Accretion Events'};
eventSkill = NaN(2, nModels); % [event type x model]

for m = 1:nModels
    predChange = [NaN; diff(Models(m).modelWidth)];
    
    % Erosion skill
    eIdx = erosionEvents & ~isnan(predChange);
    if any(eIdx)
        eventSkill(1, m) = sqrt(mean((obsChange(eIdx) - predChange(eIdx)).^2));
    end
    
    % Accretion skill
    aIdx = accretionEvents & ~isnan(predChange);
    if any(aIdx)
        eventSkill(2, m) = sqrt(mean((obsChange(aIdx) - predChange(aIdx)).^2));
    end
end

b4 = bar(eventSkill);
for m = 1:nModels
    b4(m).FaceColor = modelColors{m};
end
set(gca, 'XTickLabel', eventLabels);
ylabel('RMSE of Change Prediction (m)');
title('Skill for Erosion vs Accretion Events');
legend(modelNames, 'Location', 'best');
grid on;

fprintf('\nEvent-specific change prediction RMSE:\n');
for m = 1:nModels
    fprintf('  %s: Erosion=%.2fm, Accretion=%.2fm\n', ...
        modelNames{m}, eventSkill(1,m), eventSkill(2,m));
end

% Key diagnostic: ratio of accretion to erosion skill
fprintf('\nAccretion/Erosion skill ratio (>1 means worse at accretion):\n');
for m = 1:nModels
    ratio = eventSkill(2,m) / eventSkill(1,m);
    fprintf('  %s: %.2f\n', modelNames{m}, ratio);
end

sgtitle('Change Prediction Diagnostics', 'FontSize', 14, 'FontWeight', 'bold');

%% ===== Store diagnostic results =====
Diagnostics.antecedentEmean = antecedentEmean;
Diagnostics.antecedentEmax = antecedentEmax;
Diagnostics.daysSinceStorm = daysSinceStorm;
Diagnostics.stormThreshold = stormThreshold;
Diagnostics.lookbackDays = lookbackDays;
Diagnostics.seasonalRMSE = barData;
Diagnostics.conditionBias = barData2;
Diagnostics.energyQuartileRMSE = binRMSE;
Diagnostics.eventSkill = eventSkill;

%% ===== FIGURE 6: B.4 - SLOPE TRACKING ANALYSIS =====

fprintf('\n===== B.4: SLOPE TRACKING ANALYSIS =====\n');

figure('Position', [300 100 1200 500], 'Color', 'w');

% --- Panel 1: Observed vs Modeled Slope Time Series ---
subplot(1,3,1);
hold on;

plot(survDT, spatialMeanSlope, 'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k', ...
    'LineWidth', 1.5, 'DisplayName', 'Observed');

% Plot SlopeModel's tracked slope (model 4)
if nModels >= 4
    plot(survDT, Models(4).modelSlope, '-', 'Color', modelColors{4}, ...
        'LineWidth', 2, 'DisplayName', 'SlopeModel Tracked');
end

yline(meanSlope, 'k--', 'LineWidth', 1, 'DisplayName', sprintf('Mean (%.3f)', meanSlope));
xlabel('Time');
ylabel('Beach Face Slope');
title('Beach Slope Evolution');
legend('Location', 'best');
grid on;

% --- Panel 2: Slope vs Beach Width Phase Space ---
subplot(1,3,2);
hold on;

% Observed trajectory
validSlope = ~isnan(spatialMeanSlope);
scatter(spatialMeanWidth(validSlope), spatialMeanSlope(validSlope), 30, ...
    datenum(survDT(validSlope)), 'filled', 'DisplayName', 'Observed');
colormap(gca, parula);
cb = colorbar;
cb.Label.String = 'Date';
datetick(cb, 'y', 'yyyy');

% Plot SlopeModel trajectory
if nModels >= 4
    validSlopeM = ~isnan(Models(4).modelSlope);
    plot(Models(4).modelWidth(validSlopeM), Models(4).modelSlope(validSlopeM), ...
        '-', 'Color', modelColors{4}, 'LineWidth', 1.5, 'DisplayName', 'SlopeModel');
end

xlabel(sprintf('%s Beach Width (m)', ShorelineElev));
ylabel('Beach Face Slope');
title('Slope-Width Phase Space');
legend('Location', 'best');
grid on;

% --- Panel 3: Slope-Width Correlation ---
subplot(1,3,3);
hold on;

validBoth = ~isnan(spatialMeanSlope) & ~isnan(spatialMeanWidth);
scatter(spatialMeanWidth(validBoth), spatialMeanSlope(validBoth), 50, 'k', 'filled');

% Fit line
if sum(validBoth) > 3
    p = polyfit(spatialMeanWidth(validBoth), spatialMeanSlope(validBoth), 1);
    xfit = linspace(min(spatialMeanWidth(validBoth)), max(spatialMeanWidth(validBoth)), 50);
    plot(xfit, polyval(p, xfit), 'r-', 'LineWidth', 2);
    
    % Calculate correlation
    R = corrcoef(spatialMeanWidth(validBoth), spatialMeanSlope(validBoth));
    text(0.05, 0.95, sprintf('r = %.3f\nSlope = %.5f/m', R(1,2), p(1)), ...
        'Units', 'normalized', 'FontSize', 10, 'VerticalAlignment', 'top');
end

xlabel(sprintf('%s Beach Width (m)', ShorelineElev));
ylabel('Beach Face Slope');
title('Observed Slope-Width Relationship');
grid on;

sgtitle('B.4: Profile Shape (Slope) Tracking', 'FontSize', 14, 'FontWeight', 'bold');

%% ===== FIGURE 7: B.5 - MULTI-CONTOUR ANALYSIS =====

if MultiContour.enabled
    fprintf('\n===== B.5: MULTI-CONTOUR ANALYSIS =====\n');
    
    % Load widths for multiple contour elevations
    nContours = length(MultiContour.elevations);
    MultiContourWidths = cell(nContours, 1);
    MultiContourDates = cell(nContours, 1);
    
    fprintf('Loading multi-contour data from SM files...\n');
    
    for c = 1:nContours
        Zc = MultiContour.elevations(c);
        cDates = [];
        cWidths = [];
        
        for m = MopRange(1):MopRange(2)
            smfile = [mpath 'M' num2str(m,'%5.5i') 'SM.mat'];
            
            if exist(smfile, 'file')
                load(smfile, 'SM');
                
                for n = 1:length(SM)
                    X1D = SM(n).X1D;
                    Z1D = SM(n).Z1Dmean;
                    
                    if ~isempty(X1D) && ~isempty(Z1D) && any(~isnan(Z1D))
                        xWidth = intersections([-50 200], [Zc Zc], X1D, Z1D);
                        
                        if ~isempty(xWidth)
                            cDates = [cDates; SM(n).Datenum];
                            cWidths = [cWidths; min(xWidth)];
                        end
                    end
                end
            end
        end
        
        % Filter by time range and aggregate
        timeIdx = cDates >= datenum(StartYear,1,1) & cDates <= datenum(EndYear,12,31);
        cDates = cDates(timeIdx);
        cWidths = cWidths(timeIdx);
        
        % Calculate spatial mean for unique dates
        [uDates, ~, dGroup] = unique(cDates);
        uWidths = accumarray(dGroup, cWidths, [], @(x) mean(x,'omitnan'));
        
        validIdx = ~isnan(uWidths);
        MultiContourDates{c} = uDates(validIdx);
        MultiContourWidths{c} = uWidths(validIdx);
        
        fprintf('  %s (%.3fm): %d observations\n', MultiContour.labels{c}, Zc, length(MultiContourWidths{c}));
    end
    
    % Run Ludka model for each contour and compare
    figure('Position', [350 100 1400 600], 'Color', 'w');
    
    contourColors = {[0.2 0.6 1], [0.1 0.5 0.1], [0.8 0.2 0.2]}; % Blue, Green, Red
    
    % --- Panel 1: Multi-contour time series ---
    subplot(2,2,1);
    hold on;
    
    for c = 1:nContours
        dt = datetime(MultiContourDates{c}, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
        plot(dt, MultiContourWidths{c}, 'o-', 'Color', contourColors{c}, ...
            'MarkerSize', 3, 'MarkerFaceColor', contourColors{c}, ...
            'DisplayName', sprintf('%s (%.2fm)', MultiContour.labels{c}, MultiContour.elevations(c)));
    end
    
    xlabel('Time');
    ylabel('Beach Width (m)');
    title('Multi-Contour Beach Width Time Series');
    legend('Location', 'best');
    grid on;
    
    % --- Panel 2: Contour width correlations ---
    subplot(2,2,2);
    hold on;
    
    % Find common dates for all contours
    commonDates = MultiContourDates{1};
    for c = 2:nContours
        commonDates = intersect(commonDates, MultiContourDates{c});
    end
    
    if length(commonDates) > 5
        % Get widths at common dates
        commonWidths = NaN(length(commonDates), nContours);
        for c = 1:nContours
            [~, ia, ib] = intersect(commonDates, MultiContourDates{c});
            commonWidths(ia, c) = MultiContourWidths{c}(ib);
        end
        
        % Plot MSL vs MHW
        scatter(commonWidths(:,1), commonWidths(:,2), 40, 'b', 'filled', 'DisplayName', 'MSL vs MHW');
        
        % Correlation
        R = corrcoef(commonWidths(:,1), commonWidths(:,2), 'Rows', 'complete');
        
        % Add 1:1 line
        axLim = [min(commonWidths(:)) max(commonWidths(:))];
        plot(axLim, axLim, 'k--', 'LineWidth', 1.5, 'DisplayName', '1:1 Line');
        
        text(0.05, 0.95, sprintf('r = %.3f', R(1,2)), 'Units', 'normalized', ...
            'FontSize', 11, 'VerticalAlignment', 'top');
    end
    
    xlabel('MSL Width (m)');
    ylabel('MHW Width (m)');
    title('MSL vs MHW Width Correlation');
    axis equal;
    grid on;
    legend('Location', 'best');
    
    % --- Panel 3: Model skill by contour elevation ---
    subplot(2,2,3);
    hold on;
    
    % Run Ludka model for each contour
    contourSkill = NaN(nContours, 1);
    
    for c = 1:nContours
        dates_c = MultiContourDates{c};
        widths_c = MultiContourWidths{c};
        meanS_c = mean(widths_c, 'omitnan');
        
        if length(dates_c) < 3
            continue;
        end
        
        % Run model
        modelWidth_c = NaN(length(dates_c), 1);
        modelWidth_c(1) = widths_c(1);
        
        for ns = 2:length(dates_c)
            t1 = datetime(dates_c(ns-1), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
            t2 = datetime(dates_c(ns), 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
            waveIdx = find(wavetime >= t1 & wavetime <= t2);
            
            if isempty(waveIdx)
                modelWidth_c(ns) = modelWidth_c(ns-1);
                continue;
            end
            
            S = modelWidth_c(ns-1) - meanS_c;
            for i = 1:length(waveIdx)
                wi = waveIdx(i);
                Eeq = Ludka.a * S + Ludka.b;
                deltaE = E(wi) - Eeq;
                if deltaE > 0
                    dSdt = Ludka.Cminus * sqrt(E(wi)) * deltaE;
                else
                    dSdt = Ludka.Cplus * sqrt(E(wi)) * deltaE;
                end
                S = S + dSdt;
            end
            modelWidth_c(ns) = S + meanS_c;
        end
        
        % Calculate RMSE
        validIdx = ~isnan(widths_c) & ~isnan(modelWidth_c);
        if any(validIdx)
            contourSkill(c) = sqrt(mean((widths_c(validIdx) - modelWidth_c(validIdx)).^2));
        end
        
        fprintf('  %s RMSE: %.2f m\n', MultiContour.labels{c}, contourSkill(c));
    end
    
    bar(contourSkill);
    set(gca, 'XTickLabel', MultiContour.labels);
    ylabel('RMSE (m)');
    title('Ludka Model Skill by Contour Elevation');
    grid on;
    
    % --- Panel 4: Beach width range (MHW-MSL) time series ---
    subplot(2,2,4);
    hold on;
    
    if length(commonDates) > 5
        beachfaceWidth = commonWidths(:,2) - commonWidths(:,1);  % MHW - MSL
        dt = datetime(commonDates, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
        
        plot(dt, beachfaceWidth, 'ko-', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
        yline(mean(beachfaceWidth, 'omitnan'), 'r--', 'LineWidth', 2);
        
        xlabel('Time');
        ylabel('Beach Face Width (MHW - MSL) (m)');
        title('Beach Face Width Evolution');
        grid on;
    end
    
    sgtitle('B.5: Multi-Contour Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Store multi-contour results
    Diagnostics.MultiContour.elevations = MultiContour.elevations;
    Diagnostics.MultiContour.labels = MultiContour.labels;
    Diagnostics.MultiContour.dates = MultiContourDates;
    Diagnostics.MultiContour.widths = MultiContourWidths;
    Diagnostics.MultiContour.skill = contourSkill;
end

%% ===== SAVE RESULTS =====

% Create output structure with all models
Results.MopRange = MopRange;
Results.ShorelineElev = ShorelineElev;
Results.StartYear = StartYear;
Results.EndYear = EndYear;
Results.MeanShoreline = meanS;
Results.MeanSlope = meanSlope;
Results.SurveyDates = uniqueDates;
Results.SurveyDatetimes = survDT;
Results.ObservedWidth = observed;
Results.ObservedSlope = spatialMeanSlope;
Results.WaveTime = wavetime;
Results.WaveEnergy = E;

% Store all model results
Results.Yates.params = Yates;
Results.Yates.PredictedWidth = Models(1).modelWidth;
Results.Yates.Divergence = Models(1).divergence;
Results.Yates.AccumDivergence = Models(1).accumDivergence;
Results.Yates.RMSE = Models(1).RMSE;
Results.Yates.MAE = Models(1).MAE;
Results.Yates.Bias = Models(1).bias;
Results.Yates.R2 = Models(1).R2;

Results.Ludka.params = Ludka;
Results.Ludka.PredictedWidth = Models(2).modelWidth;
Results.Ludka.Divergence = Models(2).divergence;
Results.Ludka.AccumDivergence = Models(2).accumDivergence;
Results.Ludka.RMSE = Models(2).RMSE;
Results.Ludka.MAE = Models(2).MAE;
Results.Ludka.Bias = Models(2).bias;
Results.Ludka.R2 = Models(2).R2;

Results.Asymmetric.params = Asymmetric;
Results.Asymmetric.PredictedWidth = Models(3).modelWidth;
Results.Asymmetric.Divergence = Models(3).divergence;
Results.Asymmetric.AccumDivergence = Models(3).accumDivergence;
Results.Asymmetric.RMSE = Models(3).RMSE;
Results.Asymmetric.MAE = Models(3).MAE;
Results.Asymmetric.Bias = Models(3).bias;
Results.Asymmetric.R2 = Models(3).R2;

Results.SlopeModel.params = SlopeModel;
Results.SlopeModel.PredictedWidth = Models(4).modelWidth;
Results.SlopeModel.PredictedSlope = Models(4).modelSlope;
Results.SlopeModel.Divergence = Models(4).divergence;
Results.SlopeModel.AccumDivergence = Models(4).accumDivergence;
Results.SlopeModel.RMSE = Models(4).RMSE;
Results.SlopeModel.MAE = Models(4).MAE;
Results.SlopeModel.Bias = Models(4).bias;
Results.SlopeModel.R2 = Models(4).R2;

% Also store the full Models struct
Results.Models = Models;

% Store diagnostics
Results.Diagnostics = Diagnostics;

% Save to file
outfile = sprintf('EquilibriumModelComparison_MOP%d-%d_%d-%d.mat', ...
    MopRange(1), MopRange(2), StartYear, EndYear);
save(outfile, 'Results');
fprintf('\nResults saved to %s\n', outfile);

fprintf('\n===== ANALYSIS COMPLETE =====\n');
fprintf('Model RMSE comparison:\n');
for m = 1:nModels
    fprintf('  %s: %.2f m\n', Models(m).name, Models(m).RMSE);
end
[~, bestIdx] = min([Models.RMSE]);
fprintf('Best model: %s\n', Models(bestIdx).name);
