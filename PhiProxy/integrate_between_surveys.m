function [PhiSum, FbSum, interval_table] = integrate_between_surveys(Phi, Fb, t_wave, t_survey, varargin)
%INTEGRATE_BETWEEN_SURVEYS Integrate Φ and F between survey times
%
%   [PhiSum, FbSum, interval_table] = INTEGRATE_BETWEEN_SURVEYS(Phi, Fb, t_wave, t_survey)
%
%   Integrates the Φ transport proxy and energy flux Fb between consecutive
%   survey times to produce predictors for comparison with observed bed change.
%
%   INPUTS:
%       Phi         - Instantaneous Φ proxy time series [(W/m)^n], [Nt x 1]
%       Fb          - Energy flux time series (W/m), [Nt x 1]
%       t_wave      - Wave time vector, datetime or datenum [Nt x 1]
%       t_survey    - Survey times, datetime or datenum [Ns x 1]
%
%   OPTIONAL NAME-VALUE PAIRS:
%       'dt_hours'  - Time step in hours (default: inferred from t_wave)
%       'lag_days'  - Response lag in days (default: 0)
%       'min_coverage' - Minimum fraction of valid data in interval (default: 0.5)
%
%   OUTPUTS:
%       PhiSum      - Integrated Φ for each interval [(W/m)^n·hours], [Ns-1 x 1]
%       FbSum       - Integrated Fb for each interval [W·hours/m], [Ns-1 x 1]
%       interval_table - Table with interval details:
%                        .t_start, .t_end - interval bounds
%                        .duration_days - interval duration
%                        .PhiSum, .FbSum - integrated values
%                        .n_obs - number of valid observations
%                        .coverage - fraction of interval with data
%
%   Based on phi_proxy_pipeline_spec.md §4.2
%
%   See also: compute_phi, fit_and_score_phi
%
%   Holden Leslie-Bole, January 2026

%% Parse inputs
p = inputParser;
addRequired(p, 'Phi', @isnumeric);
addRequired(p, 'Fb', @isnumeric);
addRequired(p, 't_wave');
addRequired(p, 't_survey');
addParameter(p, 'dt_hours', [], @isnumeric);
addParameter(p, 'lag_days', 0, @isnumeric);
addParameter(p, 'min_coverage', 0.5, @isnumeric);
parse(p, Phi, Fb, t_wave, t_survey, varargin{:});

lag_days = p.Results.lag_days;
min_coverage = p.Results.min_coverage;
dt_hours = p.Results.dt_hours;

%% Convert times to datenum for consistent arithmetic
if isdatetime(t_wave)
    t_wave_num = datenum(t_wave);
else
    t_wave_num = t_wave(:);
end

if isdatetime(t_survey)
    t_survey_num = datenum(t_survey);
else
    t_survey_num = t_survey(:);
end

%% Infer time step if not provided
if isempty(dt_hours)
    dt_hours = median(diff(t_wave_num)) * 24;  % Convert days to hours
end

%% Ensure column vectors
Phi = Phi(:);
Fb = Fb(:);
t_wave_num = t_wave_num(:);
t_survey_num = sort(t_survey_num(:));

Nt = length(Phi);
Ns = length(t_survey_num);
Nintervals = Ns - 1;

%% Preallocate outputs
PhiSum = NaN(Nintervals, 1);
FbSum = NaN(Nintervals, 1);
t_start = NaT(Nintervals, 1);
t_end = NaT(Nintervals, 1);
duration_days = NaN(Nintervals, 1);
n_obs = NaN(Nintervals, 1);
coverage = NaN(Nintervals, 1);

%% Integration loop
for i = 1:Nintervals
    % Interval bounds (with optional lag)
    ti_start = t_survey_num(i) + lag_days;
    ti_end = t_survey_num(i+1) + lag_days;
    
    % Find wave indices within this interval
    idx = t_wave_num >= ti_start & t_wave_num < ti_end;
    
    if ~any(idx)
        continue
    end
    
    % Extract data for this interval
    Phi_interval = Phi(idx);
    Fb_interval = Fb(idx);
    
    % Check coverage
    n_valid_phi = sum(isfinite(Phi_interval));
    n_valid_fb = sum(isfinite(Fb_interval));
    n_total = sum(idx);
    
    interval_coverage = min(n_valid_phi, n_valid_fb) / n_total;
    
    if interval_coverage < min_coverage
        continue
    end
    
    % Integrate (sum * dt_hours)
    PhiSum(i) = nansum(Phi_interval) * dt_hours;
    FbSum(i) = nansum(Fb_interval) * dt_hours;
    
    % Store metadata
    t_start(i) = datetime(t_survey_num(i), 'ConvertFrom', 'datenum');
    t_end(i) = datetime(t_survey_num(i+1), 'ConvertFrom', 'datenum');
    duration_days(i) = t_survey_num(i+1) - t_survey_num(i);
    n_obs(i) = n_total;
    coverage(i) = interval_coverage;
end

%% Create output table
interval_table = table(t_start, t_end, duration_days, PhiSum, FbSum, n_obs, coverage, ...
    'VariableNames', {'t_start', 't_end', 'duration_days', 'PhiSum', 'FbSum', 'n_obs', 'coverage'});

end
