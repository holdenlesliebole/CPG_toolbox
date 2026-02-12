function [Phi, PhiCum] = compute_phi(Fb, Phi_crit, varargin)
%COMPUTE_PHI Compute Φ transport proxy from energy flux
%
%   [Phi, PhiCum] = COMPUTE_PHI(Fb, Phi_crit)
%   [Phi, PhiCum] = COMPUTE_PHI(Fb, Phi_crit, 'exponent', n)
%
%   Computes the Φ onshore-transport proxy defined as:
%       Φ(t) = max(0, Fb(t)^n - Φcrit)
%
%   where the default exponent n=3 emphasizes episodic/tail events.
%
%   INPUTS:
%       Fb          - Bottom energy flux time series (W/m), [Nt x 1]
%       Phi_crit    - Activation threshold in (W/m)^n units (scalar)
%                     Use Phi_crit=0 to get unthresholded F^n proxy
%
%   OPTIONAL NAME-VALUE PAIRS:
%       'exponent'  - Power-law exponent, default 3
%       'dt'        - Time step for cumulative integration (hours), default 1
%
%   OUTPUTS:
%       Phi         - Instantaneous Φ proxy [(W/m)^n], [Nt x 1]
%       PhiCum      - Cumulative Φ over time, same units * hours
%
%   PHYSICAL INTERPRETATION (from phi_proxy_pipeline_spec.md §1):
%       - Φ is a diagnostic proxy, not a transport law
%       - Distinguishes sediment mobility from morphologically effective transport
%       - Cube suppresses weak background forcing
%       - Threshold represents minimum forcing for net bed change
%
%   DEPTH BAND CALIBRATION (Torrey Pines, TBR23 recovery):
%       - Analysis of TBR23MeanElevChange.png shows cumulative F³ tracks best
%         with 4-5m depth band (z = [-5, -4] m NAVD88)
%       - This is the primary zone of wave-driven sediment response at TP
%       - Deeper zones (5-6m, 6-7m) show delayed/damped response
%       - See also: TBR23/PlotMeanElevChange.m
%
%   UNITS NOTE:
%       Φ has units of (W/m)^3 ≈ 10^15 W³/m³ for typical coastal conditions
%       These are not physical transport units; treat Φ as a dimensionless proxy
%       or normalize before comparison.
%
%   See also: compute_energy_flux_spectral, integrate_between_surveys, fit_and_score_phi
%
%   Holden Leslie-Bole, January 2026

%% Parse inputs
p = inputParser;
addRequired(p, 'Fb', @isnumeric);
addRequired(p, 'Phi_crit', @isnumeric);
addParameter(p, 'exponent', 3, @(x) isnumeric(x) && x > 0);
addParameter(p, 'dt', 1, @(x) isnumeric(x) && x > 0);  % hours
parse(p, Fb, Phi_crit, varargin{:});

n = p.Results.exponent;
dt = p.Results.dt;

%% Ensure column vector
Fb = Fb(:);
Nt = length(Fb);

%% Compute Φ(t)
% Apply power law
Fb_n = Fb.^n;

% Apply threshold
Phi = max(0, Fb_n - Phi_crit);

% Handle NaNs in input
Phi(~isfinite(Fb)) = NaN;

%% Compute cumulative Φ
PhiCum = NaN(Nt, 1);
PhiCum(1) = 0;

for t = 2:Nt
    if isfinite(Phi(t))
        PhiCum(t) = PhiCum(t-1) + Phi(t) * dt;
    else
        PhiCum(t) = PhiCum(t-1);  % Carry forward during gaps
    end
end

end
