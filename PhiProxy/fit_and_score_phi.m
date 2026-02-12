function [results, best_model] = fit_and_score_phi(PhiSum, FbSum, delta_z, varargin)
%FIT_AND_SCORE_PHI Fit regression models and compute skill metrics for Φ proxy
%
%   [results, best_model] = FIT_AND_SCORE_PHI(PhiSum, FbSum, delta_z)
%
%   Fits linear regression between integrated Φ (and null predictors) and
%   observed bed elevation change, computing comprehensive skill metrics.
%
%   INPUTS:
%       PhiSum      - Integrated Φ proxy for each interval [(W/m)^n·hours], [Ni x 1]
%       FbSum       - Integrated Fb for each interval [W·hours/m], [Ni x 1]
%       delta_z     - Observed bed elevation change (m), [Ni x 1]
%
%   OPTIONAL NAME-VALUE PAIRS:
%       'n_bootstrap' - Number of bootstrap iterations (default: 1000)
%       'alpha'       - Significance level for CIs (default: 0.05)
%       'cv_method'   - Cross-validation: 'loio' (leave-one-interval-out) 
%                       or 'none' (default: 'loio')
%
%   OUTPUTS:
%       results     - Structure with skill metrics for each model:
%                     .phi - Φ proxy model results
%                     .fb  - Fb (null) model results  
%                     .fb3 - Fb³ unthresholded (null) model results
%                     Each contains:
%                       .r, .R2, .RMSE, .MAE - skill metrics
%                       .p - regression coefficients [slope, intercept]
%                       .p_CI - 95% CI on coefficients
%                       .sign_accuracy - fraction with correct sign
%                       .cv_R2 - cross-validated R²
%
%       best_model  - Structure with best model parameters:
%                     .name - 'phi', 'fb', or 'fb3'
%                     .R2, .cv_R2, etc.
%
%   Based on phi_proxy_pipeline_spec.md §7
%
%   See also: integrate_between_surveys, select_phi_threshold
%
%   Holden Leslie-Bole, January 2026

%% Parse inputs
p = inputParser;
addRequired(p, 'PhiSum', @isnumeric);
addRequired(p, 'FbSum', @isnumeric);
addRequired(p, 'delta_z', @isnumeric);
addParameter(p, 'n_bootstrap', 1000, @isnumeric);
addParameter(p, 'alpha', 0.05, @isnumeric);
addParameter(p, 'cv_method', 'loio', @ischar);
parse(p, PhiSum, FbSum, delta_z, varargin{:});

n_boot = p.Results.n_bootstrap;
alpha = p.Results.alpha;
cv_method = p.Results.cv_method;

%% Ensure column vectors
PhiSum = PhiSum(:);
FbSum = FbSum(:);
delta_z = delta_z(:);

%% Find valid data
valid = isfinite(PhiSum) & isfinite(FbSum) & isfinite(delta_z);
Nvalid = sum(valid);

if Nvalid < 3
    warning('Insufficient valid data points (%d) for regression', Nvalid);
    results = struct();
    best_model = struct();
    return
end

%% Define predictors
predictors = struct();
predictors.phi = PhiSum(valid);
predictors.fb = FbSum(valid);
predictors.fb3 = FbSum(valid).^3;  % Unthresholded F^3

response = delta_z(valid);

%% Fit each model
model_names = fieldnames(predictors);
results = struct();

for m = 1:length(model_names)
    name = model_names{m};
    X = predictors.(name);
    
    % Basic linear regression
    [p_fit, S] = polyfit(X, response, 1);
    y_hat = polyval(p_fit, X);
    
    % Skill metrics
    r = corr(X, response, 'rows', 'complete');
    ss_res = sum((response - y_hat).^2);
    ss_tot = sum((response - mean(response)).^2);
    R2 = 1 - ss_res/ss_tot;
    RMSE = sqrt(mean((response - y_hat).^2));
    MAE = mean(abs(response - y_hat));
    
    % Sign accuracy (after centering)
    y_centered = response - mean(response);
    y_hat_centered = y_hat - mean(y_hat);
    sign_acc = mean(sign(y_centered) == sign(y_hat_centered));
    
    % Bootstrap confidence intervals on slope
    boot_slopes = NaN(n_boot, 1);
    boot_intercepts = NaN(n_boot, 1);
    for b = 1:n_boot
        idx = randi(Nvalid, Nvalid, 1);
        p_boot = polyfit(X(idx), response(idx), 1);
        boot_slopes(b) = p_boot(1);
        boot_intercepts(b) = p_boot(2);
    end
    slope_CI = quantile(boot_slopes, [alpha/2, 1-alpha/2]);
    intercept_CI = quantile(boot_intercepts, [alpha/2, 1-alpha/2]);
    
    % Cross-validation (LOIO)
    if strcmpi(cv_method, 'loio') && Nvalid >= 5
        cv_pred = NaN(Nvalid, 1);
        for i = 1:Nvalid
            train_idx = true(Nvalid, 1);
            train_idx(i) = false;
            p_cv = polyfit(X(train_idx), response(train_idx), 1);
            cv_pred(i) = polyval(p_cv, X(i));
        end
        cv_ss_res = sum((response - cv_pred).^2);
        cv_R2 = 1 - cv_ss_res/ss_tot;
    else
        cv_R2 = NaN;
    end
    
    % Store results
    results.(name) = struct(...
        'r', r, ...
        'R2', R2, ...
        'RMSE', RMSE, ...
        'MAE', MAE, ...
        'p', p_fit, ...
        'p_CI', [slope_CI; intercept_CI], ...
        'sign_accuracy', sign_acc, ...
        'cv_R2', cv_R2, ...
        'n_valid', Nvalid, ...
        'X', X, ...
        'y', response, ...
        'y_hat', y_hat);
end

%% Determine best model based on cv_R2 (or R2 if CV not available)
best_cv_R2 = -Inf;
best_name = '';

for m = 1:length(model_names)
    name = model_names{m};
    if isfinite(results.(name).cv_R2) && results.(name).cv_R2 > best_cv_R2
        best_cv_R2 = results.(name).cv_R2;
        best_name = name;
    elseif ~isfinite(results.(name).cv_R2) && results.(name).R2 > best_cv_R2
        best_cv_R2 = results.(name).R2;
        best_name = name;
    end
end

best_model = results.(best_name);
best_model.name = best_name;

%% Print summary
fprintf('\n=== PHI PROXY SKILL ASSESSMENT ===\n');
fprintf('%-12s | %8s | %8s | %8s | %8s | %8s\n', ...
    'Model', 'r', 'R²', 'cv_R²', 'RMSE', 'Sign Acc');
fprintf('%s\n', repmat('-', 1, 65));

for m = 1:length(model_names)
    name = model_names{m};
    res = results.(name);
    fprintf('%-12s | %8.3f | %8.3f | %8.3f | %8.4f | %8.1f%%\n', ...
        upper(name), res.r, res.R2, res.cv_R2, res.RMSE, res.sign_accuracy*100);
end

fprintf('%s\n', repmat('-', 1, 65));
fprintf('Best model: %s (cv_R² = %.3f)\n', upper(best_name), best_cv_R2);
fprintf('Regression: Δz = %.2e × %s + %.4f m\n', ...
    best_model.p(1), upper(best_name), best_model.p(2));
fprintf('==================================\n\n');

end
