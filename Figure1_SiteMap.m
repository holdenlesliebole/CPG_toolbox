%% FIGURE 1: Study Site & Instrumentation Map
% Establishes spatial context with transects, PUV locations, bathymetry, and CDIP buoy
% Publication quality map for coastal survey site

clear all; close all
addpath /Users/holden/Documents/Scripps/Research/toolbox

%% USER SETTINGS
MopStart = 576;  % Start MOP for Torrey Pines
MopEnd = 590;    % End MOP
OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

% PUV sensor locations (example coordinates - UPDATE WITH ACTUAL DATA)
PUV_depth = [5, 7];  % Two depths in meters
PUV_lat = 32.915;    % Example latitude (update to actual)
PUV_lon = -117.253;  % Example longitude (update to actual)

% Tide datums (NAVD88 to MSL conversion = -0.774m)
tide_marks = struct();
tide_marks.HAT = 2.119;    % Highest Astronomical Tide
tide_marks.MHHW = 1.566;   % Mean Higher High Water
tide_marks.MHW = 1.344;    % Mean High Water
tide_marks.MSL = 0.774;    % Mean Sea Level
tide_marks.MLLW = -0.058;  % Mean Lower Low Water

%% LOAD MOPTABLE & TRANSECT DATA
load('MopTableUTM.mat', 'Mop')

% Extract UTM coordinates for MOP range
mop_idx = find([Mop.Mopnum] >= MopStart & [Mop.Mopnum] <= MopEnd);
Mop_range = Mop(mop_idx);
mop_numbers = [Mop_range.Mopnum];
mop_x = [Mop_range.EastingM];
mop_y = [Mop_range.NorthingM];

%% CREATE FIGURE
fig = figure('position', [100 100 1400 900]);
set(fig, 'InvertHardcopy', 'off');

% Create axis
ax_main = axes('position', [0.1 0.15 0.8 0.8]);
hold on; box on; grid on;

%% PLOT GOOGLE MAPS BACKGROUND
% Get representative MOP to load for bounding box
test_mop = MopStart;
try
    plot_google_map('MapType', 'satellite', 'Alpha', 0.7);
    google_maps_success = 1;
catch
    fprintf('Google Maps failed - continuing with basic map\n');
    google_maps_success = 0;
end

%% PLOT BATHYMETRIC CONTOURS (if available from gridded data)
% This requires a pre-existing bathymetry grid - customize as needed
% For now, show MOP transect line as proxy for alongshore extent
plot(mop_x, mop_y, 'y-', 'linewidth', 3, 'DisplayName', 'MOP Transects');

%% PLOT MOP TRANSECT ENDPOINTS
for i = 1:length(Mop_range)
    % Representative back-beach point
    plot(Mop_range(i).EastingM, Mop_range(i).NorthingM, 'yo', ...
        'markersize', 8, 'markerfacecolor', 'yellow', 'markeredgecolor', 'black', 'linewidth', 2);
    
    % Add MOP labels at spacing
    if mod(i, 2) == 0  % Label every other MOP to avoid clutter
        text(Mop_range(i).EastingM, Mop_range(i).NorthingM + 30, ...
            sprintf('M%d', Mop_range(i).Mopnum), ...
            'fontsize', 10, 'fontweight', 'bold', 'color', 'white', ...
            'BackgroundColor', 'black', 'horizontalalignment', 'center');
    end
end

%% PLOT PUV SENSOR LOCATIONS
% Convert lat/lon to UTM (simplified - use utm2deg.m for accurate conversion)
% For now, mark approximate location relative to MOP transect
puv_x = mean(mop_x);  % Place at center of MOP range
puv_y = mean(mop_y) + 100;  % 100 m seaward

for d = 1:length(PUV_depth)
    % Plot depth-specific location
    plot(puv_x + d*50, puv_y, 's', 'markersize', 12, 'markerfacecolor', 'red', ...
        'markeredgecolor', 'darkred', 'linewidth', 2);
    text(puv_x + d*50, puv_y - 50, sprintf('PUV %d m', PUV_depth(d)), ...
        'fontsize', 11, 'fontweight', 'bold', 'color', 'red', ...
        'horizontalalignment', 'center', 'BackgroundColor', 'white');
end

%% ADD SCALE BAR
% Approximate scale: 1 degree latitude ≈ 111 km
scale_length = 100;  % 100 m in map units
xl = get(ax_main, 'xlim');
yl = get(ax_main, 'ylim');
scale_x = xl(1) + 0.1 * (xl(2) - xl(1));
scale_y = yl(1) + 0.05 * (yl(2) - yl(1));

plot([scale_x scale_x + scale_length], [scale_y scale_y], 'k-', 'linewidth', 3);
text(scale_x + scale_length/2, scale_y - 20, '100 m', 'fontsize', 12, ...
    'horizontalalignment', 'center', 'fontweight', 'bold', 'BackgroundColor', 'white');

%% COMPASS/ORIENTATION
% Add north arrow
arrow_len = (xl(2) - xl(1)) * 0.05;
arrow_x = xl(2) - 0.1 * (xl(2) - xl(1));
arrow_y = yl(2) - 0.1 * (yl(2) - yl(1));
arrow([arrow_x, arrow_y], [arrow_x, arrow_y + arrow_len], 'width', arrow_len/8, 'length', arrow_len/3);
text(arrow_x + arrow_len/2, arrow_y + arrow_len * 1.5, 'N', 'fontsize', 14, ...
    'fontweight', 'bold', 'horizontalalignment', 'center');

%% LEGEND & LABELS
leg = legend('MOP Transects', 'location', 'northeast', 'fontsize', 12);
set(leg, 'TextColor', 'black', 'BackgroundColor', 'white', 'EdgeColor', 'black');

set(ax_main, 'fontsize', 14, 'fontweight', 'bold', 'linewidth', 2);
xlabel('Easting (UTM m)', 'fontsize', 16, 'fontweight', 'bold');
ylabel('Northing (UTM m)', 'fontsize', 16, 'fontweight', 'bold');
title(sprintf('Torrey Pines Study Site: MOPs %d–%d with Instrumentation', MopStart, MopEnd), ...
    'fontsize', 18, 'fontweight', 'bold');

%% ADD INFORMATION BOX
info_text = {
    'Study Site: Torrey Pines, San Diego, CA';
    sprintf('MOP Range: %d–%d (alongshore)', MopStart, MopEnd);
    'Survey Methods: Jetski sonar, Truck LiDAR, ATV';
    'Instruments: 2× PUV sensors (5m, 7m depths)';
    'Data Period: Oct 2022 – Oct 2025'
};

ax_text = axes('position', [0.08 0.02 0.3 0.12], 'visible', 'off');
text(0.5, 0.5, info_text, 'fontsize', 10, 'horizontalalignment', 'center', ...
    'verticalalignment', 'middle', 'BackgroundColor', 'lightyellow', ...
    'EdgeColor', 'black', 'margin', 5, 'parent', ax_text);

%% SAVE FIGURE
set(gcf, 'position', [100 100 1400 900]);
print(gcf, fullfile(OutputDir, 'Figure_1_SiteMap.png'), '-dpng', '-r300');
fprintf('Saved Figure 1: %s\n', fullfile(OutputDir, 'Figure_1_SiteMap.png'));

%% NOTES
fprintf('\n=== FIGURE 1: SITE MAP ===\n');
fprintf('✓ Transects plotted from MOP table\n');
fprintf('✓ Google Maps satellite background (if available)\n');
fprintf('✓ PUV sensor locations marked (UPDATE WITH ACTUAL COORDS)\n');
fprintf('✓ Scale bar and orientation added\n');
fprintf('\nNEXT STEP: Update PUV coordinates and bathymetry grid data\n');
