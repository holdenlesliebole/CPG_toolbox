% Hovmoller plot of beach profile elevation changes over time
% X-axis: time (surveys)
% Y-axis: cross-shore distance
% Color: elevation change relative to first survey in date range

clear all
close all

%% USER SETTINGS
MopNumber = 582;  % MOP transect to analyze
dateStart = datenum(2023, 4, 6);  % Start date for analysis
dateEnd   = datenum(2023, 8, 31); % End date for analysis

% Profile interpolation settings
NumSubTrans = 51;  % Number of cross-shore interpolation points
XgapTol = 25;      % Max cross-shore gap tolerance (m) - increased from 15
YdistTol = 50;     % Max distance from transect (m) - increased from 25

% Gap handling / smoothing for display
MaxInterpGap = 500;   % meters; gaps wider than this stay NaN
SmoothXwindow = 3;   % points; moving mean along x after interpolation (set 1 to disable)

% Time interpolation for smoother Hovmoller (number of time samples)
TimeInterpN = 100;   % increase for smoother look; set empty [] to disable

%% Load survey data
fprintf('Loading survey data for MOP %d...\n', MopNumber);
load(sprintf('M%05dSA.mat', MopNumber), 'SA');

% Filter surveys by date range
survdates = [SA.Datenum];
date_idx = find(survdates >= dateStart & survdates <= dateEnd);

if isempty(date_idx)
    error('No surveys found in specified date range');
end
SA_filtered = SA(date_idx);
fprintf('Found %d surveys in date range.\n', length(SA_filtered));

%% Extract cross-shore profiles for each survey
[X1Dmop, X1Dcpg, Zdatetime, Z1Dtrans, Z1Dmean, Z1Dmedian, Z1Dmin, Z1Dmax, Z1Dstd] = ...
    GetCpgNearestPointProfiles(SA_filtered, NumSubTrans, XgapTol, YdistTol);

fprintf('Interpolated profiles to %d cross-shore points.\n', length(X1Dcpg));
fprintf('Date range: %s to %s\n', datestr(min(Zdatetime)), datestr(max(Zdatetime)));

%% Calculate elevation change relative to first survey
% Z1Dmean is [Nsurv x Nxshore] array
Z_anomaly = Z1Dmean - repmat(Z1Dmean(1,:), size(Z1Dmean,1), 1);

%% Time interpolation (optional) to smooth the Hovmoller in time
Z_anomaly_time = Z_anomaly;
Zdatetime_time = Zdatetime;

% Deduplicate survey times to avoid interp1 duplicate-sample errors
Zdatenum_raw = datenum(Zdatetime);
[t_unique,~,ic] = unique(Zdatenum_raw);
if numel(t_unique) < numel(Zdatenum_raw)
    Zuniq = nan(numel(t_unique), size(Z_anomaly,2));
    for ii = 1:numel(t_unique)
        idx = (ic == ii);
        Zuniq(ii,:) = nanmean(Z_anomaly(idx,:), 1);
    end
    Z_anomaly_dedup = Zuniq;
    Zdatenum_dedup = t_unique;
else
    Z_anomaly_dedup = Z_anomaly;
    Zdatenum_dedup = Zdatenum_raw;
end

if ~isempty(TimeInterpN) && TimeInterpN > length(Zdatenum_dedup)
    Zdatenum_dense = linspace(min(Zdatenum_dedup), max(Zdatenum_dedup), TimeInterpN);
    Z_anomaly_dense = nan(TimeInterpN, size(Z_anomaly_dedup,2));
    for ix = 1:size(Z_anomaly_dedup,2)
        Z_anomaly_dense(:,ix) = interp1(Zdatenum_dedup, Z_anomaly_dedup(:,ix), Zdatenum_dense, 'linear', NaN);
    end
    Z_anomaly_time = Z_anomaly_dense;
    Zdatetime_time = datetime(Zdatenum_dense, 'ConvertFrom','datenum');
else
    Z_anomaly_time = Z_anomaly_dedup;
    Zdatetime_time = datetime(Zdatenum_dedup, 'ConvertFrom','datenum');
end

%% Fill small cross-shore gaps for smoother display
Z_plot = Z_anomaly;
X = X1Dcpg;
dx = median(diff(X));
for k = 1:size(Z_anomaly_time,1)
    z = Z_anomaly_time(k,:);
    mask = ~isnan(z);
    if sum(mask) >= 2
        % Linear interp across NaNs
        z_filled = interp1(X(mask), z(mask), X, 'linear', NaN);
        % Keep large gaps unfilled
        idx_valid = find(mask);
        for ii = 1:numel(idx_valid)-1
            gap_idx = (idx_valid(ii)+1):(idx_valid(ii+1)-1);
            if ~isempty(gap_idx)
                gap_width = X(idx_valid(ii+1)) - X(idx_valid(ii));
                if gap_width > MaxInterpGap
                    z_filled(gap_idx) = NaN;
                end
            end
        end
        % Optional smoothing along x
        if SmoothXwindow > 1
            z_filled = movmean(z_filled, SmoothXwindow, 'omitnan');
        end
        Z_plot(k,:) = z_filled;
    end
end

%% Create Hovmoller plot
figure('position', [100 100 1200 600]);

% Convert datetime to datenum for pcolor
Zdatenum = datenum(Zdatetime_time);

% Create pcolor plot
[T_grid, X_grid] = meshgrid(Zdatenum, X1Dcpg);
% Create pcolor plot (use gap-filled Z_plot)
pcolor(T_grid', X_grid', Z_plot);
shading flat;

% Color setup: red/blue diverging colormap for elevation changes
cmax = max(abs(Z_plot(~isnan(Z_plot))));
if isempty(cmax) || cmax == 0
    cmax = 0.1; % avoid zero/NaN range
end
if exist('redblue','file') == 2
    colormap(flipud(redblue)); % flip so blue = positive
else
    colormap(flipud(redblue_local(256)));
end
caxis([-cmax cmax]);
cb = colorbar;
cb.Label.String = 'Elevation Change (m) Relative to First Survey';
cb.Label.FontSize = 12;

% Format axes
datetick('x', 'mmm yyyy', 'keeplimits');
xlabel('Survey Date', 'fontsize', 12);
ylabel('Cross-shore Distance (m)', 'fontsize', 12);
title(sprintf('MOP %d: Beach Profile Elevation Change (%s to %s)', MopNumber, ...
    datestr(min(Zdatenum),'yyyy-mm-dd'), datestr(max(Zdatenum),'yyyy-mm-dd')), ...
    'fontsize', 14, 'fontweight', 'bold');

grid on;
set(gca, 'fontsize', 11);
set(gca, 'ydir', 'normal');  % Y-axis increases upward (cross-shore distance)

% Add tidal reference lines
hold on;
yline(0.774, 'k--', 'linewidth', 1.5, 'DisplayName', 'MSL');
yline(1.344, 'k--', 'linewidth', 1.5, 'DisplayName', 'MHW');
yline(1.566, 'k--', 'linewidth', 1.5, 'DisplayName', 'MHHW');

% Overlay contour position curves (0, -2, -4, -6, -8 m)
contours_plot = [0 -2 -4 -6 -8];
contour_x = nan(length(Zdatetime), numel(contours_plot));
for k = 1:length(Zdatetime)
    zprof = Z1Dmean(k,:);
    % ensure monotonic X for interp
    [Xsorted, is] = sort(X1Dcpg);
    zsorted = zprof(is);
    for ci = 1:numel(contours_plot)
        level = contours_plot(ci);
        msk = isfinite(zsorted) & isfinite(Xsorted);
        if nnz(msk) >= 2
            zs = zsorted(msk);
            xs = Xsorted(msk);
            % ensure unique zs for interp1
            [zs_u, ia, icu] = unique(zs, 'stable');
            if numel(zs_u) >= 2
                if numel(zs_u) ~= numel(zs)
                    % average xs for duplicate zs
                    xs_mean = accumarray(icu, xs, [], @mean, NaN);
                    xs_u = xs_mean(1:numel(zs_u));
                else
                    xs_u = xs;
                end
                if min(zs_u) <= level && max(zs_u) >= level
                    contour_x(k,ci) = interp1(zs_u, xs_u, level, 'linear', NaN);
                end
            end
        end
    end
end
% Deduplicate time for contours using same unique grid
T_orig_num = datenum(Zdatetime);
[t_unique_c,~,ic_c] = unique(T_orig_num);
contour_x_dedup = nan(numel(t_unique_c), numel(contours_plot));
for ii = 1:numel(t_unique_c)
    idx = (ic_c == ii);
    contour_x_dedup(ii,:) = nanmean(contour_x(idx,:),1);
end

% Time-interpolate contour positions to match Zdatenum (if interpolated)
if ~isempty(TimeInterpN) && TimeInterpN > length(t_unique_c)
    T_dense_num = Zdatenum;
    contour_x_dense = nan(length(T_dense_num), numel(contours_plot));
    for ci = 1:numel(contours_plot)
        contour_x_dense(:,ci) = interp1(t_unique_c, contour_x_dedup(:,ci), T_dense_num, 'linear', NaN);
    end
    contour_x = contour_x_dense;
    T_plot_num = T_dense_num;
else
    contour_x = contour_x_dedup;
    T_plot_num = t_unique_c;
end
for ci = 1:numel(contours_plot)
    plot(T_plot_num, contour_x(:,ci), 'k-', 'linewidth', 1.2);
end

% Rotate x-axis labels for readability
xtickangle(45);

% Add survey count info
nsurv = length(SA_filtered);
text(0.02, 0.98, sprintf('Number of surveys: %d', nsurv), ...
    'units', 'normalized', 'verticalalign', 'top', 'fontsize', 10, ...
    'backgroundcolor','w','margin',2,'edgecolor',[0.5 0.5 0.5]);

%% Optional: Save figure
savefig(sprintf('Hovmoller_Mop%d_%s_to_%s.fig', MopNumber, ...
    datestr(min(Zdatenum),'yyyymmdd'), datestr(max(Zdatenum),'yyyymmdd')));
print(sprintf('Hovmoller_Mop%d_%s_to_%s.png', MopNumber, ...
    datestr(min(Zdatenum),'yyyymmdd'), datestr(max(Zdatenum),'yyyymmdd')), ...
    '-dpng', '-r150');

fprintf('Plot complete. %d surveys, %d cross-shore points.\n', nsurv, length(X1Dcpg));

%% Local red-blue colormap (if redblue.m not on path)
function cmap = redblue_local(m)
if nargin < 1, m = 256; end
% Simple diverging red-white-blue
bottom = [0 0 1];
middle = [1 1 1];
top = [1 0 0];
x = linspace(0,1,m)';
cmap = zeros(m,3);
for i=1:3
    cmap(:,i) = interp1([0 0.5 1],[bottom(i) middle(i) top(i)], x);
end
end