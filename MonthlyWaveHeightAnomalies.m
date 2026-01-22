% Monthly wave height anomalies bar plot
% Plots monthly mean Hs anomalies (departure from long-term mean)
% Red bars = positive anomalies, Blue bars = negative anomalies

clear all
close all

%% USER SETTINGS
MopName = 'D0583';           % MOP line (e.g., 'D0583')
dateStart = datenum(2022, 10, 1);  % Start date
dateEnd   = datenum(2025, 12, 31); % End date

%% Load wave data
fprintf('Loading wave data for %s (%s to %s)...\n', MopName, ...
    datestr(dateStart, 'yyyy-mm-dd'), datestr(dateEnd, 'yyyy-mm-dd'));

dt1 = datetime(dateStart, 'ConvertFrom', 'datenum');
dt2 = datetime(dateEnd, 'ConvertFrom', 'datenum');

try
    MOP = read_MOPline2(MopName, dt1, dt2);
catch ME
    error('Failed to load wave data for %s: %s', MopName, ME.message);
end

% Extract time and Hs
timeW_dt = MOP.time(:);
Hs = MOP.Hs(:);

% Convert datetime to datenum
if isdatetime(timeW_dt)
    timeW = datenum(timeW_dt);
else
    timeW = timeW_dt;
end

fprintf('Loaded %d wave data points.\n', length(Hs));

%% Calculate monthly statistics
% Get year and month
dt_all = datetime(timeW, 'ConvertFrom', 'datenum');
years = year(dt_all);
months = month(dt_all);

% Monthly aggregation: mean Hs for each (year, month)
year_month = years*100 + months;  % e.g., 202210 for Oct 2022
[ym_unique, ~, ic] = unique(year_month);

n_months = length(ym_unique);
monthly_Hs = nan(n_months, 1);
monthly_date = nan(n_months, 1);
monthly_month = nan(n_months, 1);  % track calendar month for climatology

for i = 1:n_months
    idx = (ic == i);
    monthly_Hs(i) = nanmean(Hs(idx));
    monthly_month(i) = mode(months(idx));  % most common month in this group
    % Use first day of month as timestamp
    yr = floor(ym_unique(i) / 100);
    mo = mod(ym_unique(i), 100);
    monthly_date(i) = datenum(yr, mo, 15);  % middle of month
end

% Calculate climatological mean for each calendar month (1-12)
clim_month_mean = nan(12, 1);
Hs_mean_global = nanmean(monthly_Hs);  % overall mean for reference
for mo = 1:12
    idx_mo = (monthly_month == mo);
    if any(idx_mo)
        clim_month_mean(mo) = nanmean(monthly_Hs(idx_mo));
    end
end

% Calculate anomalies relative to climatological month
Hs_anom = nan(size(monthly_Hs));
for i = 1:n_months
    mo = monthly_month(i);
    if ~isnan(clim_month_mean(mo))
        Hs_anom(i) = monthly_Hs(i) - clim_month_mean(mo);
    end
end

%% Create bar plot
figure('position', [100 100 1200 500]);

% Separate positive and negative anomalies
pos_idx = Hs_anom >= 0;
neg_idx = Hs_anom < 0;

% Plot negative bars first (blue)
if any(neg_idx)
    bar(monthly_date(neg_idx), Hs_anom(neg_idx), 'b', 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    hold on;
end

% Plot positive bars (red)
if any(pos_idx)
    bar(monthly_date(pos_idx), Hs_anom(pos_idx), 'r', 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    hold on;
end

% Add zero line
yline(0, 'k-', 'linewidth', 1.5);

% Format axes
datetick('x', 'mmm yyyy', 'keeplimits');
xlabel('Month', 'fontsize', 12);
ylabel('Wave Height Anomaly (m)', 'fontsize', 12);
title(sprintf('Monthly Wave Height Anomalies\n%s (%s to %s)', MopName, ...
    datestr(dateStart, 'yyyy-mm-dd'), datestr(dateEnd, 'yyyy-mm-dd')), ...
    'fontsize', 14, 'fontweight', 'bold');

grid on;
set(gca, 'fontsize', 11);
xtickangle(45);

% Add statistics box
n_data = nnz(~isnan(Hs_anom));
anom_std = nanstd(Hs_anom);
text(0.02, 0.02, sprintf('Months: %d\nGlobal mean Hs: %.2f m\nClimatological anomalies\nStd: %.2f m', ...
    n_data, Hs_mean_global, anom_std), ...
    'units', 'normalized', 'verticalalign', 'bottom', 'fontsize', 10, ...
    'backgroundcolor', 'w', 'margin', 2, 'edgecolor', [0.5 0.5 0.5]);

fprintf('Monthly climatological anomalies: %d months, std = %.3f m, global Hs mean = %.3f m\n', ...
    n_data, anom_std, Hs_mean_global);

% Save figure
filename = sprintf('MonthlyWaveHeightAnomalies_%s_%s_to_%s.fig', MopName, ...
    datestr(dateStart, 'yyyymmdd'), datestr(dateEnd, 'yyyymmdd'));
savefig(filename);
fprintf('Figure saved to: %s\n', filename);
