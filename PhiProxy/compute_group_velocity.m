function [Cg, C, n] = compute_group_velocity(f, h, method)
%COMPUTE_GROUP_VELOCITY Compute group velocity for linear surface gravity waves
%
%   [Cg, C, n] = COMPUTE_GROUP_VELOCITY(f, h)
%   [Cg, C, n] = COMPUTE_GROUP_VELOCITY(f, h, method)
%
%   Computes group velocity Cg, phase velocity C, and the ratio n = Cg/C
%   for linear surface gravity waves at specified frequency and depth.
%
%   INPUTS:
%       f       - Wave frequency (Hz), can be vector [Nf x 1] or [1 x Nf]
%       h       - Water depth (m), scalar
%       method  - (optional) 'robust' (Newton-Raphson, default) or 'wu' (C.S. Wu approx)
%
%   OUTPUTS:
%       Cg      - Group velocity (m/s), same size as f
%       C       - Phase velocity (m/s), same size as f
%       n       - Cg/C ratio (dimensionless), same size as f
%
%   THEORY:
%       For linear waves, group velocity is:
%           Cg = (1/2)*C*(1 + 2*k*h/sinh(2*k*h))
%       where C = omega/k is the phase velocity.
%       
%       In deep water (kh >> 1): Cg ≈ C/2
%       In shallow water (kh << 1): Cg ≈ C ≈ sqrt(g*h)
%
%   Based on phi_proxy_pipeline_spec.md §3.1
%
%   See also: dispersion_k_robust, LinearDispersion
%
%   Holden Leslie-Bole, January 2026

if nargin < 3
    method = 'robust';
end

g = 9.81;

% Handle frequency input
f = f(:);  % Ensure column vector
Nf = length(f);

% Preallocate outputs
Cg = NaN(size(f));
C = NaN(size(f));
n = NaN(size(f));

for j = 1:Nf
    if ~isfinite(f(j)) || f(j) <= 0 || ~isfinite(h) || h <= 0
        continue
    end
    
    omega = 2*pi*f(j);
    
    % Solve for wavenumber
    switch lower(method)
        case 'robust'
            k = dispersion_k_robust(omega, h);
        case 'wu'
            % C.S. Wu approximation (faster but less robust)
            a = 4.0243*h*f(j)^2;
            yhat = a*(1 + 1.26*exp(-1.84*a));
            t = exp(-2*yhat);
            if a >= 1
                aka = a*(1 + 2*t*(1 + t));
            else
                aka = sqrt(a)*(1 + (a/6)*(1 + a/5));
            end
            k = abs(aka/h);
        otherwise
            error('Unknown method: %s. Use ''robust'' or ''wu''.', method);
    end
    
    if ~isfinite(k) || k <= 0
        continue
    end
    
    % Phase velocity
    C(j) = omega/k;
    
    % Group velocity
    kh = k*h;
    if kh > 50
        % Deep water limit
        n(j) = 0.5;
    else
        n(j) = 0.5*(1 + 2*kh/sinh(2*kh));
    end
    Cg(j) = n(j)*C(j);
end

end
