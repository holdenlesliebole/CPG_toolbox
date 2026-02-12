# Paper 1 Figure Generation Guide

## Overview
This guide outlines the structure, data requirements, and existing code resources for creating 8 main publication figures plus 10 supplemental figures for your depth-partitioned beach recovery paper.

---

## PART 1: USEFUL EXISTING CODES FOR EACH FIGURE TYPE

### Profile Evolution & Visualization
**Existing Scripts for Inspiration:**
- `PlotLast5QuarterlyProfiles.m` - Multi-survey profile plotting with legend/formatting
- `SIOplotLatestSurveyProfileChange.m` - Profile evolution with volume statistics
- `TBR23/TorreyRecoveryEvolutionMeanProfiles.m` - Alongshore-averaged profile evolution (DIRECT TEMPLATE)
- `PlotLatestSurveyProfiles.m` - Latest survey profile display with tide marks
- `MopOverview/EduardoJumboProfiles.m` - Seasonal profile comparison with color schemes

**Key Functions Available:**
- `GetAllNearestPointsProfile.m` - Extract profiles from survey data
- `GetCpgNearestPointProfiles.m` - Interpolate to common cross-shore grid
- `movmean()` - Smooth profiles across cross-shore distance

### Volume & Depth-Binning Analysis
**Existing Scripts for Inspiration:**
- `ExamplePlotReachJetskiVolumeEvolution.m` - Elevation-binned volume changes (CORE TEMPLATE)
- `ExampleXshoreVolumeChangeDensityPlot.m` - 2D density plots of volume redistribution
- `ExamplePlotReachJetskiVolumeEvolutionMovie.m` - Time-series volume animation
- `MopOverview/BuildMopSubaqueousStructArray.m` - Depth-zone volume partitioning
- `MopOverview/TestMopSubaqueousZoneDefinitions.m` - Zone definition (deep/mid/shallow bins)

**Key Code Patterns:**
```matlab
% Elevation binning for volume calculation
zRes = 0.5;  % 50 cm bins
z = round((Z1 - 0.774) * (1/zRes));  % Convert to bin indices
dv = [];
for iz = min(z(:)):max(z(:))
    dv(m) = sum(d(z == iz), 'omitnan');  % Volume per bin
end
```

### Wave Climate & Time Series
**Existing Scripts for Inspiration:**
- `WaveBadness2.m` - Long-term wave climate histograms
- `TBR23/PlotMeanElevChange.m` - Energy flux time series with Hs overlay
- `profiles/ExampleYatesStockdonTWLlocation.m` - Wave time series with tide integration
- `YatesConnorMop582ShorelineForecastLong.m` - Wave forcing with morphodynamic response

**Key Data Access:**
```matlab
% Access MOP wave data
stn = ['D' num2str(MopNumber, '%4.4i')];
urlbase = 'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';
dsurl = strcat(urlbase, stn, '_nowcast.nc');
wavehs = ncread(dsurl, 'waveHs');
wavetime = ncread(dsurl, 'waveTime');
wavetime = datetime(wavetime, 'ConvertFrom', 'posixTime');
```

### Energy Flux & Bottom Stress
**Existing Scripts for Inspiration:**
- `WaveBadness.m` / `WaveBadness2.m` - Energy flux histograms and temporal distributions
- `Runup/LinearDispersion.m` - Dispersion relation solver for group velocity
- `Runup/GetMopStockdonParams.m` - Unshoaling wave parameters from spectra
- `LongshoreTransport/GetCpgMopRadiationStresses.m` - Radiation stress calculations

**Key Equations (from LinearDispersion.m):**
- C.S. Wu algorithm for radian wavenumber from frequency & depth
- Group velocity: $C_g = \pi (f/k) [1 + \sigma/\sinh(\sigma)]$
- Energy flux: $F = C_g \times \text{Energy density}$
- Bed stress from wave parameters at measured depths

### Spatial Maps & Elevation Change
**Existing Scripts for Inspiration:**
- `ExamplePlotCombinedJumboSGelevationChangeNorthTP.m` - 2D elevation change maps
- `MopRangeElevationChangeMap.m` - Multi-panel elevation change (WITH Google Maps background)
- `Solana/*.m` series - Regional comparison plots

**Key Colormaps:**
- `polarmap.m` - Red (erosion) to Blue (accretion)
- `BeachColorbar.m` / `BeachColorMap.mat` - Specialized beach colormaps

### Conceptual Diagrams
**Approaches:**
- Use `arrow()`, `text()`, `patch()` for schematic elements
- Layer arrows to show sediment transport processes
- Add boxes/rectangles for zone definitions
- Label with large fonts for publication quality

---

## PART 2: FIGURE-BY-FIGURE SPECIFICATIONS

### FIGURE 1: Study Site & Instrumentation Map

**Purpose:** Establish spatial context, instrument locations, survey coverage

**Data Requirements:**
- UTM coordinates of MOP transects
- PUV locations (depths, coordinates)
- Bathymetric contours (0, 2, 4, 6, 8, 10 m)
- CDIP buoy location(s)
- Regional context (San Diego County inset)

**Recommended Code Structure:**
1. Load `MopTableUTM.mat` for transect geometry
2. Use `plot_google_map()` for basemap
3. Overlay transect lines (yellow or red)
4. Mark PUV locations with special symbols
5. Add contours using `contour()` from bathymetry grid
6. Add legend with instrument types

**Output Format:** Single clean panel, 7×5 inches

**Key Functions to Leverage:**
- `PlotMopTransectUTM.m` - Transect plotting
- `plot_google_map.m` - Satellite background

---

### FIGURE 2: Wave Climate Context (Long-Term + Experiment Period)

**Purpose:** Show the forcing context (winter 22–23 was energetic, summer 23 was weak)

**Data Requirements:**
- 10-year monthly mean $H_s$ with ±1 std
- Daily $H_s$ and $T_p$ during 2022–2024
- Wave energy partitioning (sea vs. swell)
- Anomalies relative to long-term mean

**Recommended Panel Layout:**
- Panel A: 10-year long-term context with highlighted experimental window
- Panel B: Daily smoothed $H_s$ and $T_p$ (2022–2024)
- Panel C: Energy partitioning by frequency band

**Key Code:**
```matlab
% Load CDIP buoy spectra data
[Freq, Bw, TimeUTC, a0, a1, b1, a2, b2] = getcdipBuoyAndModelnetcdf(buoyid);
Hs = 4 * sqrt(Bw' * a0);  % Significant wave height

% Monthly statistics
yyaxis left
plot(datenum(wavetime), Hs, 'b-', 'linewidth', 1);
movmean(Hs, 30, 'omitnan');  % 30-day moving average

% Anomalies
Hs_anom = Hs - nanmean(Hs);
```

**Output Format:** 3-panel figure, 16×10 inches

---

### FIGURE 3: Cross-Shore Profile Evolution

**Purpose:** Visualize morphology changes across depth zones

**Data Requirements:**
- Profile surveys at key dates (Oct 2022, Jan 2023, Jul 2023, Oct 2023)
- Alongshore-averaged profiles
- Elevation change profiles (Δz from Oct 2022 baseline)

**Recommended Panel Layout:**
- Panel A: Absolute elevations for 4 key survey dates
- Panel B: Elevation change relative to Oct 2022
- Panel C (inset): Bar crest cross-shore position vs. time

**Key Code Template (from TorreyRecoveryEvolutionMeanProfiles.m):**
```matlab
% Get representative MOPs (e.g., 580-589 for Torrey Pines)
for n = 1:length(survey_dates)
    xt = [];
    zt = [];
    % Loop through MOPs and concatenate profiles
    for m = MopStart:MopEnd
        load(['M' sprintf('%5.5d', m) 'SM.mat'])
        % Find survey date in SM struct
        idx = find(abs([SM.Datenum] - survey_dates(n)) < 1);
        if ~isempty(idx)
            z1 = SM(idx).Z1Dmean;
            x1d = SM(idx).X1D;
            % Interpolate and concatenate
            xt = [xt; x1d];
            zt = [zt; z1];
        end
    end
    % Plot mean profile
    plot(xt, mean(zt, 'omitnan'), '-', 'linewidth', 2, ...
        'DisplayName', datestr(survey_dates(n)));
end
```

**Output Format:** 3-panel figure, 14×8 inches

---

### FIGURE 4: Waves, Volumes, and Beach Width

**Purpose:** Connect wave climate to profile recovery narrative

**Data Requirements:**
- Time series (April–October 2023):
  - Significant wave height $H_s(t)$
  - Total volume change
  - Subaerial volume only
  - Subaqueous volume (deep vs. shallow bins)
  - Beach width at fixed elevation (e.g., MSL)

**Recommended Panel Layout:**
- Panel A (top): Hs(t) with sea/swell shading
- Panel B: Total volume anomaly
- Panel C: Subaerial volume
- Panel D: Subaqueous volume by depth bin
- Panel E (bottom): Beach width evolution

**Key Code Structure:**
```matlab
% Load SM files for volume calculations
for m = MopStart:MopEnd
    load(['M' sprintf('%5.5d', m) 'SM.mat'])
    % Calculate volume above MSL (0.774 m NAVD88) for each survey
    for s = 1:length(SM)
        idx = SM(s).Z1Dmean > 0.774;
        Vol_subaerial(m, s) = sum(SM(s).Z1Dmean(idx) - 0.774);
    end
end
% Time average across MOP range
VolTot = mean(Vol_subaerial, 1);
```

**Output Format:** 5-panel stacked figure, 16×12 inches

---

### FIGURE 5: Depth-Partitioned Volume Change / Pivot Depth

**Purpose:** Quantify depth-dependent recovery with 4 m pivot depth

**Data Requirements:**
- Time series of net ΔV per elevation bin:
  - Deep (−10 to −6 m)
  - Mid (−6 to −4 m)
  - Shallow (−4 to −2 m)
  - Inner (−2 m to shoreline)
- Survey dates from April to September (or custom range)

**Recommended Panel Layout:**
- Panel A: Time series of volume by depth bin (stacked area or grouped bars)
- Panel B: Hovmöller (time vs. cross-shore distance, colored by Δz)

**Key Code Template (from ExamplePlotReachJetskiVolumeEvolution.m):**
```matlab
% Elevation binning
zRes = 0.5;
z0 = round((Z0 - 0.774) * (1/zRes));  % Reference (Oct 2022) bins

% Loop through subsequent surveys
for n = 2:length(SurveyDates)
    Z = getSurveyGrid(n);
    dZ = Z - Z0;
    
    % Volume per bin
    for iz = min(z0(:)):max(z0(:))
        dv(iz) = sum(dZ(z0 == iz), 'omitnan') / zRes;
    end
    
    % Aggregate to depth zones
    deep_idx = find(z0 < -8/zRes);
    shallow_idx = find(z0 >= -4/zRes & z0 < -2/zRes);
    Vol_deep(n) = sum(dv(deep_idx));
    Vol_shallow(n) = sum(dv(shallow_idx));
end
```

**Output Format:** 2-panel figure, 14×10 inches

---

### FIGURE 6: Bottom Energy Flux & Bed Stress at 5 and 7 m

**Purpose:** Show depth-dependent forcing and mobilization thresholds

**Data Requirements:**
- Bottom energy flux $F(t)$ at 5 m and 7 m PUV locations
- Bed shear stress $\tau_b(t)$ from orbital velocity
- Critical shear stress threshold $\tau_{cr} \approx 0.2$ Pa
- Velocity skewness and asymmetry (optional)

**Recommended Panel Layout:**
- Panel A: Time series of bottom energy flux at two depths
- Panel B: Bed shear stress vs. critical threshold
- Panel C (optional): Velocity skewness/asymmetry

**Key Code:**
```matlab
% From wave parameters at PUV depths
[L, C, Cg] = LinearDispersion(Freq, depth_5m);  % 5 m depth
[L, C, Cg] = LinearDispersion(Freq, depth_7m);  % 7 m depth

% Energy flux = group velocity × wave energy
F_5m = Cg' * (energy_density_5m);
F_7m = Cg' * (energy_density_7m);

% Bed shear stress from velocity amplitude & frequency
U_b = sqrt(2 * energy_density);  % Orbital velocity amplitude
tau_b = 0.5 * rho * f_w * U_b.^2;  % Shields parameterization
f_w = 0.015;  % Dimensionless friction coefficient
```

**Output Format:** 3-panel figure, 16×10 inches

---

### FIGURE 7: Flux–Response Relationship & F³ Model Skill

**Purpose:** Show nonlinear cubic scaling between energy flux and morphological response

**Data Requirements:**
- Observed elevation change $\Delta z(x,t)$ near 4–5 m depth
- Bottom energy flux $F(t)$ time series
- Model predictions using $\Delta z \propto F^3$ relationship

**Recommended Panel Layout:**
- Panel A: Scatter $\Delta z$ vs. $F$ (shows threshold)
- Panel B: Scatter $\Delta z$ vs. $F^3$ (linear fit)
- Panel C: Time series observed vs. modeled $\Delta z$

**Key Code Structure:**
```matlab
% Collect data pairs
for t = 1:length(time_vector)
    Z_t = getSurveyElevation(t);
    F_t = getEnergyFlux(t);
    
    % Extract elevation change in 4-5 m depth zone
    idx = find(Z_ref >= -5 & Z_ref <= -4);
    dz_obs(t) = mean(Z_t(idx) - Z_ref(idx), 'omitnan');
end

% Fit model
threshold = 0.5;  % Energy flux threshold (m³/s)
idx_active = F_t > threshold;
coefficients = polyfit(F_t(idx_active).^3, dz_obs(idx_active), 1);

% Plot
scatter(F_t, dz_obs, 'k', 'filled');
hold on;
f_model = linspace(threshold, max(F_t), 100);
z_model = coefficients(1) * f_model.^3 + coefficients(2);
plot(f_model, z_model, 'r-', 'linewidth', 2);
```

**Output Format:** 3-panel figure, 16×8 inches

---

### FIGURE 8: Conceptual Schematic

**Purpose:** Visual summary of depth-partitioned recovery mechanism

**Data Requirements:** None (schematic only)

**Recommended Elements:**
- Cross-shore profile sketch with 3 depth zones
- Arrows showing sediment transport magnitude
- Labels:
  - Deep (6–10 m): "Frequent mobility, weak net flux"
  - Pivot (~4 m): "Shoaling-induced nonlinearities activate"
  - Shallow (0–3 m): "Surf/swash accretion zone"
- Process annotations (shoaling → skewness → stress → transport)

**Example Code:**
```matlab
figure('position', [100 100 1000 600]);

% Draw profile outline
x = [0:1:100]; z = 3 - 0.05*x;  % Simplified profile
plot(x, z, 'k-', 'linewidth', 3);
hold on;

% Add zone backgrounds
patch([0 40 40 0], [-10 -10 0 0], [0.9 0.9 1.0], 'FaceAlpha', 0.3);
text(20, -5, 'DEEP ZONE', 'fontsize', 14, 'fontweight', 'bold');

% Add arrows for sediment transport
arrow([25 -4], [25 -2], 'width', 1, 'length', 5);
text(28, -3, 'F³ Nonlinear', 'fontsize', 12);

% Add labels
text(0, 3.5, 'Shoreline', 'fontsize', 12, 'fontweight', 'bold');
text(100, -10.5, 'Seabed', 'fontsize', 12, 'fontweight', 'bold');
```

**Output Format:** Single wide panel, 14×6 inches

---

## PART 3: DATA WORKFLOW & LOADING PATTERNS

### Standard SM/SA Struct Loading
```matlab
% Survey Mean (SM) struct - contains averaged profiles
load(['M' sprintf('%5.5d', MopNumber) 'SM.mat'], 'SM')
% Fields: .Datenum, .X1D (cross-shore), .Z1Dmean, .Z1Dmedian, .File

% Survey Array (SA) struct - contains point cloud data
load(['M' sprintf('%5.5d', MopNumber) 'SA.mat'], 'SA')
% Fields: .Datenum, .X, .Y, .Z, .File, .Mopnum
```

### MOP Table Loading
```matlab
load('MopTableUTM.mat', 'Mop')
% Mop struct with transect coordinates for all MOPs
% Use to reference geospatial locations
```

### Wave Data Access (from CDIP)
```matlab
% Method 1: Real-time CDIP nowcast
stn = ['D' num2str(MopNumber, '%4.4i')];
urlbase = 'http://thredds.cdip.ucsd.edu/thredds/dodsC/cdip/model/MOP_alongshore/';
dsurl = [urlbase stn '_nowcast.nc'];
Hs = ncread(dsurl, 'waveHs');
```

### Combined Grid (SG) Struct for Multiple MOPs
```matlab
% From ExamplePlotCombinedJumboSGelevationChangeNorthTP.m
CG = CombineSGdata(mappath, MopStart, MopEnd);
% Returns combined grid data structure for entire MOP range
```

---

## PART 4: REUSABLE CODE PATTERNS

### Pattern 1: Multi-MOP Profile Concatenation
```matlab
for m = MopStart:MopEnd
    load(['M' sprintf('%5.5d', m) 'SM.mat'])
    idx = find(abs([SM.Datenum] - target_date) < 1);
    if ~isempty(idx)
        x_all = [x_all; SM(idx).X1D];
        z_all = [z_all; SM(idx).Z1Dmean];
    end
end
% Interpolate to common grid
z_interp = interp1(x_all, z_all, x_common, 'linear', NaN);
```

### Pattern 2: Elevation-Based Volume Binning
```matlab
zRes = 0.5;  % Bin resolution
z_bin = round((Z_ref - 0.774) * (1/zRes));
dV = NaN(max(z_bin(:)), 1);
for iz = min(z_bin(:)):max(z_bin(:))
    dV(iz) = sum(dZ(z_bin == iz), 'omitnan') / zRes;
end
```

### Pattern 3: Time Series Alignment & Interpolation
```matlab
% Common time vector
t_common = datenum(2022,10,1):1:datenum(2023,10,31);

for m = MopStart:MopEnd
    load(['M' sprintf('%5.5d', m) 'SM.mat'])
    t_m = [SM.Datenum];
    z_m = [SM.Z1Dmean];  % For single elevation
    
    % Interpolate to common times
    z_common = interp1(t_m, z_m, t_common, 'linear');
end
```

### Pattern 4: Wave Energy Flux Calculation
```matlab
% Group velocity from dispersion
[L, C, Cg] = LinearDispersion(Freq, Depth);

% Energy density from wave spectra
E = a0 .* Bw;  % (freq × time) array

% Energy flux
F = Cg' * E;  % (time) vector
```

### Pattern 5: Data Quality Filtering
```matlab
% Remove shallow/incomplete surveys
idx_valid = [];
for s = 1:length(SM)
    z_min = min(SM(s).Z1Dmean);
    if z_min < -3  % Subaqueous coverage check
        idx_valid = [idx_valid, s];
    end
end
SM_filtered = SM(idx_valid);
```

---

## PART 5: VISUALIZATION BEST PRACTICES

### Colormaps to Use
- **Elevation change:** `polarmap()` (red=erosion, blue=accretion)
- **Time series:** `jet()` with color preallocations for consistency
- **Beach morphology:** `BeachColorMap.mat` (specialized for coastal)
- **Energy flux:** `hot()` or `parula()` for 0→max scaling

### Font & Label Standards
```matlab
set(gca, 'fontsize', 16, 'linewidth', 2);
xlabel('Cross-shore Distance (m)', 'fontsize', 18, 'fontweight', 'bold');
ylabel('Elevation (m, NAVD88)', 'fontsize', 18, 'fontweight', 'bold');
title('Figure Title', 'fontsize', 20, 'fontweight', 'bold');
```

### Datum References
- **NAVD88:** Primary elevation datum in survey data
- **MSL:** NAVD88 - 0.774 m (standard local reference)
- **MHW:** NAVD88 - 1.344 m
- **MHHW:** NAVD88 - 1.566 m
- **HAT:** NAVD88 - 2.119 m

---

## PART 6: FILE OUTPUT & SAVING

```matlab
% High-quality PNG export for publication
set(gcf, 'position', [100 100 1600 1000]);  % Set figure size
set(gcf, 'InvertHardcopy', 'off');  % Preserve colors
print(gcf, 'Figure_1_SiteMap.png', '-dpng', '-r300');  % 300 DPI for printing

% PDF export (vectorized)
print(gcf, 'Figure_1_SiteMap.pdf', '-dpdf');
```

---

## Quick Reference: Which Existing Scripts to Adapt

| Figure | Primary Reference | Secondary Reference |
|--------|------------------|----------------------|
| 1 | `PlotMopTransectUTM.m` | `MopRangeElevationChangeMap.m` |
| 2 | `WaveBadness2.m` | `TBR23/PlotMeanElevChange.m` |
| 3 | `TBR23/TorreyRecoveryEvolutionMeanProfiles.m` | `PlotLast5QuarterlyProfiles.m` |
| 4 | `ExamplePlotReachJetskiVolumeEvolution.m` | Custom stacked time series |
| 5 | `ExampleXshoreVolumeChangeDensityPlot.m` | `ExamplePlotReachJetskiVolumeEvolution.m` |
| 6 | `WaveBadness.m` (energy flux) | `Runup/LinearDispersion.m` |
| 7 | `WaveBadness2.m` (scatter) | Custom regression fitting |
| 8 | Custom schematic | `arrow()`, `patch()` MATLAB functions |

