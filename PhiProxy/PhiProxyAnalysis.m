%% PHI PROXY ANALYSIS: Bottom Energy Flux → Morphological Response
% Comprehensive pipeline for Φ transport proxy computation and validation
%
% This script implements the full Φ proxy analysis pipeline as specified in
% phi_proxy_pipeline_spec.md, computing bottom energy flux from MOP wave data
% and relating it to between-survey bed elevation changes.
%
% OUTPUTS:
%   1. PhiProxyResults.mat - All computed data products
%   2. Diagnostic console output with skill metrics
%   3. Figures (via Figure_PhiProxy.m)
%
% Holden Leslie-Bole, January 2026

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox
addpath /Users/holden/Documents/Scripps/Research/toolbox/PhiProxy

%% ========================================================================
%  USER CONFIGURATION
%  ========================================================================

% --- Survey/Morphology Settings ---
mpath = '/volumes/group/MOPS/';  % Path to MOPS data
MopStart = 576;                   % Start MOP (alongshore extent)
MopEnd = 589;                     % End MOP
MopWave = 582;                    % MOP for wave data (center of reach)

% --- Time Range ---
DateStart = datetime(2023, 4, 1);
DateEnd = datetime(2023, 12, 31);

% --- Depth Band for Analysis ---
% Define the depth band where we expect wave-driven transport
% UPDATED (2026-01-29): Inspired by TBR23MeanElevChange.png which shows
% the red dashed curve (cumulative E_flux³) closely tracks 4-5m depth band
% This is the optimal energy flux response zone at Torrey Pines
depth_band = [-5, -4];  % [z_min, z_max] in m NAVD88 (4-5m depth band)

% --- Wave Flux Computation Settings ---
analysis_depth = 5;  % Depth (m) at which to evaluate energy flux
freq_bands = struct('IG', [0.004 0.04], 'SS', [0.04 0.12], 'SEA', [0.12 0.25]);

% --- Threshold Selection ---
quantile_range = 0.50:0.05:0.95;  % Quantiles to test
exponent = 3;                      % Power law exponent for Φ = max(0, F^n - Fcrit)

% --- Output ---
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

SaveResults = true;
ResultsFile = fullfile(OutputDir, 'PhiProxyResults.mat');

%% ========================================================================
%  LOAD SURVEY DATA
%  ========================================================================

fprintf('\n========================================\n');
fprintf('PHI PROXY ANALYSIS PIPELINE\n');
fprintf('========================================\n\n');

fprintf('Loading survey data for MOPs %d-%d...\n', MopStart, MopEnd);
SG = CombineSGdata(mpath, MopStart, MopEnd);

% Identify jetski (deep) surveys
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

% Sort by date
[~, sort_idx] = sort([SG(jetski).Datenum]);
jetski = jetski(sort_idx);

SurveyDates = datetime([SG(jetski).Datenum], 'ConvertFrom', 'datenum');
Nsurveys = length(jetski);

fprintf('Found %d jetski surveys from %s to %s\n', ...
    Nsurveys, datestr(min(SurveyDates)), datestr(max(SurveyDates)));

%% ========================================================================
%  COMPUTE BED ELEVATION CHANGE IN TARGET DEPTH BAND
%  ========================================================================

fprintf('\nComputing bed elevation changes in depth band [%.0f, %.0f] m...\n', ...
    depth_band(1), depth_band(2));

% Reference survey (first)
z_ref = SG(jetski(1)).Z;
x_ref = SG(jetski(1)).X;
y_ref = SG(jetski(1)).Y;

% Identify points in target depth band (in reference survey)
in_band_ref = z_ref >= depth_band(1) & z_ref <= depth_band(2);
fprintf('Reference survey: %d points in depth band (%.1f%% of total)\n', ...
    sum(in_band_ref), 100*sum(in_band_ref)/length(z_ref));

% Compute mean elevation in depth band for each survey
z_mean_band = NaN(Nsurveys, 1);
z_std_band = NaN(Nsurveys, 1);
n_points_band = NaN(Nsurveys, 1);

for n = 1:Nsurveys
    z_n = SG(jetski(n)).Z;
    
    % Use the depth band based on the current survey's elevations
    in_band = z_n >= depth_band(1) & z_n <= depth_band(2);
    
    if sum(in_band) > 10
        z_mean_band(n) = mean(z_n(in_band), 'omitnan');
        z_std_band(n) = std(z_n(in_band), 'omitnan');
        n_points_band(n) = sum(in_band);
    end
end

% Compute between-survey elevation change
delta_z = diff(z_mean_band);
delta_z_err = sqrt(z_std_band(1:end-1).^2 + z_std_band(2:end).^2) ./ ...
              sqrt(min(n_points_band(1:end-1), n_points_band(2:end)));

fprintf('Mean Δz: %.3f ± %.3f m\n', nanmean(delta_z), nanstd(delta_z));
fprintf('Range: %.3f to %.3f m\n', nanmin(delta_z), nanmax(delta_z));

%% ========================================================================
%  LOAD WAVE DATA FROM MOP
%  ========================================================================

MopName = sprintf('D%04d', MopWave);
fprintf('\nLoading wave data from %s...\n', MopName);

try
    MOP = read_MOPline2(MopName, DateStart, DateEnd);
    
    % Extract time and spectra
    if isdatetime(MOP.time)
        t_wave = MOP.time(:);
    else
        t_wave = datetime(MOP.time(:), 'ConvertFrom', 'datenum');
    end
    t_wave_num = datenum(t_wave);
    
    Nt_wave = length(t_wave);
    fprintf('Loaded %d wave observations from %s to %s\n', ...
        Nt_wave, datestr(min(t_wave)), datestr(max(t_wave)));
    
    % Use pre-computed energy flux from read_MOPline2 if available
    if isfield(MOP, 'EfluxXtotal') && ~isempty(MOP.EfluxXtotal)
        Fb_mop = MOP.EfluxXtotal(:);
        fprintf('Using pre-computed cross-shore energy flux (EfluxXtotal)\n');
        Fb_source = 'MOP_precomputed';
    else
        % Compute from spectra if not available
        fprintf('Computing energy flux from spectra...\n');
        Seta = MOP.spec1D;  % [Nt x Nf]
        f = MOP.frequency(:)';
        
        % Compute df from frequency bounds
        if isfield(MOP, 'fbounds')
            df = double(MOP.fbounds(2,:) - MOP.fbounds(1,:));
        else
            df = [diff(f), f(end)-f(end-1)];
        end
        
        [Fb_mop, Fb_bands] = compute_energy_flux_spectral(Seta, f, df, analysis_depth, ...
            'bands', freq_bands, 'method', 'wu');
        Fb_source = 'computed_spectral';
    end
    
    fprintf('Energy flux range: %.1f to %.1f W/m\n', nanmin(Fb_mop), nanmax(Fb_mop));
    
catch ME
    error('Failed to load wave data: %s', ME.message);
end

%% ========================================================================
%  SELECT OPTIMAL Φcrit THRESHOLD
%  ========================================================================

fprintf('\nSelecting optimal Φcrit threshold via cross-validation...\n');

[best_crit, sensitivity] = select_phi_threshold(Fb_mop, t_wave, SurveyDates, delta_z, ...
    'quantiles', quantile_range, ...
    'exponent', exponent, ...
    'metric', 'cv_R2', ...
    'min_coverage', 0.5);

%% ========================================================================
%  COMPUTE FINAL Φ WITH OPTIMAL THRESHOLD
%  ========================================================================

fprintf('\nComputing final Φ proxy with optimal threshold...\n');

[Phi, PhiCum] = compute_phi(Fb_mop, best_crit, 'exponent', exponent);

% Also compute unthresholded versions for comparison
[Phi_unthresh, PhiCum_unthresh] = compute_phi(Fb_mop, 0, 'exponent', exponent);

fprintf('Φ active fraction: %.1f%% of observations\n', 100*sum(Phi > 0)/sum(isfinite(Phi)));

%% ========================================================================
%  INTEGRATE BETWEEN SURVEYS AND EVALUATE SKILL
%  ========================================================================

fprintf('\nIntegrating between surveys and evaluating skill...\n');

[PhiSum, FbSum, interval_table] = integrate_between_surveys(Phi, Fb_mop, t_wave, SurveyDates);

% Also compute for unthresholded
[PhiSum_unthresh, ~, ~] = integrate_between_surveys(Phi_unthresh, Fb_mop, t_wave, SurveyDates);

% Final skill assessment
[results, best_model] = fit_and_score_phi(PhiSum, FbSum, delta_z);

%% ========================================================================
%  ADDITIONAL NULL MODEL COMPARISONS
%  ========================================================================

fprintf('\n=== ADDITIONAL NULL COMPARISONS ===\n');

% Null 1: Hs mean
Hs_mean = NaN(Nsurveys-1, 1);
for i = 1:Nsurveys-1
    ti_start = datenum(SurveyDates(i));
    ti_end = datenum(SurveyDates(i+1));
    idx = t_wave_num >= ti_start & t_wave_num < ti_end;
    if any(idx)
        Hs_mean(i) = nanmean(MOP.Hs(idx));
    end
end

valid_null = isfinite(Hs_mean) & isfinite(delta_z);
if sum(valid_null) >= 3
    r_Hs = corr(Hs_mean(valid_null), delta_z(valid_null));
    fprintf('Null (mean Hs): r = %.3f\n', r_Hs);
end

% Null 2: Hs^2 (energy scaling)
if sum(valid_null) >= 3
    r_Hs2 = corr(Hs_mean(valid_null).^2, delta_z(valid_null));
    fprintf('Null (mean Hs²): r = %.3f\n', r_Hs2);
end

% Null 3: Unthresholded F^3
valid_unthresh = isfinite(PhiSum_unthresh) & isfinite(delta_z);
if sum(valid_unthresh) >= 3
    r_unthresh = corr(PhiSum_unthresh(valid_unthresh), delta_z(valid_unthresh));
    fprintf('Null (F³ unthresholded): r = %.3f\n', r_unthresh);
end

fprintf('Φ proxy (thresholded): r = %.3f\n', results.phi.r);
fprintf('====================================\n\n');

%% ========================================================================
%  PACKAGE RESULTS
%  ========================================================================

PhiResults = struct();

% Configuration
PhiResults.config.MopStart = MopStart;
PhiResults.config.MopEnd = MopEnd;
PhiResults.config.MopWave = MopWave;
PhiResults.config.DateStart = DateStart;
PhiResults.config.DateEnd = DateEnd;
PhiResults.config.depth_band = depth_band;
PhiResults.config.analysis_depth = analysis_depth;
PhiResults.config.freq_bands = freq_bands;
PhiResults.config.exponent = exponent;
PhiResults.config.Fb_source = Fb_source;

% Time series data
PhiResults.wave.t = t_wave;
PhiResults.wave.Fb = Fb_mop;
PhiResults.wave.Phi = Phi;
PhiResults.wave.PhiCum = PhiCum;
PhiResults.wave.Hs = MOP.Hs(:);
if exist('Fb_bands', 'var')
    PhiResults.wave.Fb_bands = Fb_bands;
end

% Survey data
PhiResults.survey.dates = SurveyDates;
PhiResults.survey.z_mean_band = z_mean_band;
PhiResults.survey.z_std_band = z_std_band;
PhiResults.survey.n_points_band = n_points_band;
PhiResults.survey.delta_z = delta_z;
PhiResults.survey.delta_z_err = delta_z_err;

% Between-survey integration
PhiResults.intervals.PhiSum = PhiSum;
PhiResults.intervals.FbSum = FbSum;
PhiResults.intervals.PhiSum_unthresh = PhiSum_unthresh;
PhiResults.intervals.table = interval_table;

% Threshold selection
PhiResults.threshold.best_crit = best_crit;
PhiResults.threshold.sensitivity = sensitivity;

% Skill metrics
PhiResults.skill = results;
PhiResults.skill.best_model = best_model;

%% ========================================================================
%  SAVE RESULTS
%  ========================================================================

if SaveResults
    fprintf('Saving results to %s...\n', ResultsFile);
    save(ResultsFile, 'PhiResults', '-v7.3');
    fprintf('Done.\n');
end

%% ========================================================================
%  SUMMARY
%  ========================================================================

fprintf('\n========================================\n');
fprintf('PHI PROXY ANALYSIS COMPLETE\n');
fprintf('========================================\n');
fprintf('Study period: %s to %s\n', datestr(DateStart), datestr(DateEnd));
fprintf('Number of survey intervals: %d\n', Nsurveys-1);
fprintf('Depth band analyzed: [%.0f, %.0f] m\n', depth_band(1), depth_band(2));
fprintf('\nOPTIMAL MODEL:\n');
fprintf('  Φcrit = %.4e (%.0f%% quantile of F^%d)\n', ...
    best_crit, sensitivity.best_quantile*100, exponent);
fprintf('  R² = %.3f, cv_R² = %.3f\n', results.phi.R2, results.phi.cv_R2);
fprintf('  Δz = %.2e × ΣΦ + %.4f m\n', results.phi.p(1), results.phi.p(2));
fprintf('\nNEXT: Run Figure_PhiProxy.m to generate figures\n');
fprintf('========================================\n');
