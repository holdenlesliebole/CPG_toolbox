%% FIGURE 4: Waves, Volumes, and Beach Width Time Series
% 5 stacked panels showing wave forcing & morphological response
% Real data from SM files and CDIP waves
% Adapted from ExamplePlotReachJetskiVolumeEvolution.m patterns

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox

%% USER SETTINGS
mpath = '/volumes/group/MOPS/';  % Path to MOPS data
MopStart = 576;
MopEnd = 589;
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

% Date range for detailed analysis
DateStart = datetime(2023,4,1);%datetime(2022, 10, 1);
DateEnd = datetime(2023,8,31); %datetime(2023, 10, 31);

% Wave data settings
MopNumber = 582;  % Representative MOP for waves
MopName = sprintf('D%04d', MopNumber);

% Alongshore reach length (normalized)
L = 100 * (MopEnd - MopStart + 1);  % m

% Control volume elevation bounds
% Set to [] for default (use survey extents) or specify a minimum elevation (m, NAVD88)
% Example: zmin_control = -10;  % Only analyze down to -10m
zmin_control = [];  % Leave blank to use full survey extent

%% LOAD SURVEY DATA
fprintf('Loading survey data for MOPs %d-%d...\n', MopStart, MopEnd);
SG = CombineSGdata(mpath, MopStart, MopEnd);

% Identify jetski surveys
jumbo = find(contains({SG.File}, 'umbo') | contains({SG.File}, 'etski'));
jetski = [];
for j = 1:length(jumbo)
    if min(SG(jumbo(j)).Z) < -3
        jetski = [jetski, jumbo(j)];
    end
end

% Filter to date range
DateStart_num = datenum(DateStart);
DateEnd_num = datenum(DateEnd);
idx = find([SG(jetski).Datenum] >= DateStart_num & [SG(jetski).Datenum] <= DateEnd_num);
jetski = jetski(idx);
SurveyDates = datetime([SG(jetski).Datenum], 'ConvertFrom', 'datenum');
fprintf('Found %d jetski surveys in date range\n', length(jetski));
if ~isempty(SurveyDates)
    fprintf('Survey date range: %s to %s\n', datestr(min(SurveyDates)), datestr(max(SurveyDates)));
end

% MSL datum (NAVD88)
MSL = 0.774;

%% LOAD REAL WAVE DATA
fprintf('Loading wave data for %s (%s to %s)...\n', MopName, ...
    datestr(DateStart, 'yyyy-mm-dd'), datestr(DateEnd, 'yyyy-mm-dd'));

try
    dt1 = DateStart;%datetime(DateStart, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    dt2 = DateEnd;%datetime(DateEnd, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    fprintf('Loading wave data for D%04d (%s to %s)...\n', MopNumber, datestr(DateStart), datestr(DateEnd));
    MOP = read_MOPline2(MopName, dt1, dt2);
    
    % Keep datetime format for plotting
    if isdatetime(MOP.time)
        TimeUTC_dt = MOP.time(:);
    else
        TimeUTC_dt = datetime(MOP.time(:), 'ConvertFrom', 'datenum');
    end
    TimeUTC = datenum(TimeUTC_dt);  % Also keep datenum for compatibility
    
    wavehs = MOP.Hs(:);
    eflux_total = MOP.EfluxXtotal(:);  % Cross-shore energy flux
    
    fprintf('Successfully loaded %d wave data points\n', length(wavehs));
    fprintf('Wave data range: %s to %s\n', datestr(min(TimeUTC)), datestr(max(TimeUTC)));
catch ME
    error('Failed to load wave data: %s', ME.message);
end

%% CREATE 2D GRID FOR VOLUME CALCULATIONS
% Make base grid encompassing all gridded survey data
minx = min(vertcat(SG(jetski).X));
maxx = max(vertcat(SG(jetski).X));
miny = min(vertcat(SG(jetski).Y));
maxy = max(vertcat(SG(jetski).Y));

% 2D UTM grid
[X_grid, Y_grid] = meshgrid(minx:maxx, miny:maxy);
W = maxx - minx;  % Cross-shore width for normalization

% Create reference grid Z0 from first survey
SurvNum_ref = jetski(1);
x_ref = SG(SurvNum_ref).X;
y_ref = SG(SurvNum_ref).Y;
z_ref = SG(SurvNum_ref).Z;

% Map first survey to 2D grid
idx_ref = sub2ind(size(X_grid), y_ref - miny + 1, x_ref - minx + 1);
Z0 = X_grid * NaN;
Z0(idx_ref) = z_ref;

% Create elevation bins for reference grid
zRes = 0.5;
z0bin = round((Z0 - 0.774) / zRes);

fprintf('Grid size: %d x %d, Cross-shore width W = %.0f m\n', size(X_grid, 2), size(X_grid, 1), W);

%% GRID DIAGNOSTICS
fprintf('\n=== CONTROL VOLUME DIAGNOSTICS ===\n');
fprintf('Grid extent (UTM coordinates):\n');
fprintf('  X (cross-shore): %.1f to %.1f m (span: %.1f m)\n', minx, maxx, maxx - minx);
fprintf('  Y (alongshore): %.1f to %.1f m (span: %.1f m)\n', miny, maxy, maxy - miny);
fprintf('Alongshore reach length L (normalized): %.0f m\n', L);
fprintf('Reference survey (baseline Z0): %s\n', datestr(SG(jetski(1)).Datenum));
fprintf('Number of jetski surveys: %d\n', length(jetski));

% Check coverage for each survey
fprintf('\nSurvey coverage statistics:\n');
fprintf('Survey Date           | Data Points | Coverage %%\n');
fprintf('%-20s | %11d | %8.1f%%\n', datestr(SG(jetski(1)).Datenum), length(SG(jetski(1)).X), 100);
for n = 2:length(jetski)
    coverage_pct = (length(SG(jetski(n)).X) / length(SG(jetski(1)).X)) * 100;
    fprintf('%-20s | %11d | %8.1f%%\n', datestr(SG(jetski(n)).Datenum), length(SG(jetski(n)).X), coverage_pct);
end

fprintf('\nControl Volume Summary:\n');
fprintf('  Cross-shore extent (W): %.0f m\n', W);
fprintf('  Alongshore extent (normalized L): %.0f m\n', L);
fprintf('  Total area: %.0f m²\n', W * L);

% Determine and apply elevation bounds
zmin_survey = min(Z0(:), [], 'omitnan');
zmax_survey = max(Z0(:), [], 'omitnan');

if isempty(zmin_control)
    zmin_bound = zmin_survey;
    fprintf('  Elevation range (survey extent): %.2f to %.2f m (NAVD88)\n', zmin_bound, zmax_survey);
else
    zmin_bound = zmin_control;
    fprintf('  Elevation range (user-specified): %.2f to %.2f m (NAVD88)\n', zmin_bound, zmax_survey);
    fprintf('    (Note: Survey extends to %.2f m, bounding at %.2f m)\n', zmin_survey, zmin_control);
end

fprintf('=====================================\n\n');

%% COMPUTE VOLUMES FOR EACH SURVEY (relative to reference Z0)
fprintf('Computing volumes for %d surveys relative to baseline...\n', length(jetski));

Vol_total = [];
Vol_subaerial = [];
Vol_subaqueous = [];
Vol_shallow = [];
Vol_deep = [];
BeachWidth = [];

for n = 1:length(jetski)
    SurvNum = jetski(n);
    x_n = SG(SurvNum).X;
    y_n = SG(SurvNum).Y;
    z_n = SG(SurvNum).Z;
    
    % Map current survey to 2D grid
    idx_n = sub2ind(size(X_grid), y_n - miny + 1, x_n - minx + 1);
    Z_n = X_grid * NaN;
    Z_n(idx_n) = z_n;
    
    % Elevation difference relative to reference
    dZ = Z_n - Z0;
    
    % Calculate volumes by elevation bin
    vol_subaerial = 0;
    vol_shallow = 0;
    vol_deep = 0;
    
    % Compute elevation bin for the minimum control bound
    iz_min_bound = round((zmin_bound - 0.774) / zRes);
    
    for iz = min(z0bin(:)):max(z0bin(:))
        % Skip bins below the control volume minimum bound
        if iz < iz_min_bound
            continue;
        end
        
        bin_mask = (z0bin == iz);
        dz_bin = dZ(bin_mask);
        
        % Subaerial (z0 >= MSL)
        if iz >= round((0.774 - 0.774) / zRes)
            vol_subaerial = vol_subaerial + sum(dz_bin, 'omitnan');
        end
        
        % Shallow subaqueous (z0 -4 to MSL)
        if iz >= round((-4 - 0.774) / zRes) && iz < round((0.774 - 0.774) / zRes)
            vol_shallow = vol_shallow + sum(dz_bin, 'omitnan');
        end
        
        % Deep subaqueous (z0 < -4) but above the control volume bound
        if iz < round((-4 - 0.774) / zRes) && iz >= iz_min_bound
            vol_deep = vol_deep + sum(dz_bin, 'omitnan');
        end
    end
    
    Vol_subaerial(n) = vol_subaerial / L;
    Vol_shallow(n) = vol_shallow / L;
    Vol_deep(n) = vol_deep / L;
    Vol_subaqueous(n) = (vol_shallow + vol_deep) / L;
    Vol_total(n) = (vol_subaerial + vol_shallow + vol_deep) / L;
    
    % Beach width at MSL
    msl_mask = z_n >= 0.774;
    if sum(msl_mask) > 0
        x_msl = x_n(msl_mask);
        BeachWidth(n) = max(x_msl) - min(x_msl);
    else
        BeachWidth(n) = NaN;
    end
end

fprintf('Volume range: [%.2f, %.2f] m³/m\n', min(Vol_total), max(Vol_total));
fprintf('Beach width range: [%.1f, %.1f] m\n', nanmin(BeachWidth), nanmax(BeachWidth));

%% INTERPOLATE WAVE DATA TO SURVEY DATES (for better visualization)
% Remove duplicate times in wave data
% Ensure TimeUTC is numeric
if isdatetime(TimeUTC)
    TimeUTC = datenum(TimeUTC);
end
[TimeUTC_unique, idx_unique] = unique(TimeUTC, 'stable');
wavehs_unique = wavehs(idx_unique);
eflux_unique = eflux_total(idx_unique);

% Convert SurveyDates to numeric for interpolation
SurveyDates_num = datenum(SurveyDates);

% Interpolate to survey dates
Hs_interp = interp1(TimeUTC_unique, wavehs_unique, SurveyDates_num, 'linear', NaN);
Hs_mean_interval = [];
Hs_max_interval = [];
Eflux_mean_interval = [];
Eflux_max_interval = [];

for n = 1:length(jetski)-1
    t_start = datenum(SurveyDates(n));
    t_end = datenum(SurveyDates(n+1));
    idx_window = TimeUTC_unique >= t_start & TimeUTC_unique <= t_end;
    Hs_mean_interval(n) = nanmean(wavehs_unique(idx_window));
    Hs_max_interval(n) = nanmax(wavehs_unique(idx_window));
    Eflux_mean_interval(n) = nanmean(eflux_unique(idx_window));
    Eflux_max_interval(n) = nanmax(eflux_unique(idx_window));
end

%% DEEP ZONE TIMING ANALYSIS
fprintf('\n=== DEEP ZONE VOLUME DYNAMICS (z < -4m, bounded at %.1f m) ===\n', zmin_bound);
fprintf('Deep zone range: [%.2f, %.2f] m³/m\n', min(Vol_deep), max(Vol_deep));

% Calculate deep zone changes between surveys
DeepZone_change = diff(Vol_deep);
[max_accretion, idx_max_acc] = max(DeepZone_change);
[max_erosion, idx_max_ero] = min(DeepZone_change);

fprintf('\nMAXIMUM DEEP ZONE ACCRETION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_max_acc)), datestr(SurveyDates(idx_max_acc+1)), ...
    days(SurveyDates(idx_max_acc+1) - SurveyDates(idx_max_acc)));
fprintf('  Change: +%.2f m³/m\n', max_accretion);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_max_acc), Hs_max_interval(idx_max_acc));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_max_acc), Eflux_max_interval(idx_max_acc));

fprintf('\nMAXIMUM DEEP ZONE EROSION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_max_ero)), datestr(SurveyDates(idx_max_ero+1)), ...
    days(SurveyDates(idx_max_ero+1) - SurveyDates(idx_max_ero)));
fprintf('  Change: %.2f m³/m\n', max_erosion);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_max_ero), Hs_max_interval(idx_max_ero));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_max_ero), Eflux_max_interval(idx_max_ero));

% Identify periods with large deep zone changes
threshold_change = std(DeepZone_change);
large_change_idx = find(abs(DeepZone_change) > 1.5*threshold_change);
fprintf('\nLarge deep zone changes (>1.5 SD = ±%.2f m³/m):\n', 1.5*threshold_change);
for i = 1:min(5, length(large_change_idx))  % Top 5 events
    idx = large_change_idx(i);
    fprintf('  %s: %+.2f m³/m | Hs: %.2f/%.2f m | Eflux: %.1f/%.1f kW/m\n', ...
        datestr(SurveyDates(idx)), DeepZone_change(idx), ...
        Hs_mean_interval(idx), Hs_max_interval(idx), ...
        Eflux_mean_interval(idx), Eflux_max_interval(idx));
end

%% SHALLOW ZONE TIMING ANALYSIS
fprintf('\n=== SHALLOW ZONE VOLUME DYNAMICS (-4m < z < MSL) ===\n');
fprintf('Shallow zone range: [%.2f, %.2f] m³/m\n', min(Vol_shallow), max(Vol_shallow));

% Calculate shallow zone changes between surveys
ShallowZone_change = diff(Vol_shallow);
[max_acc_shallow, idx_acc_shallow] = max(ShallowZone_change);
[max_ero_shallow, idx_ero_shallow] = min(ShallowZone_change);

fprintf('\nMAXIMUM SHALLOW ZONE ACCRETION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_acc_shallow)), datestr(SurveyDates(idx_acc_shallow+1)), ...
    days(SurveyDates(idx_acc_shallow+1) - SurveyDates(idx_acc_shallow)));
fprintf('  Change: +%.2f m³/m\n', max_acc_shallow);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_acc_shallow), Hs_max_interval(idx_acc_shallow));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_acc_shallow), Eflux_max_interval(idx_acc_shallow));

fprintf('\nMAXIMUM SHALLOW ZONE EROSION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_ero_shallow)), datestr(SurveyDates(idx_ero_shallow+1)), ...
    days(SurveyDates(idx_ero_shallow+1) - SurveyDates(idx_ero_shallow)));
fprintf('  Change: %.2f m³/m\n', max_ero_shallow);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_ero_shallow), Hs_max_interval(idx_ero_shallow));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_ero_shallow), Eflux_max_interval(idx_ero_shallow));

% Identify periods with large shallow zone changes
threshold_change_shallow = std(ShallowZone_change);
large_change_idx_shallow = find(abs(ShallowZone_change) > 1.5*threshold_change_shallow);
fprintf('\nLarge shallow zone changes (>1.5 SD = ±%.2f m³/m):\n', 1.5*threshold_change_shallow);
for i = 1:min(5, length(large_change_idx_shallow))
    idx = large_change_idx_shallow(i);
    fprintf('  %s: %+.2f m³/m | Hs: %.2f/%.2f m | Eflux: %.1f/%.1f kW/m\n', ...
        datestr(SurveyDates(idx)), ShallowZone_change(idx), ...
        Hs_mean_interval(idx), Hs_max_interval(idx), ...
        Eflux_mean_interval(idx), Eflux_max_interval(idx));
end

%% SUBAERIAL ZONE TIMING ANALYSIS
fprintf('\n=== SUBAERIAL ZONE VOLUME DYNAMICS (z > MSL) ===\n');
fprintf('Subaerial zone range: [%.2f, %.2f] m³/m\n', min(Vol_subaerial), max(Vol_subaerial));

% Calculate subaerial zone changes between surveys
SubaerialZone_change = diff(Vol_subaerial);
[max_acc_subaerial, idx_acc_subaerial] = max(SubaerialZone_change);
[max_ero_subaerial, idx_ero_subaerial] = min(SubaerialZone_change);

fprintf('\nMAXIMUM SUBAERIAL ZONE ACCRETION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_acc_subaerial)), datestr(SurveyDates(idx_acc_subaerial+1)), ...
    days(SurveyDates(idx_acc_subaerial+1) - SurveyDates(idx_acc_subaerial)));
fprintf('  Change: +%.2f m³/m\n', max_acc_subaerial);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_acc_subaerial), Hs_max_interval(idx_acc_subaerial));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_acc_subaerial), Eflux_max_interval(idx_acc_subaerial));

fprintf('\nMAXIMUM SUBAERIAL ZONE EROSION:\n');
fprintf('  Period: %s to %s (%.1f days)\n', ...
    datestr(SurveyDates(idx_ero_subaerial)), datestr(SurveyDates(idx_ero_subaerial+1)), ...
    days(SurveyDates(idx_ero_subaerial+1) - SurveyDates(idx_ero_subaerial)));
fprintf('  Change: %.2f m³/m\n', max_ero_subaerial);
fprintf('  Wave conditions: Mean Hs=%.2f m, Max Hs=%.2f m\n', Hs_mean_interval(idx_ero_subaerial), Hs_max_interval(idx_ero_subaerial));
fprintf('  Energy flux: Mean=%.2f kW/m, Max=%.2f kW/m\n', Eflux_mean_interval(idx_ero_subaerial), Eflux_max_interval(idx_ero_subaerial));

% Identify periods with large subaerial zone changes
threshold_change_subaerial = std(SubaerialZone_change);
large_change_idx_subaerial = find(abs(SubaerialZone_change) > 1.5*threshold_change_subaerial);
fprintf('\nLarge subaerial zone changes (>1.5 SD = ±%.2f m³/m):\n', 1.5*threshold_change_subaerial);
for i = 1:min(5, length(large_change_idx_subaerial))
    idx = large_change_idx_subaerial(i);
    fprintf('  %s: %+.2f m³/m | Hs: %.2f/%.2f m | Eflux: %.1f/%.1f kW/m\n', ...
        datestr(SurveyDates(idx)), SubaerialZone_change(idx), ...
        Hs_mean_interval(idx), Hs_max_interval(idx), ...
        Eflux_mean_interval(idx), Eflux_max_interval(idx));
end

%% COMPUTE VOLUME CHANGES BETWEEN SURVEYS (derivative)
% The bars in panel 2 will show the change between consecutive surveys
Vol_change = diff(Vol_total);  % Change between consecutive surveys
SurveyDates_intervals = SurveyDates(1:end-1);  % Plot changes at start of interval

%% CREATE FIGURE
fig = figure('position', [100 100 1600 1200]);
set(fig, 'InvertHardcopy', 'off');

% Use tight layout to ensure consistent subplot widths
tiledlayout(4, 1, 'TileSpacing', 'compact');

% Add global title
sgtitle('Wave Forcing and Coastal Morphodynamic Response (MOPs 576-589)', ...
    'fontsize', 15, 'fontweight', 'bold');

%% COLOR PALETTE
% Subaerial/beach: warm tones
col_subaerial = [0.85 0.55 0.15];   % Warm tan/orange
col_survey = [0.8 0.2 0.2];         % Red for survey markers
col_accretion = [0.2 0.65 0.2];     % Green for accretion
col_erosion = [0.8 0.2 0.2];        % Red for erosion
col_cumulative = [0.15 0.4 0.75];   % Blue for cumulative
col_subaqueous = [0.15 0.75 0.4];   % Green for subaqueous
col_shallow = [0.4 0.9 0.7];        % Light green for shallow
col_deep = [0.1 0.6 0.3];           % Dark green for deep

%% PANEL 1: WAVE HEIGHT
ax1 = nexttile;
hold on; box on; grid on;

% Convert TimeUTC to datetime for plotting
TimeUTC_dt_plot = datetime(TimeUTC, 'ConvertFrom', 'datenum');

% Plot hourly wave time series
p1 = plot(TimeUTC_dt_plot, wavehs, 'b-', 'linewidth', 1.5, 'DisplayName', 'Hourly H_s');

% Overlay survey markers
p1_survey = plot(SurveyDates, Hs_interp, 'o', 'markersize', 6, 'color', col_survey, 'DisplayName', 'Morphology Survey', 'LineStyle', 'none');

set(ax1, 'fontsize', 12, 'linewidth', 1.5);
ylabel('H_s (m)', 'fontsize', 12, 'fontweight', 'bold');
title('(a) Wave Forcing', 'fontsize', 13, 'fontweight', 'bold');
set(ax1, 'xlim', [DateStart, DateEnd], 'ylim', [0, max(wavehs)*1.3], 'XTickLabel', []);
xtickformat(ax1, 'MMM yyyy');
legend([p1, p1_survey], 'location', 'eastoutside', 'fontsize', 10, 'box', 'on');
grid on;

%% PANEL 2: TOTAL VOLUME CHANGE
ax2 = nexttile;
hold on; box on; grid on;

% Plot interval changes as bars (red=erosion, green=accretion)
pos_idx = Vol_change >= 0;
neg_idx = Vol_change < 0;
bar(SurveyDates_intervals(pos_idx), Vol_change(pos_idx), 7, 'FaceColor', col_accretion, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
bar(SurveyDates_intervals(neg_idx), Vol_change(neg_idx), 7, 'FaceColor', col_erosion, 'EdgeColor', 'none', 'FaceAlpha', 0.6);

% Overlay cumulative volume as line
p2_cumul = plot(SurveyDates, Vol_total, '-', 'linewidth', 2.5, 'color', col_cumulative, 'DisplayName', 'Cumulative volume');
plot(SurveyDates, zeros(size(SurveyDates)), 'k--', 'linewidth', 1.5);

% Create proxy objects for legend
proxy_pos = patch(NaN, NaN, col_accretion, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Accretion (interval)');
proxy_neg = patch(NaN, NaN, col_erosion, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Erosion (interval)');

set(ax2, 'fontsize', 12, 'linewidth', 1.5);
ylabel('Volume (m³/m)', 'fontsize', 12, 'fontweight', 'bold');
title('(b) Volume: Cumulative (line) & Interval Change (bars)', 'fontsize', 13, 'fontweight', 'bold');
set(ax2, 'xlim', [DateStart, DateEnd], 'XTickLabel', []);
xtickformat(ax2, 'MMM yyyy');
legend([proxy_pos, proxy_neg, p2_cumul], 'location', 'eastoutside', 'fontsize', 9, 'box', 'on');
grid on;

%% PANEL 3: SUBAERIAL & SUBAQUEOUS VOLUME
ax3 = nexttile;
hold on; box on; grid on;

p3a = plot(SurveyDates, Vol_subaerial, '-', 'linewidth', 2.5, ...
    'color', col_subaerial, 'DisplayName', 'Subaerial (Z > MSL)');
p3b = plot(SurveyDates, Vol_subaqueous, '-', 'linewidth', 2.5, ...
    'color', col_subaqueous, 'DisplayName', 'Subaqueous (Z < MSL)');
plot(SurveyDates, zeros(size(Vol_subaerial)), 'k--', 'linewidth', 1.5);

set(ax3, 'fontsize', 12, 'linewidth', 1.5);
ylabel('ΔVolume (m³/m)', 'fontsize', 12, 'fontweight', 'bold');
title('(c) Subaerial-Subaqueous Exchange', 'fontsize', 13, 'fontweight', 'bold');
set(ax3, 'xlim', [DateStart, DateEnd], 'XTickLabel', []);
xtickformat(ax3, 'MMM yyyy');
legend([p3a, p3b], 'location', 'eastoutside', 'fontsize', 10, 'box', 'on');
grid on;

%% PANEL 4: SUBAQUEOUS VOLUME BY DEPTH
ax4 = nexttile;
hold on; box on; grid on;

% Stacked area plot
fill([SurveyDates; flipud(SurveyDates)], ...
    [Vol_shallow + Vol_deep; flipud(Vol_shallow)], ...
    col_deep, 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
fill([SurveyDates; flipud(SurveyDates)], ...
    [Vol_shallow; flipud(zeros(size(Vol_shallow)))], ...
    col_shallow, 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');

% Outline - these become the legend entries
p4a = plot(SurveyDates, Vol_shallow + Vol_deep, '-', 'linewidth', 2.5, 'color', col_deep, 'DisplayName', 'Deep (< -4m)');
p4b = plot(SurveyDates, Vol_shallow, '-', 'linewidth', 2.5, 'color', col_shallow, 'DisplayName', 'Shallow (-4 to MSL)');
plot(SurveyDates, zeros(size(Vol_total)), 'k--', 'linewidth', 1.5);

set(ax4, 'fontsize', 12, 'linewidth', 1.5);
xlabel('Date', 'fontsize', 12, 'fontweight', 'bold');
ylabel('ΔV_subaqueous (m³/m)', 'fontsize', 12, 'fontweight', 'bold');
title('(d) Subaqueous by Depth (Pivot at -4m)', 'fontsize', 13, 'fontweight', 'bold');
set(ax4, 'xlim', [DateStart, DateEnd]);
xtickformat(ax4, 'MMM yyyy');
%xtickangle(45);
legend([p4a, p4b], 'location', 'eastoutside', 'fontsize', 10, 'box', 'on');
grid on;

%% PANEL 5: BEACH WIDTH AT FIXED ELEVATION (MSL) - COMMENTED OUT
% ax5 = subplot(5, 1, 5);
% hold on; box on; grid on;
%
% p5 = plot(SurveyDates, BeachWidth, '-', 'linewidth', 2.5, ...
%     'color', [0.9 0.5 0.1], 'DisplayName', 'Beach width @ MSL');
%
% % Add reference
% ref_width = nanmean(BeachWidth);
% plot(SurveyDates, ref_width*ones(size(SurveyDates)), 'k--', 'linewidth', 1.5);
% text(DateEnd - 5, ref_width + 1, sprintf('Mean: %.0f m', ref_width), ...
%     'fontsize', 11, 'fontweight', 'bold', 'BackgroundColor', 'white');
%
% set(ax5, 'fontsize', 12, 'linewidth', 1.5);
% xlabel('Date', 'fontsize', 12, 'fontweight', 'bold');
% ylabel('Width (m)', 'fontsize', 12, 'fontweight', 'bold');
% title('(e) Beach Width at MSL', 'fontsize', 13, 'fontweight', 'bold');
% set(ax5, 'xlim', [DateStart, DateEnd], 'XTickLabel', xtick_labels);
% xtickangle(45);

%% FORMATTING & LEGEND UNIFICATION
% Legends already handled in each panel with specific graphics objects

% % Add comprehensive text annotation
% info_text = {
%     ['MOPs ' num2str(MopStart) '–' num2str(MopEnd) ' (Torrey Pines North)'];
%     'Narrative: Severe winter loss → partial shallow recovery → deep profile stagnation';
%     'Pivot depth: ~4m (shown as horizontal line in depth-partitioned panel)'
% };

ax_info = axes('position', [0.12 0.01 0.76 0.04], 'visible', 'off');
% text(0.5, 0.5, info_text, 'fontsize', 10, 'horizontalalignment', 'center', ...
%     'verticalalignment', 'middle', 'parent', ax_info, 'FontName', 'Courier');

%% SAVE FIGURE
set(gcf, 'position', [100 100 1600 1200]);
print(gcf, fullfile(OutputDir, 'Figure_4_WavesVolumesWidthApr-Oct.png'), '-dpng', '-r300');
fprintf('Saved Figure 4: %s\n', fullfile(OutputDir, 'Figure_4_WavesVolumesWidthApr-Oct.png'));

%% STATISTICS
fprintf('\n=== FIGURE 4: WAVE & MORPHODYNAMIC SUMMARY ===\n');
fprintf('Period: %s to %s\n', datestr(DateStart), datestr(DateEnd));
fprintf('Surveys found: %d | Max Hs: %.2f m | Min Hs: %.2f m | Mean Hs: %.2f m\n', ...
    length(jetski), max(wavehs_unique), min(wavehs_unique), nanmean(wavehs_unique));
fprintf('Total Vol Change: %.1f → %.1f m³/m\n', Vol_total(1), Vol_total(end));
fprintf('Subaerial Vol Change: %.1f → %.1f m³/m\n', Vol_subaerial(1), Vol_subaerial(end));
fprintf('Beach Width @ MSL: %.1f → %.1f m\n', BeachWidth(1), BeachWidth(end));
