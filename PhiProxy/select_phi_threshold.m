function [best_crit, sensitivity] = select_phi_threshold(Fb, t_wave, t_survey, delta_z, varargin)
%SELECT_PHI_THRESHOLD Objectively select Φcrit via cross-validation
%
%   [best_crit, sensitivity] = SELECT_PHI_THRESHOLD(Fb, t_wave, t_survey, delta_z)
%
%   Selects the optimal Φcrit threshold by testing candidates across
%   percentiles of F³ and maximizing cross-validated skill against observed
%   bed elevation change.
%
%   INPUTS:
%       Fb          - Energy flux time series (W/m), [Nt x 1]
%       t_wave      - Wave time vector, datetime or datenum [Nt x 1]
%       t_survey    - Survey times, datetime or datenum [Ns x 1]
%       delta_z     - Observed bed elevation change (m), [Ns-1 x 1]
%
%   OPTIONAL NAME-VALUE PAIRS:
%       'quantiles'   - Quantile range to test (default: 0.50:0.05:0.95)
%       'exponent'    - Power law exponent (default: 3)
%       'metric'      - Optimization metric: 'R2', 'cv_R2', 'r' (default: 'cv_R2')
%       'dt_hours'    - Time step (hours), default: inferred
%       'min_coverage'- Minimum coverage per interval (default: 0.5)
%
%   OUTPUTS:
%       best_crit   - Optimal threshold [(W/m)^n]
%       sensitivity - Structure with:
%                     .quantiles - tested quantile values
%                     .thresholds - corresponding Φcrit values
%                     .R2, .cv_R2, .r, .RMSE - skill at each threshold
%                     .best_quantile - optimal quantile
%                     .best_idx - index of best threshold
%
%   Based on phi_proxy_pipeline_spec.md §6.1 and §6.3
%
%   See also: compute_phi, integrate_between_surveys, fit_and_score_phi
%
%   Holden Leslie-Bole, January 2026

%% Parse inputs
p = inputParser;
addRequired(p, 'Fb', @isnumeric);
addRequired(p, 't_wave');
addRequired(p, 't_survey');
addRequired(p, 'delta_z', @isnumeric);
addParameter(p, 'quantiles', 0.50:0.05:0.95, @isnumeric);
addParameter(p, 'exponent', 3, @isnumeric);
addParameter(p, 'metric', 'cv_R2', @ischar);
addParameter(p, 'dt_hours', [], @isnumeric);
addParameter(p, 'min_coverage', 0.5, @isnumeric);
parse(p, Fb, t_wave, t_survey, delta_z, varargin{:});

quantiles = p.Results.quantiles(:);
n_exp = p.Results.exponent;
metric = p.Results.metric;
dt_hours = p.Results.dt_hours;
min_coverage = p.Results.min_coverage;

%% Compute F^n and candidate thresholds
Fb = Fb(:);
Fb_n = Fb.^n_exp;

% Remove non-finite values for quantile calculation
Fb_n_valid = Fb_n(isfinite(Fb_n));

% Candidate thresholds from quantiles
n_candidates = length(quantiles);
thresholds = quantile(Fb_n_valid, quantiles);

%% Preallocate skill arrays
R2_arr = NaN(n_candidates, 1);
cv_R2_arr = NaN(n_candidates, 1);
r_arr = NaN(n_candidates, 1);
RMSE_arr = NaN(n_candidates, 1);

%% Test each threshold
fprintf('Testing %d threshold candidates...\n', n_candidates);

for c = 1:n_candidates
    PhiCrit = thresholds(c);
    
    % Compute Φ with this threshold
    [Phi, ~] = compute_phi(Fb, PhiCrit, 'exponent', n_exp);
    
    % Integrate between surveys
    [PhiSum, FbSum, ~] = integrate_between_surveys(Phi, Fb, t_wave, t_survey, ...
        'dt_hours', dt_hours, 'min_coverage', min_coverage);
    
    % Fit and score (suppress output during loop)
    warning('off', 'all');
    [results, ~] = fit_and_score_phi(PhiSum, FbSum, delta_z, 'cv_method', 'loio');
    warning('on', 'all');
    
    % Store results
    if isfield(results, 'phi')
        R2_arr(c) = results.phi.R2;
        cv_R2_arr(c) = results.phi.cv_R2;
        r_arr(c) = results.phi.r;
        RMSE_arr(c) = results.phi.RMSE;
    end
end

%% Select best threshold based on metric
switch lower(metric)
    case 'cv_r2'
        [~, best_idx] = max(cv_R2_arr);
    case 'r2'
        [~, best_idx] = max(R2_arr);
    case 'r'
        [~, best_idx] = max(r_arr);
    case 'rmse'
        [~, best_idx] = min(RMSE_arr);
    otherwise
        error('Unknown metric: %s', metric);
end

best_crit = thresholds(best_idx);
best_quantile = quantiles(best_idx);

%% Package sensitivity output
sensitivity = struct(...
    'quantiles', quantiles, ...
    'thresholds', thresholds, ...
    'R2', R2_arr, ...
    'cv_R2', cv_R2_arr, ...
    'r', r_arr, ...
    'RMSE', RMSE_arr, ...
    'best_quantile', best_quantile, ...
    'best_idx', best_idx, ...
    'best_crit', best_crit, ...
    'exponent', n_exp, ...
    'metric', metric);

%% Print results
fprintf('\n=== THRESHOLD SELECTION RESULTS ===\n');
fprintf('Search range: %.0f%% to %.0f%% quantiles of F^%d\n', ...
    min(quantiles)*100, max(quantiles)*100, n_exp);
fprintf('Optimal threshold: %.4e (q = %.0f%%)\n', best_crit, best_quantile*100);
fprintf('Optimal %s: %.3f\n', upper(metric), sensitivity.(metric)(best_idx));
fprintf('====================================\n\n');

end
