% CombineTBR23ElevationMaps.m
%
% Creates a composite 2x2 figure combining 4 consecutive elevation change maps
% from MopRangeElevationChangeMapTBR23.m output
% Useful for publication figures showing elevation change progression

clear all
close all

%% USER SETTINGS
OutputDir = pwd;           % Directory containing the elevation change PNG files
MopStart = 576;            % MOP range used in original analysis
MopEnd = 590;
NumMapsToStack = 4;        % Number of maps to show in one composite (2x2 grid)

% Find all elevation change map files
fprintf('Searching for elevation change map files...\n');
FilePattern = fullfile(OutputDir, 'ElevationChangeAndProfileMap_TBR23_*.png');
FileList = dir(FilePattern);

if isempty(FileList)
    error('No elevation change map files found! Run MopRangeElevationChangeMapTBR23.m first.');
end

fprintf('Found %d elevation change maps\n', length(FileList));

% Sort by filename (which includes date)
[~, sort_idx] = sort({FileList.name});
FileList = FileList(sort_idx);

% Display available files
fprintf('\nAvailable files:\n');
for i = 1:length(FileList)
    fprintf('  %d: %s\n', i, FileList(i).name);
end

% Get user input for which maps to combine
if length(FileList) >= NumMapsToStack
    default_start = 1;
    prompt = sprintf('Enter starting index for composite figure (1-%d) [default %d]: ', ...
        length(FileList) - NumMapsToStack + 1, default_start);
    user_input = input(prompt, 's');
    if isempty(user_input)
        start_idx = default_start;
    else
        start_idx = str2double(user_input);
    end
else
    fprintf('Warning: Only %d files found, need at least %d for a full 2x2 grid\n', ...
        length(FileList), NumMapsToStack);
    start_idx = 1;
end

% Validate index
if start_idx < 1 || start_idx + NumMapsToStack - 1 > length(FileList)
    error('Invalid starting index!');
end

end_idx = min(start_idx + NumMapsToStack - 1, length(FileList));
SelectedFiles = FileList(start_idx:end_idx);

fprintf('\nSelected %d maps for composite figure:\n', length(SelectedFiles));
for i = 1:length(SelectedFiles)
    fprintf('  %s\n', SelectedFiles(i).name);
end

%% Create figure with 2x2 grid of maps
fprintf('\nCreating composite figure...\n');

% Create figure sized for paper (8.5" wide x 7" tall at 150 DPI = 1275x1050 pixels)
fig = figure('position', [100 100 1275 800], 'color', 'w');
set(fig, 'InvertHardcopy', 'off');

% Create 2x2 grid with shared margins
margin_top = 0.04;
margin_bottom = 0.05;
margin_left = 0.06;
margin_right = 0.08;
gap_h = 0.01;  % Horizontal gap between subplots (reduced)
gap_v = 0.005;  % Vertical gap between subplots (reduced)

% Calculate subplot dimensions
subplot_width = (1 - margin_left - margin_right - gap_h) / 2;
subplot_height = (1 - margin_top - margin_bottom - gap_v) / 2;

% Position coordinates for 2x2 grid (top-left, top-right, bottom-left, bottom-right)
positions = [
    margin_left, 1-margin_top-subplot_height, subplot_width, subplot_height;  % Top-left
    margin_left+subplot_width+gap_h, 1-margin_top-subplot_height, subplot_width, subplot_height;  % Top-right
    margin_left, 1-margin_top-2*subplot_height-gap_v, subplot_width, subplot_height;  % Bottom-left
    margin_left+subplot_width+gap_h, 1-margin_top-2*subplot_height-gap_v, subplot_width, subplot_height  % Bottom-right
];

%% Load and display each map image
subplot_labels = {'(a)', '(b)', '(c)', '(d)'};

for i = 1:length(SelectedFiles)
    % Read image
    filepath = fullfile(OutputDir, SelectedFiles(i).name);
    fprintf('Loading: %s\n', SelectedFiles(i).name);
    img = imread(filepath);
    
    % Create axis for this subplot
    ax = axes('Position', positions(i,:));
    imshow(img);
    hold on;
    
    % Add subplot label in top-left corner with white background
    [rows, cols, ~] = size(img);
    text_x = 20;
    text_y = 40;
    text(text_x, text_y, subplot_labels{i}, ...
        'fontsize', 16, 'fontweight', 'bold', 'color', 'black', ...
        'verticalalignment', 'top', 'horizontalalignment', 'left', ...
        'backgroundcolor', 'white', 'margin', 3, 'edgecolor', 'black', 'linewidth', 1);
    
    % Extract dates from filename for title
    % Filename format: ElevationChangeAndProfileMap_TBR23_M576-590_YYYYMMDD_to_YYYYMMDD.png
    filename_parts = strsplit(SelectedFiles(i).name, '_');
    date_start_str = filename_parts{end-1};
    date_end_str = filename_parts{end};
    date_end_str = regexprep(date_end_str, '.png', '');  % Remove .png
    
    % Convert datenum format to readable format
    datenum_start = datenum(date_start_str, 'yyyymmdd');
    datenum_end = datenum(date_end_str, 'yyyymmdd');
    
    title_str = sprintf('%s to %s', ...
        datestr(datenum_start, 'mmm dd, yyyy'), ...
        datestr(datenum_end, 'mmm dd, yyyy'));
    
    % Add title at bottom (outside the image)
    xlabel(ax, '', 'fontsize', 1);  % Clear default label
    text(cols/2, rows+80, title_str, ...
        'fontsize', 12, 'fontweight', 'bold', 'color', 'black', ...
        'horizontalalignment', 'center', ...
        'Parent', ax);
    
    axis off;
end

%% Add overall title
sgtitle(sprintf('Torrey Pines Elevation Change Progression (MOP %d-%d)\nFall-Winter 2022-2023', ...
    MopStart, MopEnd), 'fontsize', 18, 'fontweight', 'bold');

%% Save composite figure
output_filename = fullfile(OutputDir, ...
    sprintf('CompositeElevationChange_TBR23_M%d-%d_Maps%d-%d.png', ...
    MopStart, MopEnd, start_idx, end_idx));

fprintf('\nSaving composite figure to:\n  %s\n', output_filename);
exportgraphics(fig, output_filename, 'Resolution', 300);

fprintf('Composite figure created successfully!\n');
fprintf('Dimensions: 8.5 x 8.5 inches at 300 DPI\n');
fprintf('Suitable for journal publication (single page)\n');

close(fig);
