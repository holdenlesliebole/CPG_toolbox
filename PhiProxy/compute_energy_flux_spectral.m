function [Fb, Fb_bands] = compute_energy_flux_spectral(Seta, f, df, h, varargin)
%COMPUTE_ENERGY_FLUX_SPECTRAL Compute spectral energy flux at specified depth
%
%   Fb = COMPUTE_ENERGY_FLUX_SPECTRAL(Seta, f, df, h)
%   [Fb, Fb_bands] = COMPUTE_ENERGY_FLUX_SPECTRAL(Seta, f, df, h, 'bands', bandDef)
%
%   Computes total and band-resolved bottom energy flux from wave spectra
%   using linear theory group velocity at the specified water depth.
%
%   INPUTS:
%       Seta    - Sea surface elevation variance spectrum (m²/Hz)
%                 [Nt x Nf] matrix where Nt = time steps, Nf = frequency bins
%       f       - Frequency vector (Hz), [1 x Nf] or [Nf x 1]
%       df      - Frequency bin widths (Hz), same size as f
%       h       - Water depth (m), scalar or [Nt x 1] vector
%
%   OPTIONAL NAME-VALUE PAIRS:
%       'bands'     - Structure defining frequency bands, with fields:
%                     .IG = [f_low, f_high] for infragravity (default [0.004 0.04])
%                     .SS = [f_low, f_high] for swell (default [0.04 0.12])
%                     .SEA = [f_low, f_high] for sea (default [0.12 0.25])
%       'rho'       - Water density (kg/m³), default 1025
%       'method'    - Dispersion method: 'robust' or 'wu', default 'robust'
%
%   OUTPUTS:
%       Fb          - Total energy flux (W/m), [Nt x 1]
%       Fb_bands    - Structure with band-resolved flux:
%                     .IG, .SS, .SEA - each [Nt x 1] in W/m
%                     .total = Fb
%
%   UNITS:
%       Seta: m²/Hz
%       rho*g: N/m³ = kg/(m²·s²)
%       Cg: m/s
%       df: Hz
%       F = rho*g * sum(Cg * Seta * df) → N/(m·s) = W/m
%
%   Based on phi_proxy_pipeline_spec.md §3.1
%
%   See also: compute_group_velocity, dispersion_k_robust
%
%   Holden Leslie-Bole, January 2026

%% Parse inputs
p = inputParser;
addRequired(p, 'Seta', @isnumeric);
addRequired(p, 'f', @isnumeric);
addRequired(p, 'df', @isnumeric);
addRequired(p, 'h', @isnumeric);
addParameter(p, 'bands', struct('IG', [0.004 0.04], 'SS', [0.04 0.12], 'SEA', [0.12 0.25]));
addParameter(p, 'rho', 1025, @isnumeric);
addParameter(p, 'method', 'robust', @ischar);
parse(p, Seta, f, df, h, varargin{:});

bands = p.Results.bands;
rho = p.Results.rho;
method = p.Results.method;
g = 9.81;

%% Ensure proper dimensions
f = f(:)';  % Row vector [1 x Nf]
df = df(:)';  % Row vector [1 x Nf]
Nf = length(f);

% Handle Seta dimensions
if isvector(Seta)
    Seta = Seta(:)';  % Make row vector for single time step
    Nt = 1;
else
    [Nt, Nf_check] = size(Seta);
    if Nf_check ~= Nf
        % Try transposing
        if size(Seta, 1) == Nf
            Seta = Seta';
            [Nt, ~] = size(Seta);
        else
            error('Seta dimensions [%d x %d] do not match frequency vector length %d', ...
                size(Seta, 1), size(Seta, 2), Nf);
        end
    end
end

% Handle depth (scalar or time-varying)
if isscalar(h)
    h = h * ones(Nt, 1);
else
    h = h(:);
    if length(h) ~= Nt
        error('Depth vector length %d does not match time steps %d', length(h), Nt);
    end
end

%% Identify frequency band indices
idx_IG = f >= bands.IG(1) & f <= bands.IG(2);
idx_SS = f >= bands.SS(1) & f <= bands.SS(2);
idx_SEA = f >= bands.SEA(1) & f <= bands.SEA(2);

%% Preallocate outputs
Fb = NaN(Nt, 1);
Fb_IG = NaN(Nt, 1);
Fb_SS = NaN(Nt, 1);
Fb_SEA = NaN(Nt, 1);

%% Main computation loop
for t = 1:Nt
    % Skip if spectrum has NaNs or depth is invalid
    if any(~isfinite(Seta(t, :))) || ~isfinite(h(t)) || h(t) <= 0
        continue
    end
    
    % Compute group velocity at this depth for all frequencies
    Cg = compute_group_velocity(f, h(t), method);
    
    if any(~isfinite(Cg))
        continue
    end
    
    % Compute energy flux: F = rho*g * sum(Cg(f) * Seta(f) * df)
    flux_density = rho * g * Cg(:)' .* Seta(t, :) .* df;  % W/m per frequency bin
    
    % Total flux
    Fb(t) = sum(flux_density, 'omitnan');
    
    % Band-resolved flux
    if any(idx_IG)
        Fb_IG(t) = sum(flux_density(idx_IG), 'omitnan');
    else
        Fb_IG(t) = 0;
    end
    
    if any(idx_SS)
        Fb_SS(t) = sum(flux_density(idx_SS), 'omitnan');
    else
        Fb_SS(t) = 0;
    end
    
    if any(idx_SEA)
        Fb_SEA(t) = sum(flux_density(idx_SEA), 'omitnan');
    else
        Fb_SEA(t) = 0;
    end
end

%% Package band outputs
Fb_bands.IG = Fb_IG;
Fb_bands.SS = Fb_SS;
Fb_bands.SEA = Fb_SEA;
Fb_bands.total = Fb;
Fb_bands.f = f;
Fb_bands.idx_IG = idx_IG;
Fb_bands.idx_SS = idx_SS;
Fb_bands.idx_SEA = idx_SEA;
Fb_bands.bands = bands;

end
