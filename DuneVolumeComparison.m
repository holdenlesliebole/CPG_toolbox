% Compare dune volume evolution for Cardiff and Tijuana River Mouth
% Generates:
% 1. Side-by-side map plots showing elevation change (DEM of difference)
% 2. Time series plot comparing volume changes for both regions

%DefineMopPath

%% ======== REGION 1: CARDIFF DUNE ========
fprintf('=== Processing Cardiff Dune (Mops 670-678) ===\n');
cardiff_mop1 = 670;
cardiff_mop2 = 678;
cardiff_baseline_date = datenum(2015,10,6);
cardiff_min_elev = 3.2;  % m NAVD88
cardiff_max_elev = 4.7;  % m NAVD88

% Load Cardiff data
CG_cardiff = SGcombineMops(cardiff_mop1, cardiff_mop2);

% Get baseline grid
[X_cardiff, Y_cardiff, Z_cardiff_baseline] = SG2grid(CG_cardiff, find([CG_cardiff.Datenum] == cardiff_baseline_date));
Z_cardiff_baseline(Z_cardiff_baseline > cardiff_max_elev) = NaN;

% Get all survey dates for time series
cardiff_all_surveys = unique([CG_cardiff.Datenum]);
cardiff_all_surveys = sort(cardiff_all_surveys);

%% ======== REGION 2: TIJUANA RIVER MOUTH ========
fprintf('=== Processing Tijuana River Mouth (Mops 1-38) ===\n');
tijuana_mop1 = 1;
tijuana_mop2 = 38;
% Use earliest survey as baseline for Tijuana
CG_tijuana = SGcombineMops(tijuana_mop1, tijuana_mop2);
tijuana_all_surveys = unique([CG_tijuana.Datenum]);
tijuana_all_surveys = sort(tijuana_all_surveys);
tijuana_baseline_date = datenum(2019,2,6); %tijuana_all_surveys(1);
tijuana_min_elev = 3.2;  % m NAVD88
tijuana_max_elev = 4.7;  % m NAVD88

% Get baseline grid for Tijuana
[X_tijuana, Y_tijuana, Z_tijuana_baseline] = SG2grid(CG_tijuana, find([CG_tijuana.Datenum] == tijuana_baseline_date));
Z_tijuana_baseline(Z_tijuana_baseline > tijuana_max_elev) = NaN;

fprintf('Cardiff baseline: %s\n', datestr(cardiff_baseline_date));
fprintf('Tijuana baseline: %s\n', datestr(tijuana_baseline_date));

%% ======== CREATE SIDE-BY-SIDE MAP PLOT ========
% Use most recent surveys for the maps
cardiff_recent_idx = find([CG_cardiff.Datenum] == max([CG_cardiff.Datenum]));
tijuana_recent_idx = find([CG_tijuana.Datenum] == max([CG_tijuana.Datenum]));

[X_c_recent, Y_c_recent, Z_c_recent] = SG2grid(CG_cardiff, cardiff_recent_idx);
[X_t_recent, Y_t_recent, Z_t_recent] = SG2grid(CG_tijuana, tijuana_recent_idx);

% Complete back of dune with interpolation (Cardiff method)
fprintf('Interpolating dune back-of-beach for Cardiff...\n');
for n = 1:size(Z_c_recent,1)
    ixmax = find(~isnan(Z_c_recent(n,:)), 1, 'last');
    if ~isempty(ixmax)
        if Z_c_recent(n,ixmax) > cardiff_max_elev
            z4 = Z_c_recent(n,ixmax) - [1 2 3 4]*(Z_c_recent(n,ixmax) - cardiff_max_elev)/4;
            Z_c_recent(n, ixmax+1:ixmax+4) = z4;
        end
    end
end

% Do the same for Tijuana
fprintf('Interpolating dune back-of-beach for Tijuana...\n');
for n = 1:size(Z_t_recent,1)
    ixmax = find(~isnan(Z_t_recent(n,:)), 1, 'last');
    if ~isempty(ixmax)
        if Z_t_recent(n,ixmax) > tijuana_max_elev
            z4 = Z_t_recent(n,ixmax) - [1 2 3 4]*(Z_t_recent(n,ixmax) - tijuana_max_elev)/4;
            Z_t_recent(n, ixmax+1:ixmax+4) = z4;
        end
    end
end

% Fill baseline gaps
imiss_c = find(Z_c_recent(:) > cardiff_max_elev & isnan(Z_cardiff_baseline(:)));
Z_cardiff_baseline(imiss_c) = cardiff_max_elev;

imiss_t = find(Z_t_recent(:) > tijuana_max_elev & isnan(Z_tijuana_baseline(:)));
Z_tijuana_baseline(imiss_t) = tijuana_max_elev;

% Calculate elevation differences
Zd_cardiff = Z_c_recent - Z_cardiff_baseline;
Zd_cardiff(Z_cardiff_baseline < cardiff_min_elev) = NaN;

Zd_tijuana = Z_t_recent - Z_tijuana_baseline;
Zd_tijuana(Z_tijuana_baseline < tijuana_min_elev) = NaN;

% Calculate volumes
cardiff_dune_vol = round(sum(Zd_cardiff(:), 'omitnan'));
tijuana_dune_vol = round(sum(Zd_tijuana(:), 'omitnan'));

cardiff_vol_per_m = round(cardiff_dune_vol) / ((cardiff_mop2 - cardiff_mop1 + 1) * 100);
tijuana_vol_per_m = round(tijuana_dune_vol) / ((tijuana_mop2 - tijuana_mop1 + 1) * 100);

fprintf('Cardiff dune volume: %d m³ (%.1f m³/m)\n', cardiff_dune_vol, cardiff_vol_per_m);
fprintf('Tijuana dune volume: %d m³ (%.1f m³/m)\n', tijuana_dune_vol, tijuana_vol_per_m);

% Create side-by-side figure with satellite background
fig_maps = figure('position', [100 100 1400 600]);

% ===== CARDIFF MAP =====
ax_c = subplot(1, 2, 1);
idx_c = find(~isnan(Z_cardiff_baseline(:)));
[y_c, x_c] = utm2deg([min(X_cardiff(idx_c)) max(X_cardiff(idx_c))], ...
    [min(Y_cardiff(idx_c))-400 max(Y_cardiff(idx_c))+400], ...
    repmat('11 S', [2 1]));

set(ax_c, 'xlim', x_c, 'ylim', y_c);
hold on;
plot_google_map('MapType', 'satellite', 'Alpha', 1, 'axis', ax_c);
hold on;

% Convert to lat/lon for overlay
[ylat_c, xlon_c] = utm2deg(X_cardiff(:), Y_cardiff(:), repmat('11 S', [numel(X_cardiff(:)) 1]));
Xl_c = X_cardiff;
Yl_c = Y_cardiff;
Xl_c(:) = xlon_c;
Yl_c(:) = ylat_c;

surf(Xl_c, Yl_c, Zd_cardiff);
shading flat;
colormap(ax_c, jet);
view(2);
set(ax_c, 'clim', [0 3]);
view(0, 90);
set(ax_c, 'dataaspectratio', [1.0000 2.8255 50.0000]);

% Zoom to dune area
set(ax_c, 'xlim', [-117.2821 -117.2767]);
set(ax_c, 'ylim', [33.0004 33.0157]);

cb_c = colorbar(ax_c);
cb_c.Label.String = 'Elevation Change (m)';
cb_c.FontSize = 12;
set(ax_c, 'fontsize', 11);

title(sprintf('Cardiff Dune\n%s (baseline %s)', datestr(CG_cardiff(cardiff_recent_idx).Datenum, 'mmm dd, yyyy'), ...
    datestr(cardiff_baseline_date, 'mmm dd, yyyy')), 'fontsize', 12, 'fontweight', 'bold');

dim_c = [.12 .55 .25 .3];
str_c = [{'DUNE VOLUME'}, {sprintf('%d m³', cardiff_dune_vol)}, {}, ...
    {sprintf('%.1f m³/m', cardiff_vol_per_m)}];
a_c = annotation('textbox', dim_c, 'String', str_c, 'FitBoxToText', 'on', ...
    'backgroundcolor', 'w', 'fontsize', 11);

% ===== TIJUANA MAP =====
ax_t = subplot(1, 2, 2);
idx_t = find(~isnan(Z_tijuana_baseline(:)));
[y_t, x_t] = utm2deg([min(X_tijuana(idx_t)) max(X_tijuana(idx_t))], ...
    [min(Y_tijuana(idx_t))-400 max(Y_tijuana(idx_t))+400], ...
    repmat('11 S', [2 1]));

set(ax_t, 'xlim', x_t, 'ylim', y_t);
hold on;
plot_google_map('MapType', 'satellite', 'Alpha', 1, 'axis', ax_t);
hold on;

% Convert to lat/lon for overlay
[ylat_t, xlon_t] = utm2deg(X_tijuana(:), Y_tijuana(:), repmat('11 S', [numel(X_tijuana(:)) 1]));
Xl_t = X_tijuana;
Yl_t = Y_tijuana;
Xl_t(:) = xlon_t;
Yl_t(:) = ylat_t;

surf(Xl_t, Yl_t, Zd_tijuana);
shading flat;
colormap(ax_t, jet);
view(2);
set(ax_t, 'clim', [0 3]);
view(0, 90);
set(ax_t, 'dataaspectratio', [1.0000 2.8255 50.0000]);

cb_t = colorbar(ax_t);
cb_t.Label.String = 'Elevation Change (m)';
cb_t.FontSize = 12;
set(ax_t, 'fontsize', 11);

title(sprintf('Tijuana River Mouth\n%s (baseline %s)', datestr(CG_tijuana(tijuana_recent_idx).Datenum, 'mmm dd, yyyy'), ...
    datestr(tijuana_baseline_date, 'mmm dd, yyyy')), 'fontsize', 12, 'fontweight', 'bold');

dim_t = [.62 .55 .25 .3];
str_t = [{'DUNE VOLUME'}, {sprintf('%d m³', tijuana_dune_vol)}, {}, ...
    {sprintf('%.1f m³/m', tijuana_vol_per_m)}];
a_t = annotation('textbox', dim_t, 'String', str_t, 'FitBoxToText', 'on', ...
    'backgroundcolor', 'w', 'fontsize', 11);

sgtitle('Dune Volume: Elevation Change Maps', 'fontsize', 14, 'fontweight', 'bold');

print(gcf, '-dpng', '-r100', '-loose', 'DuneComparison_Maps.png');

%% ======== CREATE TIME SERIES PLOT ========
fprintf('\nCalculating time series volumes...\n');

% Calculate volume time series for Cardiff
cardiff_vols = [];
cardiff_dates = [];

for n = 1:length(cardiff_all_surveys)
    idx = find([CG_cardiff.Datenum] == cardiff_all_surveys(n));
    if ~isempty(idx)
        [X_temp, Y_temp, Z_temp] = SG2grid(CG_cardiff, idx);
        
        % Fill baseline gaps
        imiss = find(Z_temp(:) > cardiff_max_elev & isnan(Z_cardiff_baseline(:)));
        Z_cb = Z_cardiff_baseline;
        Z_cb(imiss) = cardiff_max_elev;
        
        % Interpolate back of beach
        for row = 1:size(Z_temp,1)
            ixmax = find(~isnan(Z_temp(row,:)), 1, 'last');
            if ~isempty(ixmax) && Z_temp(row,ixmax) > cardiff_max_elev
                z4 = Z_temp(row,ixmax) - [1 2 3 4]*(Z_temp(row,ixmax) - cardiff_max_elev)/4;
                Z_temp(row, ixmax+1:ixmax+4) = z4;
            end
        end
        
        % Calculate elevation difference relative to baseline
        Zd_temp = Z_temp - Z_cb;
        Zd_temp(Z_cb < cardiff_min_elev) = NaN;
        
        vol = sum(Zd_temp(:), 'omitnan');
        cardiff_vols = [cardiff_vols; vol];
        cardiff_dates = [cardiff_dates; cardiff_all_surveys(n)];
    end
end

% Calculate volume time series for Tijuana
tijuana_vols = [];
tijuana_dates = [];

for n = 1:length(tijuana_all_surveys)
    idx = find([CG_tijuana.Datenum] == tijuana_all_surveys(n));
    if ~isempty(idx)
        [X_temp, Y_temp, Z_temp] = SG2grid(CG_tijuana, idx);
        
        % Fill baseline gaps
        imiss = find(Z_temp(:) > tijuana_max_elev & isnan(Z_tijuana_baseline(:)));
        Z_tb = Z_tijuana_baseline;
        Z_tb(imiss) = tijuana_max_elev;
        
        % Interpolate back of beach
        for row = 1:size(Z_temp,1)
            ixmax = find(~isnan(Z_temp(row,:)), 1, 'last');
            if ~isempty(ixmax) && Z_temp(row,ixmax) > tijuana_max_elev
                z4 = Z_temp(row,ixmax) - [1 2 3 4]*(Z_temp(row,ixmax) - tijuana_max_elev)/4;
                Z_temp(row, ixmax+1:ixmax+4) = z4;
            end
        end
        
        % Calculate elevation difference relative to baseline
        Zd_temp = Z_temp - Z_tb;
        Zd_temp(Z_tb < tijuana_min_elev) = NaN;
        
        vol = sum(Zd_temp(:), 'omitnan');
        tijuana_vols = [tijuana_vols; vol];
        tijuana_dates = [tijuana_dates; tijuana_all_surveys(n)];
    end
end

fprintf('Cardiff: %d survey dates\n', length(cardiff_dates));
fprintf('Tijuana: %d survey dates\n', length(tijuana_dates));

% Create time series figure
fig_ts = figure('position', [100 100 1000 600]);
hold on;

% Plot both regions on same axis
p1 = plot(cardiff_dates, cardiff_vols, 'o-', 'linewidth', 2.5, 'markersize', 6, ...
    'color', [0.2 0.4 0.8], 'DisplayName', 'Cardiff Dune');
p2 = plot(tijuana_dates, tijuana_vols, 's-', 'linewidth', 2.5, 'markersize', 6, ...
    'color', [0.8 0.2 0.2], 'DisplayName', 'Tijuana River Mouth');

datetick('x', 'yyyy-mm', 'keeplimits');
grid on;
grid minor;

xlabel('Date', 'fontsize', 12, 'fontweight', 'bold');
ylabel('Dune Volume Change (m³) from Baseline', 'fontsize', 12, 'fontweight', 'bold');
title('Dune Volume Evolution: Cardiff vs. Tijuana River Mouth', 'fontsize', 14, 'fontweight', 'bold');

legend([p1 p2], 'location', 'best', 'fontsize', 11);
set(gca, 'fontsize', 11);

% Add baseline reference line
ylims = ylim;
plot([min(cardiff_dates) max(tijuana_dates)], [0 0], 'k--', 'linewidth', 1.5);

print(gcf, '-dpng', '-r100', '-loose', 'DuneComparison_TimeSeries.png');

fprintf('\nFigures saved:\n');
fprintf('  - DuneComparison_Maps.png\n');
fprintf('  - DuneComparison_TimeSeries.png\n');
