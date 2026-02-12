%% FIGURE: Φ TRANSPORT PROXY VISUALIZATION
% Publication-quality figures for Φ proxy analysis results
%
% Generates three figure panels as specified in phi_proxy_pipeline_spec.md §9:
%   A: Time series - Fb, Φ, cumulative Φ, survey Δz markers
%   B: Scatter - Δz vs ΣΦ with regression + CI
%   C: Null comparison - Δz vs cumulative Fb
%   D: Threshold sensitivity curve
%
% DEPTH BAND CALIBRATION (January 2026):
%   Updated to use 4-5m depth band (z = [-5, -4] m NAVD88) based on
%   TBR23MeanElevChange.png, which shows cumulative energy flux cubed
%   closely tracks elevation changes in this zone. This is the primary
%   response depth at Torrey Pines (see TBR23/PlotMeanElevChange.m)
%
% REQUIRES: PhiProxyResults.mat (from PhiProxyAnalysis.m)
%
% Holden Leslie-Bole, January 2026

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox
addpath /Users/holden/Documents/Scripps/Research/toolbox/PhiProxy

%% ========================================================================
%  LOAD RESULTS
%  ========================================================================

OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
ResultsFile = fullfile(OutputDir, 'PhiProxyResults.mat');

if ~exist(ResultsFile, 'file')
    error('Results file not found. Run PhiProxyAnalysis.m first.');
end

fprintf('Loading results from %s...\n', ResultsFile);
load(ResultsFile, 'PhiResults');

%% ========================================================================
%  UNPACK DATA
%  ========================================================================

% Time series
t_wave = PhiResults.wave.t;
Fb = PhiResults.wave.Fb;
Phi = PhiResults.wave.Phi;
PhiCum = PhiResults.wave.PhiCum;
Hs = PhiResults.wave.Hs;

% Survey data
SurveyDates = PhiResults.survey.dates;
delta_z = PhiResults.survey.delta_z;
delta_z_err = PhiResults.survey.delta_z_err;
z_mean_band = PhiResults.survey.z_mean_band;
if isfield(PhiResults.survey, 'z_std_band')
    z_std_band = PhiResults.survey.z_std_band;
else
    z_std_band = delta_z_err;  % Use delta_z_err as fallback
end

% Intervals
PhiSum = PhiResults.intervals.PhiSum;
FbSum = PhiResults.intervals.FbSum;

% Threshold
best_crit = PhiResults.threshold.best_crit;
sensitivity = PhiResults.threshold.sensitivity;

% Skill
results = PhiResults.skill;

% Config
depth_band = PhiResults.config.depth_band;
exponent = PhiResults.config.exponent;

%% ========================================================================
%  COLOR SCHEME (consistent with paper figures)
%  ========================================================================

col_Fb = [0.15 0.4 0.75];         % Blue for energy flux
col_Phi = [0.85 0.35 0.15];       % Orange for Φ
col_survey = [0.2 0.7 0.3];       % Green for survey points
col_regression = [0.8 0.2 0.2];   % Red for regression
col_CI = [0.9 0.85 0.85];         % Light pink for CI
col_null = [0.5 0.5 0.5];         % Gray for null models

%% ========================================================================
%  FIGURE 1: TIME SERIES OVERVIEW
%  ========================================================================

fig1 = figure('Position', [100 100 1600 1000], 'Color', 'white');
set(fig1, 'DefaultAxesFontSize', 11, 'DefaultAxesLineWidth', 1.2);

tl1 = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel A: Significant Wave Height ---
ax1 = nexttile;
hold on; box on; grid on;

p_Hs = plot(t_wave, Hs, '-', 'LineWidth', 1, 'Color', [col_Fb 0.6], ...
    'DisplayName', 'H_s (hourly)');

% Survey markers on Hs
for i = 1:length(SurveyDates)
    xline(SurveyDates(i), '--', 'Color', [col_survey 0.4], 'LineWidth', 0.8);
end

ylabel('H_s (m)', 'FontWeight', 'bold');
title('(a) Wave Height Time Series', 'FontSize', 13, 'FontWeight', 'bold');
set(ax1, 'XTickLabel', []);
xlim([min(SurveyDates) max(SurveyDates)]);
xtickformat('yyyy-MM-dd');

% --- Panel B: Energy Flux ---
ax2 = nexttile;
hold on; box on; grid on;

p_Fb = plot(t_wave, Fb/1000, '-', 'LineWidth', 1, 'Color', col_Fb, ...
    'DisplayName', 'F_b');

% Mark threshold on energy scale
Fb_thresh = best_crit^(1/exponent);  % Convert back to Fb units
yline(Fb_thresh/1000, 'r--', 'LineWidth', 2, 'DisplayName', 'F_{thresh}');

ylabel('F_b (kW/m)', 'FontWeight', 'bold');
title(sprintf('(b) Bottom Energy Flux (threshold at %.1f kW/m)', Fb_thresh/1000), ...
    'FontSize', 13, 'FontWeight', 'bold');
set(ax2, 'XTickLabel', []);
xlim([min(SurveyDates) max(SurveyDates)]);
xtickformat('yyyy-MM-dd');
legend('Location', 'northeast', 'FontSize', 10);

% --- Panel C: Instantaneous Φ ---
ax3 = nexttile;
hold on; box on; grid on;

% Show Φ as stem plot for clarity of episodic events
Phi_plot = Phi;
Phi_plot(Phi == 0) = NaN;  % Don't plot zeros

p_Phi = stem(t_wave, Phi_plot/1e12, 'filled', 'MarkerSize', 2, ...
    'Color', col_Phi, 'LineWidth', 0.5, 'DisplayName', '\Phi (active)');

ylabel('\Phi (×10^{12})', 'FontWeight', 'bold');
title(sprintf('(c) Instantaneous \\Phi = max(0, F_b^{%d} - \\Phi_{crit})', exponent), ...
    'FontSize', 13, 'FontWeight', 'bold');
set(ax3, 'XTickLabel', []);
xlim([min(SurveyDates) max(SurveyDates)]);
xtickformat('yyyy-MM-dd');

% --- Panel D: Cumulative Φ with Survey Markers ---
ax4 = nexttile;
hold on; box on; grid on;

p_PhiCum = plot(t_wave, PhiCum/1e15, '-', 'LineWidth', 2, 'Color', col_Phi, ...
    'DisplayName', 'Cumulative \Phi');

% Add survey markers with Δz color coding
scatter_size = 60;
for i = 1:length(SurveyDates)-1
    mid_time = SurveyDates(i) + (SurveyDates(i+1) - SurveyDates(i))/2;
    
    % Find cumulative Φ at survey time
    [~, idx_surv] = min(abs(t_wave - SurveyDates(i+1)));
    phi_cum_i = PhiCum(idx_surv)/1e15;
    
    if delta_z(i) > 0
        scatter(SurveyDates(i+1), phi_cum_i, scatter_size, 'o', ...
            'MarkerFaceColor', col_survey, 'MarkerEdgeColor', 'k', 'LineWidth', 1);
    else
        scatter(SurveyDates(i+1), phi_cum_i, scatter_size, 'v', ...
            'MarkerFaceColor', col_regression, 'MarkerEdgeColor', 'k', 'LineWidth', 1);
    end
end

xlabel('Date', 'FontWeight', 'bold');
ylabel('\Sigma\Phi (×10^{15})', 'FontWeight', 'bold');
title('(d) Cumulative \Phi with Survey Markers (●=accretion, ▼=erosion)', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlim([min(SurveyDates) max(SurveyDates)]);
xtickformat('yyyy-MM-dd');
xtickangle(45);

% Link x-axes
linkaxes([ax1, ax2, ax3, ax4], 'x');

% Save Figure 1
exportgraphics(fig1, fullfile(OutputDir, 'Figure_PhiProxy_TimeSeries.png'), ...
    'Resolution', 300);
fprintf('Saved: Figure_PhiProxy_TimeSeries.png\n');

%% ========================================================================
%  FIGURE 1B: SURVEY ELEVATION vs. CUMULATIVE PHI PROXY (TBR23-style)
%  ========================================================================
% Direct comparison to TBR23MeanElevChange.png structure:
%   LEFT: Survey bed elevations in depth band (similar to Δz panel)
%   RIGHT: Cumulative Φ proxy time series (similar to red dashed curve)

fig1b = figure('Position', [100 100 1200 600], 'Color', 'white');
set(fig1b, 'DefaultAxesFontSize', 12, 'DefaultAxesLineWidth', 1.5);

% Create a single axes for dual-axis plot
ax = axes('Position', [0.12 0.15 0.75 0.75]);

% LEFT AXIS: Survey bed elevation changes (relative to first survey, like TBR23)
yyaxis left;
hold on; box on; grid on;

% Compute elevation change relative to first survey
% Note: delta_z = diff(z_mean_band), so positive delta_z = accretion (bed rises)
% Negate to show erosion as positive (more intuitive for transport/energy flux)
z_change = -[0; cumsum(delta_z)];  % Negate so erosion (negative delta_z) appears as positive
z_change_cm = z_change * 100;  % Convert to cm to match TBR23 plot

% Plot elevation change with large dot markers and lines, exactly like TBR23
% Use '.-' format (dots with line) not 'o-' (circles) to match TBR23 style
p_z_survey = plot(SurveyDates, z_change_cm, '.-', 'LineWidth', 3, ...
    'MarkerSize', 35, 'Color', col_survey, 'DisplayName', 'Cumulative bed elevation change');

ylabel('Mean Elevation Change (cm)', 'FontWeight', 'bold', 'FontSize', 11);
ax.YAxis(1).Color = col_survey;

% RIGHT AXIS: Cumulative Φ proxy (negated and normalized to align with bed elevation)
yyaxis right;
hold on;

% Negate Phi to flip it vertically (decreases when bed elevation decreases)
% and normalize to same scale as bed elevation for direct comparison
PhiCum_aligned = -PhiCum / max(abs(PhiCum));  % Negate and normalize to [-1, 0]
z_change_scale = max(abs(z_change_cm));
PhiCum_aligned = PhiCum_aligned * z_change_scale;  % Scale to match z_change range

p_PhiCum_right = plot(t_wave, PhiCum_aligned, '-', 'LineWidth', 2, ...
    'Color', col_Phi, 'DisplayName', 'Cumulative \Phi proxy (flipped, aligned)');

ylabel('Cumulative \Phi Proxy (aligned scale)', 'FontWeight', 'bold', 'FontSize', 11);
ax.YAxis(2).Color = col_Phi;

xlabel('Date', 'FontWeight', 'bold', 'FontSize', 11);
title('Survey Bed Elevation vs. Cumulative \Phi Proxy (TBR23-style)', ...
    'FontSize', 13, 'FontWeight', 'bold');

xlim([min(SurveyDates) max(SurveyDates)]);
ax.XAxis.TickLabelRotation = 45;
xtickformat('yyyy-MM-dd');

% Custom legend combining both axes
leg_handles = [p_z_survey, p_PhiCum_right];
leg_labels = {get(p_z_survey, 'DisplayName'), get(p_PhiCum_right, 'DisplayName')};
legend(leg_handles, leg_labels, 'Location', 'northwest', 'FontSize', 11);

% Save Figure 1B
exportgraphics(fig1b, fullfile(OutputDir, 'Figure_PhiProxy_ElevationVsFlux.png'), ...
    'Resolution', 300);
fprintf('Saved: Figure_PhiProxy_ElevationVsFlux.png\n');

%% ========================================================================
%  FIGURE 2: SCATTER PLOTS (Skill Assessment)
%  ========================================================================

fig2 = figure('Position', [100 100 1400 500], 'Color', 'white');
set(fig2, 'DefaultAxesFontSize', 12, 'DefaultAxesLineWidth', 1.2);

tl2 = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel A: Δz vs ΣΦ (Main Result) ---
ax_a = nexttile;
hold on; box on; grid on;

% Valid data
valid = isfinite(PhiSum) & isfinite(delta_z);
X = PhiSum(valid);
Y = delta_z(valid);

% Negate Phi so it decreases when bed elevation decreases (aligned with Δz sign convention)
X = -X;

% Normalize X and Y to align both at origin (0,0)
X_scale = max(abs(X));
Y_scale = max(abs(Y));
X_norm = X / X_scale;
Y_norm = Y / Y_scale;

% Regression line + CI on normalized data
p_norm = polyfit(X_norm, Y_norm, 1);

x_range = linspace(-1.1, 1.1, 100);
y_fit = polyval(p_norm, x_range);

% Bootstrap CI (approximate from stored CI)
slope_CI = results.phi.p_CI(1, :);
y_lower = slope_CI(1)*x_range - 0.1;
y_upper = slope_CI(2)*x_range + 0.1;

fill([x_range, fliplr(x_range)], [y_lower, fliplr(y_upper)], ...
    col_CI, 'EdgeColor', 'none', 'FaceAlpha', 0.5);

plot(x_range, y_fit, '-', 'LineWidth', 2.5, 'Color', col_regression);

% Data points with error bars
scatter(X_norm, Y_norm, 80, 'o', 'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

xlabel('\Sigma\Phi (normalized, 0 at origin)', 'FontWeight', 'bold');
ylabel('\Deltaz (normalized, 0 at origin)', 'FontWeight', 'bold');
title(sprintf('(a) \\Deltaz vs \\Sigma\\Phi (aligned)  |  R² = %.2f, r = %.2f', ...
    results.phi.R2, results.phi.r), 'FontSize', 13, 'FontWeight', 'bold');

% Zero reference lines at origin
xline(0, 'k--', 'LineWidth', 1.5);
yline(0, 'k--', 'LineWidth', 1.5);

% Set limits to be symmetric around origin
set(gca, 'XLim', [-1.2 1.2], 'YLim', [-1.2 1.2]);

% --- Panel B: Δz vs ΣFb (Null Comparison) ---
ax_b = nexttile;
hold on; box on; grid on;

X_null = FbSum(valid);
X_null_norm = X_null / max(abs(X_null));

% Regression
p_null = polyfit(X_null_norm, Y, 1);
x_range_null = linspace(min(X_null_norm)*1.1, max(X_null_norm)*1.1, 100);
y_fit_null = polyval(p_null, x_range_null);

plot(x_range_null, y_fit_null, '-', 'LineWidth', 2, 'Color', col_null);
scatter(X_null_norm, Y, 80, 's', 'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

xlabel('\SigmaF_b (normalized)', 'FontWeight', 'bold');
ylabel('\Deltaz (m)', 'FontWeight', 'bold');
title(sprintf('(b) \\Deltaz vs \\SigmaF_b (Null)  |  R² = %.2f, r = %.2f', ...
    results.fb.R2, results.fb.r), 'FontSize', 13, 'FontWeight', 'bold');

xline(0, 'k--', 'LineWidth', 1);
yline(0, 'k--', 'LineWidth', 1);

% --- Panel C: Threshold Sensitivity ---
ax_c = nexttile;
hold on; box on; grid on;

% Plot skill metrics vs quantile
q_pct = sensitivity.quantiles * 100;

yyaxis left
p1 = plot(q_pct, sensitivity.R2, '-o', 'LineWidth', 2, 'MarkerSize', 6, ...
    'Color', col_Fb, 'MarkerFaceColor', 'none', 'DisplayName', 'R²');
p2 = plot(q_pct, sensitivity.cv_R2, '-s', 'LineWidth', 2, 'MarkerSize', 6, ...
    'Color', col_Phi, 'MarkerFaceColor', 'none', 'DisplayName', 'cv-R²');
ylabel('R² / cv-R²', 'FontWeight', 'bold');
ylim([min([sensitivity.R2; sensitivity.cv_R2])-0.1, 1]);

yyaxis right
p3 = plot(q_pct, sensitivity.RMSE*100, '-^', 'LineWidth', 2, 'MarkerSize', 6, ...
    'Color', col_survey, 'MarkerFaceColor', 'none', 'DisplayName', 'RMSE');
ylabel('RMSE (cm)', 'FontWeight', 'bold');

% Mark optimal threshold
xline(sensitivity.best_quantile*100, 'r--', 'LineWidth', 2.5);
text(sensitivity.best_quantile*100 + 2, 0.9*max(ylim), ...
    sprintf('Optimal: %.0f%%', sensitivity.best_quantile*100), ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', 'red');

xlabel('\Phi_{crit} Quantile (%)', 'FontWeight', 'bold');
title('(c) Threshold Sensitivity', 'FontSize', 13, 'FontWeight', 'bold');
legend([p1, p2, p3], 'Location', 'southwest', 'FontSize', 10);

% Save Figure 2
exportgraphics(fig2, fullfile(OutputDir, 'Figure_PhiProxy_Scatter.png'), ...
    'Resolution', 300);
fprintf('Saved: Figure_PhiProxy_Scatter.png\n');

%% ========================================================================
%  FIGURE 3: COMBINED PAPER FIGURE (2x2 Layout)
%  ========================================================================

fig3 = figure('Position', [100 50 1200 1000], 'Color', 'white');
set(fig3, 'DefaultAxesFontSize', 11, 'DefaultAxesLineWidth', 1.2);

tl3 = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel A: Time Series (Fb + Φcum) ---
ax3a = nexttile;
hold on; box on; grid on;

yyaxis left
p_fb_ts = plot(t_wave, Fb/1000, '-', 'LineWidth', 1, 'Color', [col_Fb 0.5]);
ylabel('F_b (kW/m)', 'FontWeight', 'bold', 'Color', col_Fb);
set(ax3a, 'YColor', col_Fb);

yyaxis right
p_phi_ts = plot(t_wave, PhiCum/1e15, '-', 'LineWidth', 2, 'Color', col_Phi);
ylabel('\Sigma\Phi (×10^{15})', 'FontWeight', 'bold', 'Color', col_Phi);
set(ax3a, 'YColor', col_Phi);

% Survey markers
for i = 1:length(SurveyDates)
    xline(SurveyDates(i), ':', 'Color', [0.5 0.5 0.5 0.5], 'LineWidth', 0.5);
end

xlabel('Date', 'FontWeight', 'bold');
title(sprintf('(a) Energy Flux & Cumulative \\Phi (depth band: %d to %d m)', ...
    depth_band(1), depth_band(2)), 'FontSize', 12, 'FontWeight', 'bold');
xlim([min(SurveyDates) max(SurveyDates)]);
xtickformat('yyyy');

% --- Panel B: Δz vs ΣΦ ---
ax3b = nexttile;
hold on; box on; grid on;

valid = isfinite(PhiSum) & isfinite(delta_z);
X = PhiSum(valid);
Y = delta_z(valid);
X_norm = X / max(abs(X));
X_scale = max(abs(X));

p = results.phi.p;
p_norm = [p(1)*X_scale, p(2)];

x_range = linspace(min(X_norm)*1.1, max(X_norm)*1.1, 100);
y_fit = polyval(p_norm, x_range);

plot(x_range, y_fit, '-', 'LineWidth', 2.5, 'Color', col_regression);
scatter(X_norm, Y, 70, 'o', 'MarkerFaceColor', col_Phi, ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

xlabel('\Sigma\Phi (normalized)', 'FontWeight', 'bold');
ylabel('\Deltaz (m)', 'FontWeight', 'bold');
title(sprintf('(b) \\Phi Proxy Skill: R² = %.2f, cv-R² = %.2f', ...
    results.phi.R2, results.phi.cv_R2), 'FontSize', 12, 'FontWeight', 'bold');

xline(0, 'k--', 'LineWidth', 1);
yline(0, 'k--', 'LineWidth', 1);

% --- Panel C: Null Comparison ---
ax3c = nexttile;
hold on; box on; grid on;

X_null = FbSum(valid);
X_null_norm = X_null / max(abs(X_null));

p_null = polyfit(X_null_norm, Y, 1);
x_range_null = linspace(min(X_null_norm)*1.1, max(X_null_norm)*1.1, 100);
y_fit_null = polyval(p_null, x_range_null);

plot(x_range_null, y_fit_null, '-', 'LineWidth', 2, 'Color', col_null);
scatter(X_null_norm, Y, 70, 's', 'MarkerFaceColor', col_Fb, ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1);

xlabel('\SigmaF_b (normalized)', 'FontWeight', 'bold');
ylabel('\Deltaz (m)', 'FontWeight', 'bold');
title(sprintf('(c) Null Model (F_b): R² = %.2f', results.fb.R2), ...
    'FontSize', 12, 'FontWeight', 'bold');

xline(0, 'k--', 'LineWidth', 1);
yline(0, 'k--', 'LineWidth', 1);

% --- Panel D: Threshold Sensitivity ---
ax3d = nexttile;
hold on; box on; grid on;

q_pct = sensitivity.quantiles * 100;

plot(q_pct, sensitivity.R2, '-o', 'LineWidth', 2, 'MarkerSize', 5, ...
    'Color', col_Fb, 'MarkerFaceColor', col_Fb, 'DisplayName', 'R²');
plot(q_pct, sensitivity.cv_R2, '-s', 'LineWidth', 2, 'MarkerSize', 5, ...
    'Color', col_Phi, 'MarkerFaceColor', col_Phi, 'DisplayName', 'cv-R²');

xline(sensitivity.best_quantile*100, 'r--', 'LineWidth', 2);

xlabel('\Phi_{crit} Quantile (%)', 'FontWeight', 'bold');
ylabel('Skill (R²)', 'FontWeight', 'bold');
title(sprintf('(d) Threshold Selection (optimal: %.0f%%)', ...
    sensitivity.best_quantile*100), 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'southwest', 'FontSize', 10);
ylim([0 1]);

% Save Figure 3
exportgraphics(fig3, fullfile(OutputDir, 'Figure_PhiProxy_Combined.png'), ...
    'Resolution', 300);
fprintf('Saved: Figure_PhiProxy_Combined.png\n');

%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n========================================\n');
fprintf('FIGURE GENERATION COMPLETE\n');
fprintf('========================================\n');
fprintf('Output directory: %s\n', OutputDir);
fprintf('Files created:\n');
fprintf('  - Figure_PhiProxy_TimeSeries.png\n');
fprintf('  - Figure_PhiProxy_ElevationVsFlux.png (TBR23-style comparison)\n');
fprintf('  - Figure_PhiProxy_Scatter.png\n');
fprintf('  - Figure_PhiProxy_Combined.png\n');
fprintf('========================================\n');
