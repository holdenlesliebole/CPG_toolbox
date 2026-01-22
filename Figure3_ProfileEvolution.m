%% FIGURE 3: Cross-Shore Profile Evolution (Key Survey Dates)
% Visualizes alongshore-averaged profile morphology changes across depth zones
% Adapted from TorreyRecoveryEvolutionMeanProfiles.m

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox

%% USER SETTINGS
MopStart = 580;
MopEnd = 589;
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

% Key survey dates for profile evolution
SurveyDates = [datenum(2022, 10, 1);    % Pre-storm baseline (Oct 2022)
               datenum(2023, 1, 15);    % Post-storm recovery (Jan 2023)
               datenum(2023, 7, 1);     % Summer (Jul 2023)
               datenum(2023, 10, 1)];   % Fall (Oct 2023)

% Cross-shore interpolation
NumSubTrans = 300;  % Number of interpolation points
XCross_max = 200;   % Maximum cross-shore distance (m)

%% CREATE FIGURE
fig = figure('position', [100 100 1400 1000]);
set(fig, 'InvertHardcopy', 'off');

% Color scheme
col_surveys = [0.2 0.2 0.8; ...   % Blue - Oct 2022
               0.9 0.3 0.3; ...   % Red - Jan 2023
               0.2 0.7 0.2; ...   % Green - Jul 2023
               0.8 0.4 0.1];      % Orange - Oct 2023

%% PANEL A: ABSOLUTE ELEVATIONS AT KEY DATES
ax1 = subplot(2, 2, 1);
hold on; box on; grid on;

for n = 1:length(SurveyDates)
    % Initialize arrays for this survey
    X_all = [];
    Z_all = [];
    
    % Loop through MOPs and concatenate profiles
    for m = MopStart:MopEnd
        matfile = ['M' sprintf('%5.5d', m) 'SM.mat'];
        
        try
            load(matfile, 'SM');
            
            % Find nearest survey to target date (within ±3 days)
            [dmin, idx] = min(abs([SM.Datenum] - SurveyDates(n)));
            if dmin <= 3 && ~isnan(SM(idx).Z1Dmean(1))
                X_all = [X_all; SM(idx).X1D'];
                Z_all = [Z_all; SM(idx).Z1Dmean'];
            end
        catch
            % File or survey not found - skip
        end
    end
    
    % Remove NaN and duplicate points
    valid_idx = ~isnan(Z_all);
    if sum(valid_idx) > 10
        X_all = X_all(valid_idx);
        Z_all = Z_all(valid_idx);
        
        % Interpolate to common grid
        X_interp = linspace(0, min(max(X_all), XCross_max), NumSubTrans);
        Z_interp = interp1(X_all, Z_all, X_interp, 'linear', NaN);
        
        % Remove short distances & smooth
        valid_x = X_interp >= 0;
        X_clean = X_interp(valid_x);
        Z_clean = movmean(Z_interp(valid_x), 5, 'omitnan');
        
        % Plot
        p(n) = plot(X_clean, Z_clean, '-', 'linewidth', 2.5, 'color', col_surveys(n, :), ...
            'DisplayName', datestr(SurveyDates(n), 'mmm dd, yyyy'));
    end
end

% Add datum reference lines
datum_levels = [1.566, 0.774, -0.058];  % MHHW, MSL, MLLW
datum_labels = {'MHHW', 'MSL', 'MLLW'};
for i = 1:length(datum_levels)
    p=plot(xlim, [datum_levels(i), datum_levels(i)], 'k--', 'linewidth', 1);
    text(XCross_max*0.95, datum_levels(i)+0.15, datum_labels{i}, ...
        'fontsize', 10, 'fontweight', 'bold', 'horizontalalignment', 'right');
end

set(ax1, 'fontsize', 13, 'linewidth', 1.5, 'xdir', 'reverse');
xlabel('Cross-Shore Distance (m)', 'fontsize', 13, 'fontweight', 'bold');
ylabel('Elevation (m, NAVD88)', 'fontsize', 13, 'fontweight', 'bold');
title('(a) Profile Evolution: Absolute Elevations', 'fontsize', 14, 'fontweight', 'bold');
legend(p, 'location', 'northwest', 'fontsize', 11);
set(ax1, 'xlim', [0, XCross_max], 'ylim', [-10, 3]);

%% PANEL B: ELEVATION CHANGE FROM BASELINE (OCT 2022)
ax2 = subplot(2, 2, 2);
hold on; box on; grid on;

% Get baseline profile (first survey)
X_baseline = [];
Z_baseline = [];
for m = MopStart:MopEnd
    matfile = ['M' sprintf('%5.5d', m) 'SM.mat'];
    try
        load(matfile, 'SM');
        [dmin, idx] = min(abs([SM.Datenum] - SurveyDates(1)));
        if dmin <= 3
            X_baseline = [X_baseline; SM(idx).X1D'];
            Z_baseline = [Z_baseline; SM(idx).Z1Dmean'];
        end
    catch
    end
end
valid_idx = ~isnan(Z_baseline);
X_baseline = X_baseline(valid_idx);
Z_baseline = Z_baseline(valid_idx);

% Interpolate baseline
X_interp = linspace(0, min(max(X_baseline), XCross_max), NumSubTrans);
Z_baseline_interp = interp1(X_baseline, Z_baseline, X_interp, 'linear', NaN);

% Now calculate changes for each subsequent survey
for n = 2:length(SurveyDates)
    X_all = [];
    Z_all = [];
    for m = MopStart:MopEnd
        matfile = ['M' sprintf('%5.5d', m) 'SM.mat'];
        try
            load(matfile, 'SM');
            [dmin, idx] = min(abs([SM.Datenum] - SurveyDates(n)));
            if dmin <= 3
                X_all = [X_all; SM(idx).X1D'];
                Z_all = [Z_all; SM(idx).Z1Dmean'];
            end
        catch
        end
    end
    
    valid_idx = ~isnan(Z_all);
    if sum(valid_idx) > 10
        X_all = X_all(valid_idx);
        Z_all = Z_all(valid_idx);
        Z_interp = interp1(X_all, Z_all, X_interp, 'linear', NaN);
        
        % Calculate elevation change
        dZ = Z_interp - Z_baseline_interp;
        valid_x = X_interp >= 0;
        
        plot(X_interp(valid_x), dZ(valid_x), '-', 'linewidth', 2.5, ...
            'color', col_surveys(n, :), 'DisplayName', datestr(SurveyDates(n), 'mmm yyyy'));
    end
end

% Zero line
plot(xlim, [0, 0], 'k--', 'linewidth', 1.5);

set(ax2, 'fontsize', 13, 'linewidth', 1.5, 'xdir', 'reverse');
xlabel('Cross-Shore Distance (m)', 'fontsize', 13, 'fontweight', 'bold');
ylabel('Elevation Change $\Delta z$ (m)', 'fontsize', 13, 'fontweight', 'bold');
title('(b) Elevation Change from Oct 2022 Baseline', 'fontsize', 14, 'fontweight', 'bold');
set(ax2, 'xlim', [0, XCross_max], 'ylim', [-2, 2]);
grid on; legend('location', 'northwest', 'fontsize', 11);

%% PANEL C: SUBAERIAL (Z > MSL) ONLY
ax3 = subplot(2, 2, 3);
hold on; box on; grid on;

MSL = 0.774;  % NAVD88
for n = 1:length(SurveyDates)
    X_all = [];
    Z_all = [];
    for m = MopStart:MopEnd
        matfile = ['M' sprintf('%5.5d', m) 'SM.mat'];
        try
            load(matfile, 'SM');
            [dmin, idx] = min(abs([SM.Datenum] - SurveyDates(n)));
            if dmin <= 3
                z_data = SM(idx).Z1Dmean;
                x_data = SM(idx).X1D;
                % Only subaerial
                subaerial_idx = z_data >= MSL;
                if sum(subaerial_idx) > 5
                    X_all = [X_all; x_data(subaerial_idx)'];
                    Z_all = [Z_all; z_data(subaerial_idx)'];
                end
            end
        catch
        end
    end
    
    if ~isempty(X_all)
        valid_idx = ~isnan(Z_all);
        X_all = X_all(valid_idx);
        Z_all = Z_all(valid_idx);
        
        X_interp_s = linspace(max(0, min(X_all)), min(50, max(X_all)), 100);
        Z_interp_s = interp1(X_all, Z_all, X_interp_s, 'linear', NaN);
        
        p3(n) = plot(X_interp_s, Z_interp_s, '-', 'linewidth', 2.5, ...
            'color', col_surveys(n, :), 'DisplayName', datestr(SurveyDates(n), 'mmm yyyy'));
    end
end

plot(xlim, [MSL, MSL], 'k--', 'linewidth', 1.5);
text(45, MSL + 0.2, 'MSL', 'fontsize', 10, 'fontweight', 'bold');

set(ax3, 'fontsize', 13, 'linewidth', 1.5, 'xdir', 'reverse');
xlabel('Cross-Shore Distance (m)', 'fontsize', 13, 'fontweight', 'bold');
ylabel('Elevation (m, NAVD88)', 'fontsize', 13, 'fontweight', 'bold');
title('(c) Subaerial Profile Evolution (Z > MSL)', 'fontsize', 14, 'fontweight', 'bold');
set(ax3, 'xlim', [0, 50], 'ylim', [0.5, 4]);
legend(p3(1:length(SurveyDates)), 'location', 'northwest', 'fontsize', 11);

%% PANEL D: SUBAQUEOUS PROFILE DETAIL
ax4 = subplot(2, 2, 4);
hold on; box on; grid on;

for n = 1:length(SurveyDates)
    X_all = [];
    Z_all = [];
    for m = MopStart:MopEnd
        matfile = ['M' sprintf('%5.5d', m) 'SM.mat'];
        try
            load(matfile, 'SM');
            [dmin, idx] = min(abs([SM.Datenum] - SurveyDates(n)));
            if dmin <= 3
                z_data = SM(idx).Z1Dmean;
                x_data = SM(idx).X1D;
                % Only subaqueous
                subaqueous_idx = z_data < MSL & z_data >= -10;
                if sum(subaqueous_idx) > 5
                    X_all = [X_all; x_data(subaqueous_idx)'];
                    Z_all = [Z_all; z_data(subaqueous_idx)'];
                end
            end
        catch
        end
    end
    
    if ~isempty(X_all)
        valid_idx = ~isnan(Z_all);
        X_all = X_all(valid_idx);
        Z_all = Z_all(valid_idx);
        
        X_interp_aq = linspace(min(X_all), min(max(X_all), 150), 150);
        Z_interp_aq = interp1(X_all, Z_all, X_interp_aq, 'linear', NaN);
        
        p4(n) = plot(X_interp_aq, Z_interp_aq, '-', 'linewidth', 2.5, ...
            'color', col_surveys(n, :), 'DisplayName', datestr(SurveyDates(n), 'mmm yyyy'));
    end
end

% Add depth zone markers
plot(xlim, [0.774, 0.774], 'k--', 'linewidth', 1);
plot(xlim, [-4, -4], 'k--', 'linewidth', 1);
text(145, 0.9, 'MSL', 'fontsize', 9);
text(145, -3.8, '4m Pivot Depth', 'fontsize', 9, 'fontweight', 'bold', 'color', 'red');

set(ax4, 'fontsize', 13, 'linewidth', 1.5, 'xdir', 'reverse');
xlabel('Cross-Shore Distance (m)', 'fontsize', 13, 'fontweight', 'bold');
ylabel('Elevation (m, NAVD88)', 'fontsize', 13, 'fontweight', 'bold');
title('(d) Subaqueous Profile Evolution', 'fontsize', 14, 'fontweight', 'bold');
set(ax4, 'xlim', [0, 150], 'ylim', [-10, 1]);
legend(p4(1:length(SurveyDates)), 'location', 'southwest', 'fontsize', 11);

%% OVERALL TITLE
sgtitle(sprintf('Figure 3: Cross-Shore Profile Evolution (MOPs %d–%d)', MopStart, MopEnd), ...
    'fontsize', 18, 'fontweight', 'bold');

%% SAVE
set(gcf, 'position', [100 100 1400 1000]);
print(gcf, fullfile(OutputDir, 'Figure_3_ProfileEvolution.png'), '-dpng', '-r300');
fprintf('Saved Figure 3: %s\n', fullfile(OutputDir, 'Figure_3_ProfileEvolution.png'));
fprintf('\n=== FIGURE 3: PROFILE EVOLUTION SUMMARY ===\n');
fprintf('✓ 4-date survey comparison\n');
fprintf('✓ Absolute elevations, changes, and depth zones\n');
fprintf('✓ 4m pivot depth marked\n');
