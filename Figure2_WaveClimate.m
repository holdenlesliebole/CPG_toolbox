%% FIGURE 2: Wave Climate Context (Long-Term + Experiment Period)
% 10-year context with focus on 2022-2024 experiment window
% Shows wave height, period, and energy partitioning

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox

% Set default interpreter to LaTeX
set(groot, 'defaultAxesTickLabelInterpreter','tex');
set(groot, 'defaultTextInterpreter','tex');
set(groot, 'defaultLegendInterpreter','tex');
set(groot, 'defaultColorbarTickLabelInterpreter','tex');

%% USER SETTINGS
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

% CDIP buoy station
BuoyID = '100';  % Torrey Pines buoy (Update as needed)
MopNumber = 582;  % Representative MOP for context
MopName = sprintf('D%04d', MopNumber);  % Format as D0582

% Date ranges
DateStart_LongTerm = datenum(2000, 1, 1);  % 10-year context
DateEnd_LongTerm = datenum(2025, 12, 31);
DateStart_Detailed = datenum(2022, 10, 1);  % Experiment window
DateEnd_Detailed = datenum(2023, 10, 31);

%% LOAD REAL WAVE DATA USING read_MOPline2
fprintf('Loading wave data for %s (%s to %s)...\n', MopName, ...
    datestr(DateStart_LongTerm, 'yyyy-mm-dd'), datestr(DateEnd_LongTerm, 'yyyy-mm-dd'));

try
    % Convert datenums to datetime for read_MOPline2 (explicitly UTC to avoid timezone shifts)
    dt1 = datetime(DateStart_LongTerm, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    dt2 = datetime(DateEnd_LongTerm, 'ConvertFrom', 'datenum', 'TimeZone', 'America/Los_Angeles');
    
    % Load MOP wave data
    MOP = read_MOPline2(MopName, dt1, dt2);
    
    % Extract time, Hs, and Tp from struct
    timeW_dt = MOP.time(:);  % datetime array (in UTC)
    wavehs = MOP.Hs(:);
    waveTp = MOP.Tp(:);
    
    % Convert datetime to datenum (preserving UTC times)
    if isdatetime(timeW_dt)
        TimeUTC = datenum(timeW_dt);  % datenum is timezone-agnostic; this stays UTC
    else
        TimeUTC = timeW_dt;
    end
    
    fprintf('Successfully loaded %d wave data points from %s\n', length(wavehs), MopName);
    
catch ME
    error('Failed to load wave data for %s: %s\nMake sure read_MOPline2 is in your path.', MopName, ME.message);
end

%% PREPARE DATA FOR PLOTTING
% Use raw hourly data
t_hourly = TimeUTC;
Hs_hourly = wavehs;
Tp_hourly = waveTp;

% 30-day moving mean for Panel A thick line (720 hours = 30 days)
Hs_30day_mean = movmean(Hs_hourly, 720, 'omitnan');

% Compute long-term statistics
Hs_long_mean = nanmean(Hs_hourly);
Hs_long_max = nanmax(Hs_hourly);

% Extract detailed data for experiment window (hourly resolution)
idx_detailed = find(t_hourly >= DateStart_Detailed & t_hourly <= DateEnd_Detailed);
t_detailed = t_hourly(idx_detailed);
Hs_detailed = Hs_hourly(idx_detailed);
Tp_detailed = Tp_hourly(idx_detailed);

% Compute energy anomaly
Hs_anom_detailed = Hs_detailed - Hs_long_mean;

%% DIRECTIONAL SPECTRUM (SEASONAL AVERAGES - following Ch1Fig2.m structure)
dt_all = datetime(TimeUTC, 'ConvertFrom', 'datenum', 'TimeZone', 'UTC');
freq = double(MOP.frequency(:));
f = freq;  % Use 'f' to match Ch1Fig2.m
period = 1 ./ freq;
theta_bins = linspace(0, 2*pi, 360);  % radians
theta_deg = rad2deg(theta_bins);

% Ensure matrices are time x freq
spec1D_full = MOP.spec1D;
a1_full = MOP.a1; 
b1_full = MOP.b1; 
a2_full = MOP.a2; 
b2_full = MOP.b2;

% Extract year from datetime for looping
years_in_data = unique(year(dt_all));
start_year = years_in_data(1);
end_year = years_in_data(end);

% Initialize seasonal spectra accumulators (exactly like Ch1Fig2.m)
seasonal_spectra = cell(4, 1);
for i = 1:4
    seasonal_spectra{i} = zeros(length(f), 360);  % 20 frequency bins x 360 direction bins
end

% Initialize seasonal Hs accumulators
seasonal_Hs_sum = zeros(4, 1);
seasonal_count = zeros(4, 1);

% Loop year-by-year through seasons (following Ch1Fig2.m structure)
fprintf('Computing directional spectra...\n');
for year = start_year:end_year
    fprintf('  Year %d...\n', year);
    
    % Define seasonal dates for this year (matching Ch1Fig2.m)
    current_season_dates = {...
        [datetime(year-1,12,21,'TimeZone','UTC'), datetime(year,3,19,'TimeZone','UTC')], ... % DJF
        [datetime(year,3,20,'TimeZone','UTC'), datetime(year,6,20,'TimeZone','UTC')], ...    % MAM
        [datetime(year,6,21,'TimeZone','UTC'), datetime(year,9,22,'TimeZone','UTC')], ...    % JJA
        [datetime(year,9,23,'TimeZone','UTC'), datetime(year,12,20,'TimeZone','UTC')] ...    % SON
    };
    
    for season_idx = 1:4
        season_start = current_season_dates{season_idx}(1);
        season_end = current_season_dates{season_idx}(2);
        
        % Find indices for this season
        idx_season = find(dt_all >= season_start & dt_all <= season_end);
        if isempty(idx_season)
            continue;
        end
        
        % Get number of time steps
        n = length(idx_season);
        
        % Initialize directional spectrum for this season (n x freq x directions)
        dir_spectrum = zeros(n, length(f), 360);
        Hs_season = [];
        
        % Calculate directional spectrum for each time step (matching Ch1Fig2.m)
        for i = 1:n
            ii = idx_season(i);
            
            % Fourier coefficients for this time step
            a1 = a1_full(ii, :);
            b1 = b1_full(ii, :);
            a2 = a2_full(ii, :);
            b2 = b2_full(ii, :);
            
            % Mean direction (from a1 and b1) for each frequency
            theta_mean = atan2(b1, a1);
            
            % Compute the directional spread for each frequency and direction bin
            for j = 1:length(f)
                % Directional distribution using the first and second harmonics
                theta_diff = theta_bins - theta_mean(j);
                
                % Calculate directional energy distribution for each frequency
                D_theta = (1 / (2 * pi)) * (1 + a1(j) * cos(theta_diff) + b1(j) * sin(theta_diff) ...
                            + a2(j) * cos(2 * theta_diff) + b2(j) * sin(2 * theta_diff));
                
                % Scale by the energy spectrum at this frequency
                dir_spectrum(i, j, :) = spec1D_full(ii, j) * D_theta;
            end
            
            Hs_season = [Hs_season; wavehs(ii)];
        end
        
        % Average the directional spectrum over time for this season
        avg_dir_spectrum = squeeze(mean(dir_spectrum, 1));  % Mean over n time steps
        
        % Accumulate across years
        seasonal_spectra{season_idx} = seasonal_spectra{season_idx} + avg_dir_spectrum;
        seasonal_Hs_sum(season_idx) = seasonal_Hs_sum(season_idx) + nanmean(Hs_season);
        seasonal_count(season_idx) = seasonal_count(season_idx) + 1;
    end
end

% Compute final seasonal averages by dividing by the number of years
for season_idx = 1:4
    if seasonal_count(season_idx) > 0
        seasonal_spectra{season_idx} = seasonal_spectra{season_idx} / seasonal_count(season_idx);
        seasonal_Hs_mean(season_idx) = seasonal_Hs_sum(season_idx) / seasonal_count(season_idx);
    else
        seasonal_Hs_mean(season_idx) = NaN;
    end
end
fprintf('Directional spectra computation complete.\n');

%% CREATE FIGURE
fig = figure('position', [100 100 1400 900]);
set(fig, 'InvertHardcopy', 'off');

% Outer tiled layout: left column = time series, right column = directional spectra
outerTL = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

%% LEFT COLUMN: TIME SERIES PANELS
leftTL = tiledlayout(outerTL, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
leftTL.Layout.Tile = 1;

%% PANEL A: 10-YEAR LONG-TERM CONTEXT (30-day moving mean)
ax1 = nexttile(leftTL, 1);
hold on; box on; grid on;

% Raw hourly data envelope (light shading)
plot(t_hourly, Hs_hourly, '-', 'Color', [0.7 0.85 1.0], 'linewidth', 0.5, 'HandleVisibility', 'off');

% 30-day moving mean (thick line)
p1 = plot(t_hourly, Hs_30day_mean, 'b-', 'linewidth', 2.5, 'DisplayName', '30-Day Mean');

% Long-term mean line (black dashed)
plot([DateStart_LongTerm DateEnd_LongTerm], [Hs_long_mean Hs_long_mean], 'k--', ...
    'linewidth', 2, 'DisplayName', sprintf('Long-Term Mean = %.2f m', Hs_long_mean));

% Horizontal reference lines for seasonal means
if exist('seasonal_Hs_mean', 'var')
    % DJF mean (winter) in red
    plot([DateStart_LongTerm DateEnd_LongTerm], [seasonal_Hs_mean(1) seasonal_Hs_mean(1)], 'r--', ...
        'linewidth', 2, 'DisplayName', sprintf('Winter (DJF) = %.2f m', seasonal_Hs_mean(1)));
    % JJA mean (summer) in blue
    plot([DateStart_LongTerm DateEnd_LongTerm], [seasonal_Hs_mean(3) seasonal_Hs_mean(3)], 'c--', ...
        'linewidth', 2, 'DisplayName', sprintf('Summer (JJA) = %.2f m', seasonal_Hs_mean(3)));
end

% Highlight experiment window (2022-2024)
exp_start = datenum(2022, 10, 1);
exp_end = datenum(2023, 10, 31);
ylims = ylim;
patch([exp_start, exp_end, exp_end, exp_start], ...
    [ylims(1), ylims(1), ylims(2), ylims(2)], ...
    'red', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(exp_start, ylims(2) * 0.92, 'Experiment', ...
    'fontsize', 11, 'fontweight', 'bold', 'color', 'red', 'horizontalalignment', 'center', 'Interpreter', 'tex');
text(exp_start, ylims(2) * 0.85, 'Period', ...
    'fontsize', 11, 'fontweight', 'bold', 'color', 'red', 'horizontalalignment', 'center', 'Interpreter', 'tex');

set(ax1, 'fontsize', 13, 'linewidth', 1.5);
datetick('x', 'yyyy', 'keepticks');
ylabel('$H_s$ (m)', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
title('(a) 24-Year Wave Climate Context', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
legend('location', 'northwest', 'fontsize', 10, 'Interpreter', 'latex');
set(ax1, 'xlim', [DateStart_LongTerm, DateEnd_LongTerm]);

%% PANEL B: DETAILED HOURLY Hs & Tp (Experiment Period)
ax2 = nexttile(leftTL, 2);
hold on; box on; grid on;

% Wave height on left axis
yyaxis left
p2 = plot(t_detailed, Hs_detailed, 'b-', 'linewidth', 0.5, 'DisplayName', 'Hourly $H_s$');
Hs_smooth = movmean(Hs_detailed, 168, 'omitnan');  % 7-day moving average (168 hours)
p3 = plot(t_detailed, Hs_smooth, 'b-', 'linewidth', 2.5, 'DisplayName', '7-Day Mean $H_s$');
set(gca, 'ycolor', 'b', 'ylim', [0, max(Hs_detailed)*1.1]);
ylabel('Significant Wave Height $H_s$ (m)', 'fontsize', 14, 'fontweight', 'bold', 'color', 'b', 'Interpreter', 'latex');

% Wave period on right axis (dots for raw data)
yyaxis right
p4 = plot(t_detailed, Tp_detailed, 'r.', 'markersize', 2, 'HandleVisibility', 'off');
Tp_smooth = movmean(Tp_detailed, 168, 'omitnan');
p5 = plot(t_detailed, Tp_smooth, 'r-', 'linewidth', 2.5, 'DisplayName', '$T_p$ (7-Day Mean)');
set(gca, 'ycolor', 'r', 'ylim', [4, 20]);
ylabel('Peak Period $T_p$ (s)', 'fontsize', 14, 'fontweight', 'bold', 'color', 'r', 'Interpreter', 'latex');

set(ax2, 'fontsize', 13, 'linewidth', 1.5);
datetick('x', 'mmm yy', 'keepticks');
title('(b) Hourly and Weekly Wave Parameters', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
% Simplified legend with just one label each for Hs and Tp
legend([p3, p5], {'$H_s$ (7-Day Mean)', '$T_p$ (7-Day Mean)'}, ...
    'location', 'northeast', 'fontsize', 11, 'Interpreter', 'latex');

%% PANEL C: WAVE ENERGY ANOMALY (LOG SCALE)
ax3 = nexttile(leftTL, 3);
hold on; box on; grid on;

% True wave energy (from MOP.EfluxXtotal)
E_detailed = MOP.EfluxXtotal(idx_detailed);
E_mean = nanmean(E_detailed);
E_anom = E_detailed - E_mean;

% Convert to log scale (shift to positive values)
E_anom_pos = E_anom; %+ abs(min(E_anom)) + 0.1;  % Shift all positive for log scale

% Moving average
E_anom_smooth = movmean(E_anom_pos, 720, 'omitnan');  % 30-day smooth (720 hours)
plot(t_detailed, E_anom_smooth, 'k-', 'linewidth', 2.5, 'DisplayName', '30-Day Mean');

% Color code by positive/negative anomalies
pos_idx = E_anom > 0;
neg_idx = E_anom <= 0;

h1 = plot(t_detailed(pos_idx), E_anom_pos(pos_idx), 'r.', 'markersize', 3, 'DisplayName', 'Above Average');
h2 = plot(t_detailed(neg_idx), E_anom_pos(neg_idx), 'b.', 'markersize', 3, 'DisplayName', 'Below Average');

set(ax3, 'fontsize', 13, 'linewidth', 1.5);%, 'YScale', 'log');
datetick('x', 'mmm yy', 'keepticks');
xlabel('Date', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
ylabel('Wave Energy Anomaly (m$^2$/s)', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
title('(c) Wave Energy Anomalies', 'fontsize', 14, 'fontweight', 'bold', 'Interpreter', 'latex');
legend('location', 'northeast', 'fontsize', 10, 'Interpreter', 'latex');

% Set consistent x-axis
set(ax2, 'xlim', [min(t_detailed), max(t_detailed)]);
set(ax3, 'xlim', [min(t_detailed), max(t_detailed)]);

%% RIGHT COLUMN: SEASONAL DIRECTIONAL WAVE SPECTRA (FREQUENCY vs DIRECTION)
rightTL = tiledlayout(outerTL, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
rightTL.Layout.Tile = 2;

season_names_pretty = {'Winter (DJF)', 'Spring (MAM)', 'Summer (JJA)', 'Fall (SON)'};

% Find global min and max for consistent colorbar scaling
min_energy = inf;
max_energy = -inf;
for season_idx = 1:4
    avg_dir_spectrum = seasonal_spectra{season_idx};
    min_energy = min(min_energy, min(avg_dir_spectrum(:)));
    max_energy = max(max_energy, max(avg_dir_spectrum(:)));
end

for s = 1:4
    ax = nexttile(rightTL, s);
    hold on; box on; grid on;

    avg_dir_spectrum = seasonal_spectra{s};
    
    % Rotate spectral data by 90 degrees (circshift by 90 indices out of 360)
    avg_dir_spectrum = circshift(avg_dir_spectrum, 90, 2);
    
    % Create grid for frequency vs direction plot (use original theta_deg, data is already shifted)
    [Fgrid, Tgrid] = meshgrid(f, theta_deg);
    
    % Plot as rectangular pcolor (frequency x direction)
    pcolor(Fgrid, Tgrid, avg_dir_spectrum');
    shading interp;
    colormap(ax, hsv);
    clim([0, max_energy]);
    grid on;
    
    xlabel('Frequency (Hz)', 'fontsize', 11, 'fontweight', 'bold', 'Interpreter', 'latex');
    ylabel('Direction (deg)', 'fontsize', 11, 'fontweight', 'bold', 'Interpreter', 'latex');
    subplot_labels = {'(d) Winter (DJF)', '(e) Spring (MAM)', '(f) Summer (JJA)', '(g) Fall (SON)'};
    title(subplot_labels{s}, 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
    xlim([min(f), max(f)]);
    ylim([0 360]);
    set(ax, 'fontsize', 10, 'linewidth', 1.2);
end

% Add global colorbar
% cb = colorbar(nexttile(rightTL, 4), 'Location', 'eastoutside');
% cb.Label.String = 'Wave Energy (m$^2$/Hz/deg)';
% cb.Label.FontWeight = 'bold';
% cb.Label.FontSize = 11;
% cb.Label.Interpreter = 'latex';

%% OVERALL FIGURE FORMATTING & SAVE
sgtitle(outerTL, 'Figure 2: Wave Climate Context \& Seasonal Directional Spectra', ...
    'fontsize', 18, 'fontweight', 'bold', 'Interpreter', 'latex');

set(gcf, 'position', [100 100 1400 900]);
exportgraphics(gcf, fullfile(OutputDir, 'Figure_2_WaveClimate.png'), 'Resolution', 300);
fprintf('Saved Figure 2: %s\n', fullfile(OutputDir, 'Figure_2_WaveClimate.png'));

%% SUMMARY STATISTICS
fprintf('\n=== FIGURE 2: WAVE CLIMATE SUMMARY ===\n');
fprintf('Period: %s to %s\n', datestr(DateStart_LongTerm), datestr(DateEnd_Detailed));
fprintf('Mean Hs (long-term): %.2f m\n', Hs_long_mean);
fprintf('Max Hs (experiment): %.2f m\n', max(Hs_detailed));
fprintf('Min Hs (experiment): %.2f m\n', min(Hs_detailed));
fprintf('Mean Tp (experiment): %.2f s\n', nanmean(Tp_detailed));
fprintf('Std Hs (experiment): %.2f m\n', nanstd(Hs_detailed));

% Identify stormy periods
storm_threshold = Hs_long_mean + 1.0;
storm_idx = find(Hs_detailed > storm_threshold);
fprintf('Days with Hs > %.2f m: %d days (%.1f%% of period)\n', ...
    storm_threshold, length(storm_idx), 100*length(storm_idx)/length(Hs_detailed));
