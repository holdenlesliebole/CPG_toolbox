%% FIGURE 8: Conceptual Schematic of Depth-Partitioned Recovery Mechanism
% Cross-shore sketch showing 3 zones with process arrows and labels
% Visual summary of paper's main mechanism

clear all; close all

OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

%% CREATE FIGURE
fig = figure('position', [100 100 1400 700]);
set(fig, 'InvertHardcopy', 'off');
ax = axes('position', [0.08 0.15 0.88 0.80]);
hold on;

%% DRAW BEACH PROFILE
% Simplified beach profile
x_profile = 0:1:150;
z_profile = 3 - 0.03*x_profile - 0.0002*x_profile.^2;

fill([x_profile, 150, 0], [z_profile, -15, -15], [0.8 0.7 0.6], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
plot(x_profile, z_profile, 'k-', 'linewidth', 2.5);

%% ZONE BACKGROUNDS WITH TRANSPARENCY
% Shallow zone (0-50m)
patch([0, 50, 50, 0], [-15, -15, 5, 5], [0.2 0.8 0.2], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

% Mid zone (50-100m)
patch([50, 100, 100, 50], [-15, -15, 5, 5], [0.8 0.8 0.2], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

% Deep zone (100-150m)
patch([100, 150, 150, 100], [-15, -15, 5, 5], [0.2 0.2 0.8], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

% Bathymetric contours
plot([0, 150], [-2, -2], 'b--', 'linewidth', 1);
plot([0, 150], [-4, -4], 'r-', 'linewidth', 2.5, 'alpha', 0.8);  % PIVOT DEPTH
plot([0, 150], [-6, -6], 'b--', 'linewidth', 1, 'alpha', 0.5);
plot([0, 150], [-10, -10], 'b--', 'linewidth', 1, 'alpha', 0.5);

% Datum references
plot([0, 150], [0.774, 0.774], 'k--', 'linewidth', 1, 'alpha', 0.4);

%% ZONE LABELS
text(25, 2.5, 'SHALLOW ZONE', 'fontsize', 14, 'fontweight', 'bold', ...
    'color', 'darkgreen', 'horizontalalignment', 'center', ...
    'BackgroundColor', 'lightyellow', 'EdgeColor', 'darkgreen', 'LineWidth', 2, 'Margin', 4);

text(75, 2.5, 'MID / PIVOT', 'fontsize', 14, 'fontweight', 'bold', ...
    'color', 'darkred', 'horizontalalignment', 'center', ...
    'BackgroundColor', 'lightyellow', 'EdgeColor', 'darkred', 'LineWidth', 2, 'Margin', 4);

text(125, 2.5, 'DEEP ZONE', 'fontsize', 14, 'fontweight', 'bold', ...
    'color', 'darkblue', 'horizontalalignment', 'center', ...
    'BackgroundColor', 'lightyellow', 'EdgeColor', 'darkblue', 'LineWidth', 2, 'Margin', 4);

%% ELEVATION MARKERS
text(-5, 0.774, 'MSL', 'fontsize', 10, 'fontweight', 'bold');
text(-5, -4, 'PIVOT', 'fontsize', 11, 'fontweight', 'bold', 'color', 'red');

%% CROSS-SHORE & DEPTH AXES
arrow([0, -15], [150, -15], 'width', 0.3, 'length', 5, 'BaseAngle', 45);
text(155, -15, 'Cross-shore →', 'fontsize', 11, 'fontweight', 'bold');

arrow([0, -15], [0, 5], 'width', 0.3, 'length', 0.5, 'BaseAngle', 45);
text(-8, 5.5, '↑ Elev.', 'fontsize', 11, 'fontweight', 'bold');

%% TRANSPORT ARROWS & PROCESS DESCRIPTIONS
arrow_width = 0.8;
arrow_length = 3;

% SHALLOW ZONE: Strong onshore transport
for y_pos = 0.5:-1:-1.5
    arrow([15, y_pos], [35, y_pos], 'width', arrow_width, 'length', arrow_length, ...
        'BaseAngle', 45, 'EdgeColor', 'darkgreen', 'FaceColor', 'lightgreen', 'LineWidth', 2);
end

text(45, -0.5, {'Shoaling → skewness'; 'Enhanced onshore transport'; '→ ACCRETION'}, ...
    'fontsize', 10, 'fontweight', 'bold', 'color', 'darkgreen', ...
    'BackgroundColor', 'white', 'EdgeColor', 'darkgreen', 'LineWidth', 2, 'Margin', 4);

% MID ZONE: Competing forces
for y_pos = -3:-1:-5
    % Rightward arrows (onshore)
    arrow([50, y_pos], [65, y_pos], 'width', arrow_width*0.6, 'length', arrow_length*0.6, ...
        'BaseAngle', 45, 'EdgeColor', [0.8 0.4 0], 'FaceColor', [1 0.7 0.3], 'LineWidth', 1.5);
    
    % Leftward arrows (offshore) - same magnitude
    arrow([85, y_pos], [70, y_pos], 'width', arrow_width*0.6, 'length', arrow_length*0.6, ...
        'BaseAngle', 45, 'EdgeColor', [0.4 0.4 0.8], 'FaceColor', [0.6 0.6 1], 'LineWidth', 1.5);
end

text(75, -6.5, {'Pivot region'; 'NONLINEAR transition'; 'F³ scaling governs'; 'net transport'}, ...
    'fontsize', 10, 'fontweight', 'bold', 'color', 'darkred', ...
    'BackgroundColor', 'white', 'EdgeColor', 'darkred', 'LineWidth', 2.5, 'Margin', 4);

% DEEP ZONE: Weak, balanced forces
for y_pos = -9:-1.5:-12
    % Very small arrows (oscillating)
    arrow([110, y_pos], [120, y_pos], 'width', arrow_width*0.3, 'length', arrow_length*0.3, ...
        'BaseAngle', 45, 'EdgeColor', [0.4 0.4 0.8], 'FaceColor', [0.7 0.7 1], 'LineWidth', 1);
    arrow([130, y_pos], [120, y_pos], 'width', arrow_width*0.3, 'length', arrow_length*0.3, ...
        'BaseAngle', 45, 'EdgeColor', [0.8 0.4 0], 'FaceColor', [1 0.7 0.3], 'LineWidth', 1);
end

text(125, -13.5, {'Deep oscillatory'; 'motion, weak net flux'; '→ MINIMAL CHANGE'}, ...
    'fontsize', 10, 'fontweight', 'bold', 'color', 'darkblue', ...
    'BackgroundColor', 'white', 'EdgeColor', 'darkblue', 'LineWidth', 2, 'Margin', 4);

%% CRITICAL PROCESS BOXES (Numbered)
% Box 1: Shoaling effect
rect1 = rectangle('Position', [5, -1.5, 15, 1], 'FaceColor', 'lightyellow', ...
    'EdgeColor', 'black', 'LineWidth', 1.5, 'LineStyle', '-');
text(12.5, -1, '①', 'fontsize', 16, 'fontweight', 'bold', 'horizontalalignment', 'center');
text(12.5, -2.2, 'Shoaling', 'fontsize', 9, 'fontweight', 'bold', 'horizontalalignment', 'center');

% Arrow from shoaling to skewness
plot([12.5, 20, 30], [-1.5, -2, -3], 'k-', 'linewidth', 1.5);
plot([30, 33], [-3, -3], 'k-', 'linewidth', 1.5);
plot([30, 28], [-3, -2.5], 'k-', 'linewidth', 1.5);

% Box 2: Velocity skewness
rect2 = rectangle('Position', [35, -3.5, 15, 1], 'FaceColor', 'lightyellow', ...
    'EdgeColor', 'black', 'LineWidth', 1.5, 'LineStyle', '-');
text(42.5, -3, '②', 'fontsize', 16, 'fontweight', 'bold', 'horizontalalignment', 'center');
text(42.5, -4.2, 'Skewness', 'fontsize', 9, 'fontweight', 'bold', 'horizontalalignment', 'center');

% Arrow from skewness to stress
plot([42.5, 45, 55], [-3.5, -6, -8], 'k-', 'linewidth', 1.5);
plot([55, 58], [-8, -8], 'k-', 'linewidth', 1.5);
plot([55, 53], [-8, -7.5], 'k-', 'linewidth', 1.5);

% Box 3: Bed stress
rect3 = rectangle('Position', [60, -8.5, 15, 1], 'FaceColor', 'lightyellow', ...
    'EdgeColor', 'black', 'LineWidth', 1.5, 'LineStyle', '-');
text(67.5, -8, '③', 'fontsize', 16, 'fontweight', 'bold', 'horizontalalignment', 'center');
text(67.5, -9.2, 'Bed stress', 'fontsize', 9, 'fontweight', 'bold', 'horizontalalignment', 'center');

% Arrow from stress to transport
plot([67.5, 70, 80], [-8.5, -9.5, -10], 'k-', 'linewidth', 1.5);
plot([80, 83], [-10, -10], 'k-', 'linewidth', 1.5);
plot([80, 78], [-10, -9.5], 'k-', 'linewidth', 1.5);

% Box 4: Sediment transport
rect4 = rectangle('Position', [85, -10.5, 15, 1], 'FaceColor', 'lightyellow', ...
    'EdgeColor', 'black', 'LineWidth', 1.5, 'LineStyle', '-');
text(92.5, -10, '④', 'fontsize', 16, 'fontweight', 'bold', 'horizontalalignment', 'center');
text(92.5, -11.2, 'Transport', 'fontsize', 9, 'fontweight', 'bold', 'horizontalalignment', 'center');

% Arrow from transport to morphology
plot([92.5, 95, 105], [-10.5, -11.5, -12], 'k-', 'linewidth', 1.5);
plot([105, 108], [-12, -12], 'k-', 'linewidth', 1.5);
plot([105, 103], [-12, -11.5], 'k-', 'linewidth', 1.5);

% Box 5: Morphological response
rect5 = rectangle('Position', [110, -12.5, 15, 1], 'FaceColor', 'lightyellow', ...
    'EdgeColor', 'darkgreen', 'LineWidth', 2.5, 'LineStyle', '-');
text(117.5, -12, '⑤ ΔBED', 'fontsize', 11, 'fontweight', 'bold', 'horizontalalignment', 'center', ...
    'color', 'darkgreen');
text(117.5, -13.2, 'Morphology', 'fontsize', 9, 'fontweight', 'bold', 'horizontalalignment', 'center', ...
    'color', 'darkgreen');

%% MECHANISM LABEL & EQUATION
text(75, 4.5, 'DEPTH-PARTITIONED RECOVERY MECHANISM', 'fontsize', 13, 'fontweight', 'bold', ...
    'horizontalalignment', 'center', 'BackgroundColor', 'lightyellow', ...
    'EdgeColor', 'black', 'LineWidth', 2, 'Margin', 4);

%% AXIS FORMATTING
set(ax, 'xlim', [-15, 160], 'ylim', [-14, 5], 'fontsize', 12, 'linewidth', 1.5);
set(ax, 'xtick', [], 'ytick', []);
set(ax, 'box', 'off');

%% KEY EQUATION BOX
eq_text = {
    'GOVERNING EQUATION (Shallow zone):';
    '$\frac{d\eta}{dt} = \alpha F^3$ for $F > F_c$';
    '';
    'where: η = bed elevation, F = energy flux,';
    'α = mobility coefficient, F_c = threshold'
};

ax_eq = axes('position', [0.65, 0.02, 0.30, 0.12], 'visible', 'off');
text(0.5, 0.5, eq_text, 'fontsize', 10, 'horizontalalignment', 'center', ...
    'verticalalignment', 'middle', 'parent', ax_eq, 'interpreter', 'latex', ...
    'BackgroundColor', 'lightyellow', 'EdgeColor', 'black', 'LineWidth', 1.5, 'Margin', 5);

%% TITLE
sgtitle('Figure 8: Conceptual Model of Depth-Partitioned Recovery', ...
    'fontsize', 18, 'fontweight', 'bold');

%% SUMMARY TEXT
summary_text = {
    'PHYSICAL MECHANISM:';
    '(① Shoaling) → (② Increased skewness) → (③ Higher bed stress) → (④ Onshore sediment flux) → (⑤ Beach accretion)';
    '';
    'DEPTH DEPENDENCE: Shoaling amplification only occurs above ~4m depth. Deeper regions experience weak, balanced forces → minimal net change.';
    '';
    'NONLINEARITY: Cubic scaling (F³) arises from threshold behavior + feedback interactions between wave kinematics and sediment transport.'
};

ax_summary = axes('position', [0.08, 0.00, 0.84, 0.10], 'visible', 'off');
text(0.5, 0.5, summary_text, 'fontsize', 9, 'horizontalalignment', 'center', ...
    'verticalalignment', 'middle', 'parent', ax_summary, 'FontName', 'Courier', ...
    'BackgroundColor', 'white', 'EdgeColor', 'black', 'LineWidth', 1, 'Margin', 4);

%% SAVE
set(gcf, 'position', [100 100 1400 700]);
print(gcf, fullfile(OutputDir, 'Figure_8_ConceptualSchematic.png'), '-dpng', '-r300');
fprintf('Saved Figure 8: %s\n', fullfile(OutputDir, 'Figure_8_ConceptualSchematic.png'));

fprintf('\n=== FIGURE 8: CONCEPTUAL SCHEMATIC SUMMARY ===\n');
fprintf('✓ Cross-shore profile with 3 depth zones\n');
fprintf('✓ Sediment transport arrows showing direction & magnitude\n');
fprintf('✓ Process chain: Shoaling → Skewness → Stress → Transport → Morphology\n');
fprintf('✓ 4m pivot depth highlighted\n');
fprintf('✓ Cubic scaling equation included\n');
fprintf('✓ Depth-dependent recovery mechanism illustrated\n');
