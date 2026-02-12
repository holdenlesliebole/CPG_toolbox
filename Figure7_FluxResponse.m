%% FIGURE 7: Flux–Response Relationship & F³ Model Skill
% Shows nonlinear cubic scaling between energy flux and morphological response
% Scatter: ΔZ vs F and ΔZ vs F³, plus time series model skill
%
% REQUIRES: PhiProxyResults.mat (from PhiProxyAnalysis.m)
%
% Holden Leslie-Bole, 2026

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox
addpath /Users/holden/Documents/Scripps/Research/toolbox/PhiProxy

%% USER SETTINGS
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

ResultsFile = fullfile(OutputDir, 'PhiProxyResults.mat');

%% LOAD REAL DATA
if ~exist(ResultsFile, 'file')
    error('Results file not found: %s\nRun PhiProxyAnalysis.m first.', ResultsFile);
end

fprintf('Loading results from %s...\n', ResultsFile);
load(ResultsFile, 'PhiResults');

% Unpack wave/flux data
t_wave = PhiResults.wave.t;
Fb = PhiResults.wave.Fb;           % Bottom energy flux (W/m)
Phi = PhiResults.wave.Phi;          % Thresholded Φ proxy
PhiCum = PhiResults.wave.PhiCum;    % Cumulative Φ

% Unpack survey data
SurveyDates = PhiResults.survey.dates;
delta_z = PhiResults.survey.delta_z;       % Between-survey elevation change (m)
delta_z_err = PhiResults.survey.delta_z_err;

% Unpack interval-integrated values
PhiSum = PhiResults.intervals.PhiSum;      % Integrated Φ between surveys
FbSum = PhiResults.intervals.FbSum;        % Integrated Fb between surveys

% Unpack threshold and config
F_threshold = PhiResults.threshold.best_crit;  % Optimal threshold (W/m)
exponent = PhiResults.config.exponent;          % Power law exponent (typically 3)
depth_band = PhiResults.config.depth_band;

% Date range from config
DateStart = datenum(PhiResults.config.DateStart);
DateEnd = datenum(PhiResults.config.DateEnd);

% Convert wave times to datenum for plotting
if isdatetime(t_wave)
    t_wave_num = datenum(t_wave);
else
    t_wave_num = t_wave;
end

% Convert survey dates to datenum
if isdatetime(SurveyDates)
    SurveyDates_num = datenum(SurveyDates);
else
    SurveyDates_num = SurveyDates;
end

% Midpoint dates for interval data (between-survey changes)
MidDates = (SurveyDates_num(1:end-1) + SurveyDates_num(2:end)) / 2;

fprintf('Loaded %d wave observations and %d survey intervals\n', ...
    length(Fb), length(delta_z));
fprintf('Energy flux threshold: %.1f W/m\n', F_threshold);
fprintf('Depth band: %.0f to %.0f m\n', depth_band(1), depth_band(2));

%% COMPUTE MODEL PREDICTIONS
% Model: Δz ∝ ΣΦ where Φ = max(0, Fb - Fc)^n

% Fit linear model: delta_z = a * PhiSum + b
valid_idx = isfinite(PhiSum) & isfinite(delta_z);
if sum(valid_idx) >= 3
    p_model = polyfit(PhiSum(valid_idx), delta_z(valid_idx), 1);
    a_model = p_model(1);
    b_model = p_model(2);
    dz_model = polyval(p_model, PhiSum);
    
    % Compute R²
    residuals_fit = delta_z(valid_idx) - polyval(p_model, PhiSum(valid_idx));
    ss_res = sum(residuals_fit.^2);
    ss_tot = sum((delta_z(valid_idx) - nanmean(delta_z(valid_idx))).^2);
    R2 = 1 - (ss_res / ss_tot);
else
    error('Not enough valid data points for model fitting');
end

fprintf('Model fit: Δz = %.2e × ΣΦ + %.3f (R² = %.3f)\n', a_model, b_model, R2);

%% CREATE FIGURE
fig = figure('position', [100 100 1500 1000]);

%% PANEL A: SCATTER Δz vs Σ(Fb) (Shows Threshold Effect)
ax1 = subplot(2, 3, 1);
hold on; box on; grid on;

% Plot integrated flux vs observed elevation change
valid = isfinite(FbSum) & isfinite(delta_z);
s1 = scatter(FbSum(valid)/1e6, delta_z(valid)*100, 80, 'o', ...
    'MarkerFaceColor', [0.2 0.6 1.0], 'MarkerEdgeColor', 'blue', 'linewidth', 1.5, ...
    'DisplayName', 'Survey intervals');

% Add error bars for delta_z
for i = find(valid)'
    plot([FbSum(i)/1e6, FbSum(i)/1e6], [delta_z(i)-delta_z_err(i), delta_z(i)+delta_z_err(i)]*100, ...
        'b-', 'linewidth', 1, 'HandleVisibility', 'off');
end

set(ax1, 'fontsize', 11, 'linewidth', 1.5);
xlabel('Integrated Energy Flux $\Sigma F_b$ (MJ/m)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
ylabel('Elevation Change $\Delta z$ (cm)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
title('(a) $\Delta z$ vs Integrated Flux', 'fontsize', 13, 'fontweight', 'bold', 'Interpreter', 'latex');
legend(s1, 'location', 'best', 'fontsize', 10);

%% PANEL B: SCATTER Δz vs Σ(Φ) - Thresholded (Linear Relationship)
ax2 = subplot(2, 3, 2);
hold on; box on; grid on;

% Active intervals (where Φ > 0)
active_intervals = PhiSum > 0 & isfinite(delta_z);

% Plot all points
s2_inactive = scatter(PhiSum(~active_intervals & valid), delta_z(~active_intervals & valid)*100, 60, 'o', ...
    'MarkerFaceColor', [0.7 0.7 0.7], 'MarkerEdgeColor', 'black', 'linewidth', 1.5, ...
    'DisplayName', sprintf('$\\Sigma\\Phi$ = 0 (below threshold)', F_threshold));
s2_active = scatter(PhiSum(active_intervals), delta_z(active_intervals)*100, 80, 's', ...
    'MarkerFaceColor', [1.0 0.4 0.2], 'MarkerEdgeColor', 'red', 'linewidth', 1.5, ...
    'DisplayName', '$\Sigma\Phi$ > 0 (active)');

% Add regression line
PhiSum_range = linspace(0, max(PhiSum(valid))*1.1, 100);
dz_fit_line = polyval(p_model, PhiSum_range) * 100;  % Convert to cm
p_fit = plot(PhiSum_range, dz_fit_line, 'r-', 'linewidth', 2.5, ...
    'DisplayName', sprintf('Linear fit (R² = %.2f)', R2));

% R² annotation
text(max(PhiSum(valid))*0.5, max(delta_z(valid))*100*0.9, ...
    sprintf('R² = %.3f', R2), 'fontsize', 12, 'fontweight', 'bold', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black', 'Margin', 4);

set(ax2, 'fontsize', 11, 'linewidth', 1.5);
xlabel('Integrated $\Phi$ (thresholded $F_b^3$)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
ylabel('Elevation Change $\Delta z$ (cm)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
title(sprintf('(b) $\\Delta z$ vs $\\Sigma\\Phi$ (n=%d)', exponent), 'fontsize', 13, 'fontweight', 'bold', 'Interpreter', 'latex');
legend([s2_active, p_fit], 'location', 'northwest', 'fontsize', 10, 'Interpreter', 'latex');

%% PANEL C: THRESHOLD SENSITIVITY
ax3 = subplot(2, 3, 3);
hold on; box on; grid on;

% Plot threshold sensitivity curve if available
if isfield(PhiResults.threshold, 'sensitivity')
    sens = PhiResults.threshold.sensitivity;
    if isstruct(sens) && isfield(sens, 'quantiles') && isfield(sens, 'R2')
        plot(sens.quantiles*100, sens.R2, 'b.-', 'linewidth', 2, 'markersize', 15);
        
        % Mark optimal threshold
        [~, best_idx] = max(sens.R2);
        plot(sens.quantiles(best_idx)*100, sens.R2(best_idx), 'ro', ...
            'markersize', 15, 'markerfacecolor', 'red', 'linewidth', 2);
        
        xlabel('Threshold Quantile (\%)', 'fontsize', 12, 'fontweight', 'bold');
        ylabel('Cross-validated R²', 'fontsize', 12, 'fontweight', 'bold');
        title('(c) Threshold Sensitivity', 'fontsize', 13, 'fontweight', 'bold');
        text(sens.quantiles(best_idx)*100 + 2, sens.R2(best_idx), ...
            sprintf('Optimal: %.0f%%\n(F_c = %.0f W/m)', sens.quantiles(best_idx)*100, F_threshold), ...
            'fontsize', 10, 'fontweight', 'bold');
    end
else
    % Fallback: histogram of energy flux with threshold marked
    histogram(Fb(isfinite(Fb))/1000, 50, 'FaceColor', [0.5 0.7 0.9], 'EdgeColor', 'none');
    xline(F_threshold/1000, 'r--', 'linewidth', 2.5);
    xlabel('Energy Flux F_b (kW/m)', 'fontsize', 12, 'fontweight', 'bold');
    ylabel('Count', 'fontsize', 12, 'fontweight', 'bold');
    title(sprintf('(c) Flux Distribution (F_c = %.0f W/m)', F_threshold), 'fontsize', 13, 'fontweight', 'bold');
end

set(ax3, 'fontsize', 11, 'linewidth', 1.5);

%% PANEL D: TIME SERIES - Energy Flux and Cumulative Φ
ax4 = subplot(2, 3, [4, 5]);
hold on; box on; grid on;

% Energy flux time series (left axis)
yyaxis left
p_flux = plot(t_wave_num, Fb/1000, '-', 'linewidth', 1, 'Color', [0.2 0.5 0.8 0.6], ...
    'DisplayName', 'Energy flux F_b');
ylabel('Energy Flux F_b (kW/m)', 'fontsize', 12, 'fontweight', 'bold');
set(gca, 'YColor', [0.2 0.5 0.8]);

% Threshold line
yline(F_threshold/1000, 'r--', 'linewidth', 1.5, 'HandleVisibility', 'off');

% Cumulative Φ (right axis)
yyaxis right
p_phi = plot(t_wave_num, PhiCum, '-', 'linewidth', 2, 'Color', [0.85 0.35 0.15], ...
    'DisplayName', 'Cumulative \Phi');
ylabel('Cumulative $\Phi$', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
set(gca, 'YColor', [0.85 0.35 0.15]);

% Mark survey dates
for i = 1:length(SurveyDates_num)
    xline(SurveyDates_num(i), 'k--', 'linewidth', 0.8, 'HandleVisibility', 'off');
end

set(ax4, 'fontsize', 11, 'linewidth', 1.5);
xlabel('Date', 'fontsize', 12, 'fontweight', 'bold');
title('(d) Energy Flux \& Cumulative \Phi Time Series', 'fontsize', 13, 'fontweight', 'bold');
set(ax4, 'xlim', [DateStart, DateEnd]);
datetick('x', 'mmm', 'keepticks');
legend([p_flux, p_phi], 'location', 'northwest', 'fontsize', 10);

%% PANEL E: OBSERVED vs MODEL RESIDUALS
ax5 = subplot(2, 3, 6);
hold on; box on; grid on;

% Compute residuals for survey intervals
residuals = delta_z(valid_idx) - dz_model(valid_idx);
std_resid = nanstd(residuals);
rmse = sqrt(nanmean(residuals.^2));

% Scatter: observed vs modeled
s_resid = scatter(dz_model(valid_idx)*100, delta_z(valid_idx)*100, 80, 'o', ...
    'MarkerFaceColor', [0.2 0.7 0.3], 'MarkerEdgeColor', 'black', 'linewidth', 1.5, ...
    'DisplayName', 'Survey intervals');

% 1:1 line
dz_range = [min([delta_z; dz_model])*100, max([delta_z; dz_model])*100];
p_11 = plot(dz_range, dz_range, 'k--', 'linewidth', 2, 'DisplayName', '1:1 line');

% Error bars
for i = find(valid_idx)'
    plot([dz_model(i)*100, dz_model(i)*100], ...
        [delta_z(i)-delta_z_err(i), delta_z(i)+delta_z_err(i)]*100, ...
        'g-', 'linewidth', 1, 'HandleVisibility', 'off');
end

% Skill metrics annotation
text(dz_range(1)*0.9, dz_range(2)*0.9, ...
    sprintf('R² = %.2f\nRMSE = %.1f cm', R2, rmse*100), ...
    'fontsize', 11, 'fontweight', 'bold', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black', 'Margin', 4);

set(ax5, 'fontsize', 11, 'linewidth', 1.5);
xlabel('Modeled $\Delta z$ (cm)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
ylabel('Observed $\Delta z$ (cm)', 'fontsize', 12, 'fontweight', 'bold', 'Interpreter', 'latex');
title('(e) Model Skill: Observed vs Modeled', 'fontsize', 13, 'fontweight', 'bold');
axis equal;
legend([s_resid, p_11], 'location', 'northwest', 'fontsize', 10);

%% OVERALL TITLE
sgtitle(sprintf('Figure 7: Flux–Response Relationship (Depth Band: %.0f to %.0f m)', ...
    abs(depth_band(2)), abs(depth_band(1))), 'fontsize', 18, 'fontweight', 'bold');

%% ADD INTERPRETATION BOX
ax_info = axes('position', [0.08 0.02 0.84 0.08], 'visible', 'off');
info_text = {
    sprintf('Depth band: %.0f to %.0f m NAVD88 | Threshold: F_c = %.0f W/m | Exponent: n = %d', ...
        depth_band(1), depth_band(2), F_threshold, exponent);
    sprintf('Model: Δz = a × Σ[max(0, F_b - F_c)^n] | R² = %.2f | RMSE = %.1f cm', R2, rmse*100);
    'Physical mechanism: Shoaling waves → acceleration skewness → onshore bedload transport above critical threshold.'
};

text(0.5, 0.5, info_text, 'fontsize', 9, 'horizontalalignment', 'center', ...
    'verticalalignment', 'middle', 'parent', ax_info, 'FontName', 'Courier', ...
    'BackgroundColor', 'yellow', 'EdgeColor', 'black', 'Margin', 5);

%% SAVE
set(gcf, 'position', [100 100 1500 1000]);
exportgraphics(gcf, fullfile(OutputDir, 'Figure_7_FluxResponse.png'), 'Resolution', 300);
fprintf('Saved Figure 7: %s\n', fullfile(OutputDir, 'Figure_7_FluxResponse.png'));

fprintf('\n=== FIGURE 7: FLUX-RESPONSE MODEL SUMMARY ===\n');
fprintf('Data source: PhiProxyResults.mat\n');
fprintf('Depth band: %.0f to %.0f m NAVD88\n', depth_band(1), depth_band(2));
fprintf('Survey intervals: %d\n', sum(valid_idx));
fprintf('✓ Threshold: F_c = %.0f W/m (%.1f kW/m)\n', F_threshold, F_threshold/1000);
fprintf('✓ Exponent: n = %d\n', exponent);
fprintf('✓ R² = %.3f\n', R2);
fprintf('✓ RMSE = %.2f cm\n', rmse*100);
fprintf('✓ Physical mechanism: Shoaling → skewness → selective transport\n');
