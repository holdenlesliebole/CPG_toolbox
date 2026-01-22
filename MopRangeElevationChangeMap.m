% MopRangeElevationChangeMap.m
% 
% Creates a 2D map of elevation changes across a MOP range
% X-axis: MOP number (alongshore)
% Y-axis: Cross-shore distance from back beach
% Color: Elevation change (m) since initial survey
% Overlays elevation contours (+2, 0, -2, -4, -6, -8, -10 m)
% Background: Google Maps satellite imagery

clear all
close all

%% USER SETTINGS
MopStart = 576;           % Start MOP number
MopEnd = 590;             % End MOP number
dateStart = datenum(2022, 10, 1);    % Start of date range for quarterly plots
dateEnd = datenum(2025, 10, 31);     % End of date range for quarterly plots

% Profile interpolation settings
NumSubTrans = 300;         % Number of cross-shore interpolation points
XgapTol = 15;             % Max gap (m) for nearest-neighbor in cross-shore
YdistTol = 25;            % Alongshore tolerance (m) for scatter-to-grid

% Contour levels to overlay (in meters NAVD88)
ContourLevels = [-10, -8, -6, -4, -2, 0, 2];

% Google Map settings
MapAlpha = 1;           % Transparency of map (0-1)

% Output directory for figures
OutputDir = pwd;          % Save to current directory

%% Load MOP table
fprintf('Loading MOP table...\n');
load MopTableUTM.mat
MopNumbers = MopStart:MopEnd;

%% Find quarterly survey dates (jetski/jumbo only)
fprintf('\nSearching for jetski/jumbo surveys in range %s to %s...\n', ...
    datestr(dateStart, 'yyyy-mm-dd'), datestr(dateEnd, 'yyyy-mm-dd'));

% Load a representative MOP to find survey dates
MopID = sprintf('M%5.5i', MopStart);
SAfile = [MopID 'SA.mat'];
fprintf('Loading %s to find survey dates...\n', SAfile);
load(SAfile, 'SA');

% Filter for jetski and jumbo surveys (subaqueous data) with elevation < -3m
isJetskiJumbo = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
    {SA.File});
SA_candidates = SA(isJetskiJumbo);

% Further filter for surveys with minimum elevation < -3m (subaqueous coverage)
hasSubaqueous = [];
for i = 1:length(SA_candidates)
    if ~isempty(SA_candidates(i).Z) && min(SA_candidates(i).Z) < -3
        hasSubaqueous = [hasSubaqueous, i];
    end
end
SA_filtered = SA_candidates(hasSubaqueous);
fprintf('Found %d jetski/jumbo surveys with subaqueous coverage (min elev < -3m)\n', length(SA_filtered));

% Get dates of filtered surveys
if isempty(SA_filtered)
    error('No jetski/jumbo surveys found!');
end

AllDates = [SA_filtered.Datenum];
AllDates_sorted = sort(AllDates);

% Identify quarterly surveys (ideally Jan, Apr, Jul, Oct)
% For each date in the user range, find the two nearest surveys that bracket it
fprintf('\nIdentifying quarterly survey pairs...\n');

% Get start and end dates
dt_start = datetime(dateStart, 'ConvertFrom', 'datenum');
dt_end = datetime(dateEnd, 'ConvertFrom', 'datenum');

% Extract year and month from user dates
year_start = year(dt_start);
month_start = month(dt_start);
year_end = year(dt_end);
month_end = month(dt_end);

% Generate quarterly dates (Apr, Jul, Oct, Jan) within the user range
QuarterlyMonths = [1, 4, 7, 10];  % Jan, Apr, Jul, Oct
QuarterPairs = [];  % Will store [date1, date2] for each quarter pair

% Start from the first quarterly month >= user start
current_year = year_start;
current_month = month_start;

% Find the next quarterly month
while ~ismember(current_month, QuarterlyMonths)
    current_month = current_month + 1;
    if current_month > 12
        current_month = 1;
        current_year = current_year + 1;
    end
end

% Generate quarter pairs
while datenum(current_year, current_month, 1) <= dateEnd
    quarter_start_datenum = datenum(current_year, current_month, 1);
    
    % Find next quarterly month
    next_month = current_month;
    next_year = current_year;
    idx = find(QuarterlyMonths > current_month);
    if ~isempty(idx)
        next_month = QuarterlyMonths(idx(1));
    else
        next_month = QuarterlyMonths(1);
        next_year = current_year + 1;
    end
    
    quarter_end_datenum = datenum(next_year, next_month, 1);
    
    % Find surveys near start and end of this quarter
    [~, idx1] = min(abs(AllDates_sorted - quarter_start_datenum));
    [~, idx2] = min(abs(AllDates_sorted - quarter_end_datenum));
    
    % Ensure we have two different surveys
    if idx1 ~= idx2
        date1 = AllDates_sorted(idx1);
        date2 = AllDates_sorted(idx2);
        % Make sure date1 < date2
        if date1 > date2
            temp = date1;
            date1 = date2;
            date2 = temp;
        end
        QuarterPairs = [QuarterPairs; date1, date2];
        fprintf('  Quarter %s to %s: %s to %s\n', ...
            datestr(quarter_start_datenum, 'mmm yyyy'), ...
            datestr(quarter_end_datenum, 'mmm yyyy'), ...
            datestr(date1, 'mmm dd, yyyy'), ...
            datestr(date2, 'mmm dd, yyyy'));
    end
    
    % Move to next quarter
    current_month = next_month;
    current_year = next_year;
    if datenum(current_year, current_month, 1) > dateEnd
        break;
    end
end

fprintf('Generated %d quarterly plots\n', size(QuarterPairs, 1));

%% Load wave data once before loop for timeseries panel
fprintf('Loading wave data for timeseries panel...\n');
MopMidpoint = round((MopStart + MopEnd) / 2);
targetMOP = sprintf('D%04d', MopMidpoint);

try
    % Convert datenums to datetime for read_MOPline2
    dt1 = datetime(dateStart, 'ConvertFrom', 'datenum');
    dt2 = datetime(dateEnd, 'ConvertFrom', 'datenum');
    
    MOP_wave = read_MOPline2(targetMOP, dt1, dt2);
    
    % Extract time and Hs from struct
    timeW_dt = MOP_wave.time(:);  % datetime array
    Hs = MOP_wave.Hs(:);
    
    % Convert datetime to datenum for compatibility with survey dates
    if isdatetime(timeW_dt)
        timeW = datenum(timeW_dt);
    else
        timeW = timeW_dt;
    end
    
    % Sort wave time series chronologically
    [timeW, widx] = sort(timeW);
    Hs = Hs(widx);
    
    % Calculate 30-day moving mean of Hs
    WaveMovingMeanWindow = 30;
    Hs_monthly = movmean(Hs, WaveMovingMeanWindow*24, 'omitnan');  % Convert days to hours
    
    fprintf('Wave data loaded successfully (%d data points).\n', length(timeW));
    waveDataAvailable = true;
catch ME
    fprintf('Warning: Could not load wave data. Wave panel will be skipped.\n');
    fprintf('Error: %s\n', ME.message);
    waveDataAvailable = false;
end

%% Loop through quarterly pairs and create plots
for q = 1:size(QuarterPairs, 1)
    SurveyDate1 = QuarterPairs(q, 1);
    SurveyDate2 = QuarterPairs(q, 2);
    
    fprintf('\n========================================\n');
    fprintf('Processing quarter %d of %d\n', q, size(QuarterPairs, 1));
    fprintf('Survey dates: %s to %s\n', datestr(SurveyDate1, 'mmm dd, yyyy'), ...
        datestr(SurveyDate2, 'mmm dd, yyyy'));
    fprintf('========================================\n');

%% Initialize output arrays
% X (alongshore): MOP numbers
% Y (cross-shore): distance from back beach
% Z (color): elevation change

fprintf('\n=== Building elevation change map ===\n');

% Determine cross-shore grid
X_mops = MopNumbers;
n_mops = length(MopNumbers);

% Load first MOP to get cross-shore grid
MopID_first = sprintf('M%5.5i', MopStart);
fprintf('Loading first MOP (%s) to determine cross-shore grid...\n', MopID_first);
load([MopID_first 'SM.mat'], 'SM');

% Find surveys closest to SurveyDate1 and SurveyDate2 (prefer jetski/jumbo)
SM_dates = [SM.Datenum];

% For SurveyDate1: find all surveys within 1 day, prefer jetski/jumbo
idx_candidates_1 = find(abs(SM_dates - SurveyDate1) <= 1);
if ~isempty(idx_candidates_1)
    % Check if any are jetski/jumbo
    isJetskiJumbo_1 = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
        {SM(idx_candidates_1).File});
    jetski_idx_1 = find(isJetskiJumbo_1);
    
    if ~isempty(jetski_idx_1)
        [~, best_idx] = min(abs(SM_dates(idx_candidates_1(jetski_idx_1)) - SurveyDate1));
        idx_s1 = idx_candidates_1(jetski_idx_1(best_idx));
    else
        [~, best_idx] = min(abs(SM_dates(idx_candidates_1) - SurveyDate1));
        idx_s1 = idx_candidates_1(best_idx);
    end
else
    [~, idx_s1] = min(abs(SM_dates - SurveyDate1));
end

% For SurveyDate2: find all surveys within 1 day, prefer jetski/jumbo
idx_candidates_2 = find(abs(SM_dates - SurveyDate2) <= 1);
if ~isempty(idx_candidates_2)
    % Check if any are jetski/jumbo
    isJetskiJumbo_2 = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
        {SM(idx_candidates_2).File});
    jetski_idx_2 = find(isJetskiJumbo_2);
    
    if ~isempty(jetski_idx_2)
        [~, best_idx] = min(abs(SM_dates(idx_candidates_2(jetski_idx_2)) - SurveyDate2));
        idx_s2 = idx_candidates_2(jetski_idx_2(best_idx));
    else
        [~, best_idx] = min(abs(SM_dates(idx_candidates_2) - SurveyDate2));
        idx_s2 = idx_candidates_2(best_idx);
    end
else
    [~, idx_s2] = min(abs(SM_dates - SurveyDate2));
end

X1D_ref = SM(idx_s1).X1D;
x_min = min(X1D_ref);
x_max = max(X1D_ref);
X_cross_shore = linspace(x_min, x_max, NumSubTrans);

% Initialize 2D elevation arrays
Z_start = nan(n_mops, NumSubTrans);  % Elevation at start date
Z_end = nan(n_mops, NumSubTrans);    % Elevation at end date
Z_change = nan(n_mops, NumSubTrans); % Elevation change

%% Loop through all MOPs
for m = 1:n_mops
    MopNumber = MopNumbers(m);
    MopID = sprintf('M%5.5i', MopNumber);
    SMfile = [MopID 'SM.mat'];
    
    fprintf('Processing MOP %d (%d/%d)...\n', MopNumber, m, n_mops);
    
    try
        load(SMfile, 'SM');
    catch
        fprintf('  ERROR: Could not load %s\n', SMfile);
        continue;
    end
    
    % Find surveys matching SurveyDate1 and SurveyDate2
    % Prefer jetski/jumbo if multiple surveys on same date
    SM_dates = [SM.Datenum];
    
    % For SurveyDate1: find all surveys within 1 day, prefer jetski/jumbo
    idx_candidates_1 = find(abs(SM_dates - SurveyDate1) <= 1);
    if ~isempty(idx_candidates_1)
        % Check if any are jetski/jumbo
        isJetskiJumbo_1 = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
            {SM(idx_candidates_1).File});
        jetski_idx_1 = find(isJetskiJumbo_1);
        
        if ~isempty(jetski_idx_1)
            % Prefer jetski/jumbo; if multiple, take closest
            [~, best_idx] = min(abs(SM_dates(idx_candidates_1(jetski_idx_1)) - SurveyDate1));
            idx_s1 = idx_candidates_1(jetski_idx_1(best_idx));
        else
            % No jetski/jumbo, take closest overall
            [~, best_idx] = min(abs(SM_dates(idx_candidates_1) - SurveyDate1));
            idx_s1 = idx_candidates_1(best_idx);
        end
    else
        % No survey within 1 day, find closest
        [~, idx_s1] = min(abs(SM_dates - SurveyDate1));
    end
    
    % For SurveyDate2: find all surveys within 1 day, prefer jetski/jumbo
    idx_candidates_2 = find(abs(SM_dates - SurveyDate2) <= 1);
    if ~isempty(idx_candidates_2)
        % Check if any are jetski/jumbo
        isJetskiJumbo_2 = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
            {SM(idx_candidates_2).File});
        jetski_idx_2 = find(isJetskiJumbo_2);
        
        if ~isempty(jetski_idx_2)
            % Prefer jetski/jumbo; if multiple, take closest
            [~, best_idx] = min(abs(SM_dates(idx_candidates_2(jetski_idx_2)) - SurveyDate2));
            idx_s2 = idx_candidates_2(jetski_idx_2(best_idx));
        else
            % No jetski/jumbo, take closest overall
            [~, best_idx] = min(abs(SM_dates(idx_candidates_2) - SurveyDate2));
            idx_s2 = idx_candidates_2(best_idx);
        end
    else
        % No survey within 1 day, find closest
        [~, idx_s2] = min(abs(SM_dates - SurveyDate2));
    end
    
    % Get elevation profiles
    Z1D_start = SM(idx_s1).Z1Dmean;
    Z1D_end = SM(idx_s2).Z1Dmean;
    X1D_start = SM(idx_s1).X1D;
    X1D_end = SM(idx_s2).X1D;
    
    % Interpolate to common cross-shore grid
    if ~isnan(min(Z1D_start)) && length(Z1D_start) > 1
        % Remove NaNs and duplicate x values for interpolation
        valid_idx_s1 = isfinite(Z1D_start) & isfinite(X1D_start);
        X1D_s1_clean = X1D_start(valid_idx_s1);
        Z1D_s1_clean = Z1D_start(valid_idx_s1);
        [X1D_s1_uniq, ia, ~] = unique(X1D_s1_clean);
        Z1D_s1_uniq = Z1D_s1_clean(ia);
        
        if length(X1D_s1_uniq) > 1
            Z_start(m,:) = interp1(X1D_s1_uniq, Z1D_s1_uniq, X_cross_shore, 'linear', nan);
        end
    end
    
    if ~isnan(min(Z1D_end)) && length(Z1D_end) > 1
        % Remove NaNs and duplicate x values for interpolation
        valid_idx_s2 = isfinite(Z1D_end) & isfinite(X1D_end);
        X1D_s2_clean = X1D_end(valid_idx_s2);
        Z1D_s2_clean = Z1D_end(valid_idx_s2);
        [X1D_s2_uniq, ia, ~] = unique(X1D_s2_clean);
        Z1D_s2_uniq = Z1D_s2_clean(ia);
        
        if length(X1D_s2_uniq) > 1
            Z_end(m,:) = interp1(X1D_s2_uniq, Z1D_s2_uniq, X_cross_shore, 'linear', nan);
        end
    end
    
    % Calculate elevation change
    Z_change(m,:) = Z_end(m,:) - Z_start(m,:);
end

fprintf('\nElevation map built: %d MOPs x %d cross-shore points\n', n_mops, NumSubTrans);

%% Smooth elevation data along alongshore direction for visual appeal
fprintf('Smoothing elevation data along alongshore direction...\n');

% Apply moving mean smoothing along MOPs (rows) to reduce sharp jumps
SmoothWindow = 3;  % Smooth over 3 adjacent MOPs
for j = 1:NumSubTrans
    valid_idx = isfinite(Z_change(:, j));
    if sum(valid_idx) > SmoothWindow
        Z_change(valid_idx, j) = movmean(Z_change(valid_idx, j), SmoothWindow, 'omitnan');
    end
end

fprintf('Smoothing complete.\n');

%% Collect all quarterly surveys from initial date to current end date for profile plot
fprintf('Collecting quarterly surveys for profile panel...\n');

% Find all quarterly surveys from the first date in QuarterPairs to current SurveyDate2
FirstDate = QuarterPairs(1, 1);  % Initial survey date
AllQuarterlySurveys = [FirstDate];  % Start with initial survey

% Add all end dates from quarters 1 through current quarter q
for qq = 1:q
    if QuarterPairs(qq, 2) ~= FirstDate  % Don't duplicate
        AllQuarterlySurveys = [AllQuarterlySurveys; QuarterPairs(qq, 2)];
    end
end

% Sort chronologically
AllQuarterlySurveys = sort(unique(AllQuarterlySurveys));

fprintf('  Plotting %d surveys from %s to %s\n', length(AllQuarterlySurveys), ...
    datestr(AllQuarterlySurveys(1), 'mmm dd, yyyy'), ...
    datestr(AllQuarterlySurveys(end), 'mmm dd, yyyy'));

%% Create figure with Google Maps background
fprintf('\nCreating figure with Google Maps background...\n');

% Create wider figure for three panels (map + profiles + wave timeseries)
% Sized for PowerPoint: 16:9 aspect ratio, 1600x900 pixels
figure('position', [100 100 1600 900],'color', 'w');

% Create left axis for elevation map (40% of width, top 70% of height)
ax_map = subplot('Position', [0.05 0.32 0.35 0.62]);

% Get lat/lon bounds for the MOP range
MopStart_idx = MopStart;
MopEnd_idx = MopEnd + 1;
if MopEnd_idx > length(Mop.BackLon)
    MopEnd_idx = length(Mop.BackLon);
end

% Back beach points (landward)
BackLons = Mop.BackLon(MopStart_idx:MopEnd_idx);
BackLats = Mop.BackLat(MopStart_idx:MopEnd_idx);
% Offshore points (seaward)
OffLons = Mop.OffLon(MopStart_idx:MopEnd_idx);
OffLats = Mop.OffLat(MopStart_idx:MopEnd_idx);

% Set axis limits with some padding
lon_min = min([BackLons; OffLons]) - 0.001;
lon_max = max([BackLons; OffLons]) + 0.001;
lat_min = min([BackLats; OffLats]) - 0.001;
lat_max = max([BackLats; OffLats]) + 0.001;

set(ax_map, 'xlim', [lon_min lon_max], 'ylim', [lat_min lat_max]);

% Plot Google Maps background
fprintf('Downloading Google Maps background...\n');
plot_google_map('MapType', 'satellite', 'Alpha', MapAlpha);

hold(ax_map, 'on');

%% Plot elevation change as pcolor
fprintf('Overlaying elevation change data...\n');

% Convert MOP numbers and cross-shore distances to lat/lon
% Create coordinate arrays for each (MOP, X_cross_shore) point
Lon_grid = nan(n_mops, NumSubTrans);
Lat_grid = nan(n_mops, NumSubTrans);

for m = 1:n_mops
    MopNumber = MopNumbers(m);
    mop_idx = round(MopNumber);
    
    if mop_idx >= 1 && mop_idx + 1 <= length(Mop.BackLon)
        BackLon = Mop.BackLon(mop_idx);
        BackLat = Mop.BackLat(mop_idx);
        OffLon = Mop.OffLon(mop_idx);
        OffLat = Mop.OffLat(mop_idx);
        
        % Get the max cross-shore distance for this MOP
        Z_prof = Z_start(m,:);
        valid_idx = isfinite(Z_prof);
        if any(valid_idx)
            x_max_mop = max(X_cross_shore(valid_idx));
        else
            x_max_mop = X_cross_shore(end);
        end
        
        % For each cross-shore point, interpolate lat/lon
        for j = 1:NumSubTrans
            X_xshore = X_cross_shore(j);
            frac = X_xshore / x_max_mop;
            frac = max(0, min(1, frac));
            
            Lon_grid(m, j) = BackLon + frac * (OffLon - BackLon);
            Lat_grid(m, j) = BackLat + frac * (OffLat - BackLat);
        end
    end
end

% Plot elevation change using pcolor
cmap = flipud(polarmap(256));
h_pcolor = pcolor(ax_map, Lon_grid, Lat_grid, Z_change);
shading(ax_map, 'flat');
colormap(ax_map, cmap);
cbar = colorbar(ax_map);
cbar.Label.String = 'Elevation Change (m)';
set(ax_map, 'clim', [-2, 2]);

%% Overlay contour lines
fprintf('Overlaying elevation contours...\n');

for cont_level = ContourLevels
    % For each MOP, find cross-shore location of the contour level at start date
    Lon_contour = [];
    Lat_contour = [];
    
    for m = 1:n_mops
        MopNumber = MopNumbers(m);
        mop_idx = round(MopNumber);
        
        % Get elevation profile at start date for this MOP
        Z_profile = Z_start(m,:);
        
        if any(isfinite(Z_profile))
            % Find where profile crosses the contour level
            valid_idx = isfinite(Z_profile);
            X_valid = X_cross_shore(valid_idx);
            Z_valid = Z_profile(valid_idx);
            
            if length(Z_valid) > 1
                % Check if contour level is within range
                if cont_level >= min(Z_valid) && cont_level <= max(Z_valid)
                    % Interpolate cross-shore distance at contour level
                    [Z_sorted, sort_idx] = sort(Z_valid, 'ascend');
                    X_sorted = X_valid(sort_idx);
                    
                    X_at_contour = interp1(Z_sorted, X_sorted, cont_level, 'linear');
                    
                    if ~isnan(X_at_contour) && mop_idx >= 1 && mop_idx + 1 <= length(Mop.BackLon)
                        BackLon = Mop.BackLon(mop_idx);
                        BackLat = Mop.BackLat(mop_idx);
                        OffLon = Mop.OffLon(mop_idx);
                        OffLat = Mop.OffLat(mop_idx);
                        
                        % Get max xshore for this MOP
                        Z_prof = Z_start(m,:);
                        valid_idx_m = isfinite(Z_prof);
                        if any(valid_idx_m)
                            x_max_mop = max(X_cross_shore(valid_idx_m));
                        else
                            x_max_mop = X_cross_shore(end);
                        end
                        
                        frac = X_at_contour / x_max_mop;
                        frac = max(0, min(1, frac));
                        
                        Lon_c = BackLon + frac * (OffLon - BackLon);
                        Lat_c = BackLat + frac * (OffLat - BackLat);
                        
                        Lon_contour = [Lon_contour; Lon_c];
                        Lat_contour = [Lat_contour; Lat_c];
                    end
                end
            end
        end
    end
    
    % Plot contour line
    if ~isempty(Lon_contour)
        h_contour = plot(ax_map, Lon_contour, Lat_contour, 'k-', 'linewidth', 1.5);
        h_contour.Color(4) = 0.7;  % Set alpha transparency
        % Label contour at midpoint
        mid_idx = round(length(Lon_contour) / 2);
        if mid_idx >= 1 && mid_idx <= length(Lon_contour)
            text(ax_map, Lon_contour(mid_idx), Lat_contour(mid_idx), ...
                sprintf('  %+.0f m', cont_level), 'color', 'k', 'fontsize', 9, ...
                'backgroundcolor', 'w', 'margin', 1, 'edgecolor', 'none');
        end
    end
end

%% Draw MOP transect lines
fprintf('Drawing MOP transect boundaries...\n');

for m = 1:n_mops
    MopNumber = MopNumbers(m);
    mop_idx = round(MopNumber);
    
    if mop_idx >= 1 && mop_idx + 1 <= length(Mop.BackLon)
        % Back beach to offshore line
        plot(ax_map, [Mop.BackLon(mop_idx) Mop.OffLon(mop_idx)], ...
             [Mop.BackLat(mop_idx) Mop.OffLat(mop_idx)], ...
             'y-', 'linewidth', 0.5);
    end
end

%% Format map panel
set(ax_map, 'fontsize', 11);
xlabel(ax_map, 'Longitude', 'fontsize', 12, 'fontweight', 'bold');
ylabel(ax_map, 'Latitude', 'fontsize', 12, 'fontweight', 'bold');
title(ax_map, sprintf('Torrey Pines Elevation Change\n%s to %s', ...
    datestr(SurveyDate1, 'mmm dd, yyyy'), ...
    datestr(SurveyDate2, 'mmm dd, yyyy')), ...
    'fontsize', 14, 'fontweight', 'bold');
set(ax_map, 'fontsize', 10);

%% Create right panel: Profile evolution plot
fprintf('Creating profile evolution panel...\n');

% Create right axis for profiles (60% of width, top 70% of height)
ax_profile = subplot('Position', [0.44 0.32 0.54 0.62]);

% Define colors: preallocate based on maximum possible surveys in entire date range
% This ensures consistent colors across all quarterly plots
MaxPossibleSurveys = size(QuarterPairs, 1) + 1;  % All quarterly end dates plus initial
col_all = jet(MaxPossibleSurveys);

% Map current surveys to the preallocated color scheme
nsurveys = length(AllQuarterlySurveys);
% Find indices in the full QuarterPairs array
color_indices = zeros(nsurveys, 1);
for ns = 1:nsurveys
    % Find which quarter this survey corresponds to
    if AllQuarterlySurveys(ns) == QuarterPairs(1, 1)
        color_indices(ns) = 1;  % Initial survey
    else
        [~, qidx] = min(abs(QuarterPairs(:, 2) - AllQuarterlySurveys(ns)));
        color_indices(ns) = qidx + 1;  % Offset by 1 for initial survey
    end
end
col = col_all(color_indices, :);

% Plot each survey averaged over all MOPs
hold(ax_profile, 'on');
for ns = 1:nsurveys
    TargetDate = AllQuarterlySurveys(ns);
    
    % Collect profiles from all MOPs and concatenate
    z1t = [];
    x1t = [];
    
    for MopNumber = MopStart:MopEnd
        MopID = sprintf('M%5.5i', MopNumber);
        load([MopID 'SM.mat'], 'SM');
        SM_dates = [SM.Datenum];
        
        % Find survey for this date (prefer jetski/jumbo)
        idx_candidates = find(abs(SM_dates - TargetDate) <= 1);
        if ~isempty(idx_candidates)
            isJetskiJumbo = cellfun(@(x) ~isempty(strfind(x, 'etski')) | ~isempty(strfind(x, 'umbo')), ...
                {SM(idx_candidates).File});
            jetski_idx = find(isJetskiJumbo);
            
            if ~isempty(jetski_idx)
                [~, best_idx] = min(abs(SM_dates(idx_candidates(jetski_idx)) - TargetDate));
                idx_survey = idx_candidates(jetski_idx(best_idx));
            else
                [~, best_idx] = min(abs(SM_dates(idx_candidates) - TargetDate));
                idx_survey = idx_candidates(best_idx);
            end
        else
            [~, idx_survey] = min(abs(SM_dates - TargetDate));
        end
        
        % Concatenate profile data from this MOP
        x1t = [x1t SM(idx_survey).X1D];
        z1t = [z1t SM(idx_survey).Z1Dmedian];
    end
    
    % Sort by cross-shore distance
    [x1_sorted, sort_idx] = sort(x1t, 'ascend');
    z1_sorted = z1t(sort_idx);
    
    % Apply moving mean smoothing over sorted data (120 points as in TorreyPlotProfiles.m)
    z1_smooth = movmean(z1_sorted - 0.774, 120, 'omitnan');  % Convert to MSL
    
    % Set line properties: bold for initial and final surveys, thin for middle surveys
    if ns == 1
        % Initial survey: bold colored line
        plot(ax_profile, x1_sorted, z1_smooth, '-', 'color', col(ns,:), ...
            'linewidth', 3, 'DisplayName', datestr(TargetDate, 'mmm dd, yyyy'));
    elseif ns == nsurveys
        % Final survey: bold black line
        plot(ax_profile, x1_sorted, z1_smooth, 'k-', 'linewidth', 3, ...
            'DisplayName', datestr(TargetDate, 'mmm dd, yyyy'));
    else
        % Middle surveys: thin colored lines
        plot(ax_profile, x1_sorted, z1_smooth, '-', 'color', col(ns,:), ...
            'linewidth', 1, 'DisplayName', datestr(TargetDate, 'mmm dd, yyyy'));
    end
end

% Format profile plot
set(ax_profile, 'xdir', 'reverse', 'xlim', [0 550], 'ylim', [-10 3], 'fontsize', 11);
grid(ax_profile, 'on');
xlabel(ax_profile, 'Cross-Shore Distance (m)', 'fontsize', 12, 'fontweight', 'bold');
ylabel(ax_profile, 'Elevation (m, MSL)', 'fontsize', 12, 'fontweight', 'bold');
title(ax_profile, sprintf('MOP %d-%d Average Profile Evolution', MopStart, MopEnd), ...
    'fontsize', 14, 'fontweight', 'bold');
legend(ax_profile, 'location', 'northwest', 'fontsize', 9);

%% Create bottom panel: Wave timeseries
if waveDataAvailable
    fprintf('Creating wave timeseries panel...\n');
    
    % Create bottom axis for wave timeseries (full width, bottom 20% of height)
    ax_wave = subplot('Position', [0.05 0.08 0.93 0.18]);
    
    % Set y-axis limits
    ylim_wave = [0 max(Hs)*1.1];
    
    % Shade the quarter period between SurveyDate1 and SurveyDate2 (pale red)
    fill(ax_wave, [SurveyDate1 SurveyDate2 SurveyDate2 SurveyDate1], ...
        [ylim_wave(1) ylim_wave(1) ylim_wave(2) ylim_wave(2)], ...
        [1 0.8 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    hold(ax_wave, 'on');
    
    % Plot raw wave height timeseries (faint blue, thin line)
    plot(ax_wave, timeW, Hs, '-', 'Color', [0.6 0.7 0.9], 'linewidth', 0.8);
    
    % Plot 30-day moving mean on top (bold blue)
    plot(ax_wave, timeW, Hs_monthly, 'b-', 'linewidth', 1.8);
    
    % Plot dots for all quarterly surveys
    for ns = 1:length(AllQuarterlySurveys)
        [~, tidx] = min(abs(timeW - AllQuarterlySurveys(ns)));
        if ~isempty(tidx)
            if ns == 1 || ns == length(AllQuarterlySurveys)
                % Bold dots for initial and final
                plot(ax_wave, AllQuarterlySurveys(ns), Hs_monthly(tidx), 'k.', 'markersize', 15);
            else
                % Smaller dots for middle surveys
                plot(ax_wave, AllQuarterlySurveys(ns), Hs_monthly(tidx), 'k.', 'markersize', 10);
            end
        end
    end
    
    % Format wave panel
    set(ax_wave, 'xlim', [dateStart dateEnd], 'ylim', ylim_wave);
    ylabel(ax_wave, 'Hs (m)', 'fontsize', 11, 'fontweight', 'bold');
    xlabel(ax_wave, 'Date', 'fontsize', 11, 'fontweight', 'bold');
    datetick(ax_wave, 'x', 'mmm yyyy', 'keeplimits');
    grid(ax_wave, 'on');
    title(ax_wave, sprintf('Significant Wave Height (30-day moving mean in bold)'), ...
        'fontsize', 12, 'fontweight', 'bold');
    set(ax_wave, 'fontsize', 10);
end

%% Format overall figure
set(gcf, 'InvertHardcopy', 'off');

%% Save figure to file
dt1_str = datestr(SurveyDate1, 'yyyymmdd');
dt2_str = datestr(SurveyDate2, 'yyyymmdd');
filename = fullfile(OutputDir, sprintf('ElevationChangeAndProfileMap_M%d-%d_%s_to_%s.png', ...
    MopStart, MopEnd, dt1_str, dt2_str));
fprintf('Saving figure to: %s\n', filename);
print(gcf, filename, '-dpng', '-r150');
close(gcf);

end  % End of quarterly loop

fprintf('\n========================================\n');
fprintf('All quarterly plots complete!\n');
fprintf('Saved to: %s\n', OutputDir);
fprintf('========================================\n');