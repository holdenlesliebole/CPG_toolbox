function k = dispersion_k_robust(omega, h)
%DISPERSION_K_ROBUST Robust solver for linear wave dispersion relation
%
%   k = DISPERSION_K_ROBUST(omega, h)
%
%   Solves the linear dispersion relation:
%       omega^2 = g*k*tanh(k*h)
%
%   for wavenumber k, using Newton-Raphson with bisection fallback.
%   This is more robust than the C.S. Wu approximation for extreme cases.
%
%   INPUTS:
%       omega   - Angular frequency (rad/s), can be scalar or vector
%       h       - Water depth (m), scalar
%
%   OUTPUT:
%       k       - Wavenumber (rad/m), same size as omega
%
%   Based on phi_proxy_pipeline_spec.md §8.2 robust dispersion algorithm
%
%   See also: LinearDispersion, compute_group_velocity
%
%   Holden Leslie-Bole, January 2026

g = 9.81;

% Handle vector input
if numel(omega) > 1
    k = NaN(size(omega));
    for i = 1:numel(omega)
        k(i) = dispersion_k_robust(omega(i), h);
    end
    return
end

% Handle edge cases
if ~isfinite(omega) || ~isfinite(h) || omega <= 0 || h <= 0
    k = NaN;
    return
end

% Initial guess: deep-water approximation
k = max(omega^2 / g, 1e-6);

tol = 1e-10;
maxIter = 50;

% Newton-Raphson iteration
for it = 1:maxIter
    kh = k * h;
    
    % Prevent overflow in tanh/sech for large kh
    if kh > 50
        f = g*k - omega^2;  % Deep water limit: tanh(kh) ≈ 1
        df = g;
    else
        th = tanh(kh);
        f = g*k*th - omega^2;
        df = g*th + g*k*h*(sech(kh))^2;
    end
    
    % Check for convergence
    if abs(df) < 1e-15
        break
    end
    
    dk = -f/df;
    k_new = k + dk;
    
    % Check for convergence
    if abs(dk)/max(k, 1e-12) < tol
        k = k_new;
        return
    end
    
    % Check for invalid result
    if ~isfinite(k_new) || k_new <= 0
        break  % Fall back to bisection
    end
    
    k = k_new;
end

% Fallback: bisection method with guaranteed bounds
k_low = 1e-12;
k_high = max((omega^2/g)*100, (1/h)*100);

for it = 1:200
    k_mid = 0.5*(k_low + k_high);
    
    kh_mid = k_mid * h;
    if kh_mid > 50
        f_mid = g*k_mid - omega^2;
    else
        f_mid = g*k_mid*tanh(kh_mid) - omega^2;
    end
    
    kh_low = k_low * h;
    if kh_low > 50
        f_low = g*k_low - omega^2;
    else
        f_low = g*k_low*tanh(kh_low) - omega^2;
    end
    
    if sign(f_mid) == sign(f_low)
        k_low = k_mid;
    else
        k_high = k_mid;
    end
    
    if abs(k_high - k_low)/max(k_mid, 1e-12) < 1e-10
        k = k_mid;
        return
    end
end

k = k_mid;

end
