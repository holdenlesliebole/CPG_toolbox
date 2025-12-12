# Sand Volume Analysis Guide

## Overview

This repository contains extensive code for calculating, visualizing, and analyzing sand volume changes from your beach morphology survey data. The toolbox provides multiple plotting styles and analysis approaches ranging from simple volume difference maps to complex time-series anomaly tracking.

---

## Core Volume Calculation Functions

### Data Structure: SG (Spatial Grid)

The key to volume analysis is understanding the **SG (Spatial Grid)** structure:
- **Storage**: Individual Mop files like `M00582SG.mat`
- **Content**: 1m × 1m grid of survey elevation points (UTM coordinates, m NAVD88)
- **Volume Calculation**: Elevation difference between two surveys = volume change in m³
  
**Key Fields**:
- `SG.X, SG.Y, SG.Z` - UTM coordinates and elevation
- `SG.Datenum` - Survey date
- `SG.Source` - Data source (GPS, LiDAR, Drone, Multibeam, etc.)
- `SG.File` - Original survey file path

### Converting SG to 2D Grids

```matlab
% Convert sparse SG grid points to full 2D arrays
[X, Y, Z] = SG2grid(SG, SurveyIndex);

% X, Y - full UTM grid coordinates
% Z - full elevation grid with NaNs for no-data areas
```

### Combining Multiple Mops

```matlab
% Combine SG data across multiple Mops into a single grid
CG = CombineSGdata(mpath, MopStart, MopEnd);
% or
CG = SGcombineMops(MopStart, MopEnd);

% Result: A single struct array with all grid points from the Mop range
```

---

## Main Volume Analysis Scripts

### 1. **ExamplePlotReachJetskiVolumeEvolution.m** ⭐ RECOMMENDED START HERE

**Purpose**: Plot cross-shore volume evolution for a specified reach and date range

**What it does**:
- Loads jumbo survey grid data for a Mop range (e.g., Cardiff Mop 668-682)
- Identifies jetski surveys (those with data below -3m)
- Filters to specified date range
- Calculates volume changes relative to first survey
- Creates multiple visualization styles

**Key Outputs**:
- Volume change as function of starting elevation (binned)
- Seaward/shoreward deposition distribution
- First moment of deposition (center of mass change)
- Cross-shore profiles colored by volume change

**How to use**:
```matlab
%% Edit these settings:
mpath='/volumes/group/MOPS/';          % Path to data
MopStart=668; MopEnd=682;              % Mop range (e.g., Cardiff)
StartDate=datenum(2010,11,22);         % Date range
EndDate=datenum(2011,3,10);
zRes=0.5;                              % Elevation bin size (m)

%% Then run the script
% It will generate multiple plots showing volume changes
```

**Key Plots Generated**:
1. Volume change vs. initial elevation (scatter with binned stats)
2. Deposition distribution (where is sand going?)
3. Individual profile volume changes
4. Time series of total volume

---

### 2. **ExampleXshoreVolumeChangeDensityPlot.m** - Density Plot Style

**Purpose**: Create detailed 2D density plots of volume change across space

**What it does**:
- Creates elevation bins across the profile
- For each bin, plots how much volume change occurred
- Creates 2D heatmaps showing volume redistribution
- Computes statistics (mean, std, quantiles)

**Key Outputs**:
- 2D heatmap: cross-shore distance vs. elevation
- Volume change density by location and depth zone
- Statistical summaries

**How to use**:
```matlab
% Similar setup to ExamplePlotReachJetskiVolumeEvolution.m
% but generates different visualization style
zRes=0.5;  % Larger values = smoother results
```

---

### 3. **ExampleTrackSandVolume.m** - Volume Tracking Across Time Series

**Purpose**: Track how sand volume changes evolve through a survey sequence

**What it does**:
- Loads multiple surveys for a reach
- Calculates cumulative volume relative to baseline
- Tracks volume by survey type (UTAir, Truck, USACE, etc.)
- Creates time series of total volume change

**Key Code Pattern**:
```matlab
SG = CombineSGdata(mpath, MopStart, MopEnd);

% Loop through surveys
for SurvNum = 1:size(SG,2)
    x = SG(SurvNum).X;
    y = SG(SurvNum).Y;
    z = SG(SurvNum).Z;
    
    % Convert to 2D grid
    idx = sub2ind(size(X), y-miny+1, x-minx+1);
    Z1 = X*NaN;
    Z1(idx) = z;
    
    % Apply elevation thresholds
    Z1(Z1 < 0.774) = NaN;  % Below MSL
    Z1(Z1 > 3.0) = NaN;    % Above max elevation
    
    % Calculate volume
    vol = sum(Z1(:), 'omitnan');
    % Store results
end
```

---

### 4. **DuneVolume.m** & **DuneVolume2024.m** - Dune-Specific Analysis

**Purpose**: Calculate dune elevation and volume changes (e.g., Cardiff dune)

**What it does**:
- Combines multiple Mops (e.g., 670-678 for Cardiff dune)
- Creates baseline grid from reference survey
- Computes elevation difference (DEM of difference)
- Integrates volume over the dune area
- Visualizes on satellite basemap

**Key Features**:
- Elevation clipping at known barriers (e.g., riprap)
- Interpolation for incomplete coverage
- Google Maps satellite background overlay
- Normalization by reach length

**Output Visualization**:
```matlab
% Creates DEM of difference (DEM-DoD) plot
surf(Xl, Yl, Zd);  % Color-coded elevation change
% overlaid on satellite imagery
```

---

### 5. **EulerianAnomaly.m** & **EulerianAnomalyMovie.m** - Anomaly Tracking

**Purpose**: Calculate elevation anomalies at fixed cross-shore positions

**What it does**:
- Selects elevation contours on the mean profile (e.g., MSL+2.5m)
- Finds where each survey intersects that elevation
- Calculates cross-shore position anomalies (departure from mean)
- Creates time series of anomalies by elevation zone

**Key Settings**:
```matlab
ElvMsl = 2.5;  % Mean elevation in MSL
% This gets converted to NAVD88 by adding 0.774m

SeasonalAvgWindow = 3;  % 3-month running mean for seasonality
```

**Output**:
- Anomaly time series showing beach profile shifts
- Seasonal vs. long-term trends
- Movie showing anomaly evolution over time

---

### 6. **Solana Beach Volume Analysis Scripts** - Nourishment Tracking

**Purpose**: Specialized scripts for tracking sand nourishment project impacts

**Key Scripts**:
- `SolanaVolumeChange.m` - Volume comparison relative to baseline
- `SolanaVolumePostNurish*.m` (multiple date variants) - Post-nourishment volumes
- `SolanaVolumeChange2baseline.m` - Volume relative to pre-nourishment baseline
- `SolanaVolumeProfilesPostNurish.m` - Profile-based volume metrics

**Approach**:
1. Load ShoreBox baseline grid (`SolanaShoreboxMap.mat`)
2. Load survey data by date
3. Grid elevation data for each date
4. Calculate differences relative to baseline
5. Visualize on shorebox coordinate system

**Special Features**:
- Multiple data source integration (Truck, GPS ATV, Multibeam)
- Date-specific filtering (e.g., only GPS data from certain dates)
- Shorebox coordinate transformation for visualization
- Volume integration over specific reach boundaries

---

## Plotting Styles for Volume Data

### Plot Type 1: Volume Change vs. Initial Elevation (Binned)

```matlab
% From ExamplePlotReachJetskiVolumeEvolution.m
figure;
scatter(Zstart_bin, VolChange_bin, [], VolChange_bin, 'filled')
xlabel('Starting Elevation (m NAVD88)')
ylabel('Volume Change (m³)')
colorbar
% Shows where sand is eroding/depositing as function of depth zone
```

### Plot Type 2: 2D Heatmap - Cross-shore vs. Time

```matlab
% From EulerianAnomaly.m
imagesc(time, elevation_contours, anomaly_matrix)
xlabel('Time')
ylabel('Elevation Contour (m NAVD88)')
colorbar('Label', 'Cross-shore Anomaly (m)')
% Shows how beach profile shifts over time at different elevations
```

### Plot Type 3: DEM of Difference (DoD)

```matlab
% From DuneVolume.m
surf(X, Y, Zd)
shading flat
colormap(jet)
caxis([0 3])
% Spatial map showing exactly where elevation changes occurred
```

### Plot Type 4: 3D Surface Plot

```matlab
% Overlay on satellite basemap (from DuneVolume.m)
plot_google_map('MapType', 'satellite')
hold on
surf(X_lonlat, Y_latlon, Zd)
shading flat
view(2)
% Shows elevation changes in geographic context
```

### Plot Type 5: Volume Time Series

```matlab
% Track cumulative volume over survey sequence
plot(survey_dates, cumulative_volume)
datetick('x')
xlabel('Date')
ylabel('Cumulative Volume Change (m³)')
% Shows overall trend - is beach eroding or accreting?
```

### Plot Type 6: Anomaly Evolution (Movie)

```matlab
% From EulerianAnomalyMovie.m or DogBeachAnomalyEvolution.m
for n=1:num_surveys
    imagesc(x, y, anomaly_grid(:,:,n))
    title(datestr(survey_dates(n)))
    pause(0.5)  % Creates animation effect
end
% or save as GIF:
gif('anomaly_evolution.gif')
```

---

## Supporting Functions for Volume Analysis

### Volume Calculation Helpers

| Function | Purpose |
|----------|---------|
| `GetShoreface.m` | Extract intertidal zone elevation profile |
| `GetProfileMedianRoughness.m` | Compute roughness (high-frequency variation) |
| `GetCpgProfileBeachVolumes.m` | Calculate volume between elevation contours |
| `GetSolanaProfileVolumes.m` | Solana-specific profile volume extraction |
| `GetCpgProfileMobileVolumes.m` | Mobile LiDAR volume metrics |

### Coordinate & Grid Utilities

| Function | Purpose |
|----------|---------|
| `SG2grid.m` | Convert sparse SG points to full 2D grid |
| `CombineSGdata.m` | Merge SG files across multiple Mops |
| `SGcombineMops.m` | Load & combine Mop SG files |
| `UTM2MopCoords.m` | Convert UTM to Mop-relative coordinates |
| `UTMalongshoreGrid.m` | Create alongshore interpolation grids |
| `EqualSpacedPoints.m` | Generate regular point grids |

### Data Loading & Organization

| Function | Purpose |
|----------|---------|
| `DefineMopPath.m` | Set data directory paths |
| `GetTransectLines.m` | Load Mop transect definitions |
| `CombineSurveyDateSourceData.m` | Merge duplicate surveys |
| `AddLatestSGmatfiles.m` | Add new survey data to SG files |

---

## Workflow Examples

### Workflow A: Simple Volume Change Between Two Dates

```matlab
% 1. Setup
CpgDefineMopPath
MopNumber = 582;
load(['M' num2str(MopNumber,'%5.5i') 'SG.mat'], 'SG')

% 2. Find surveys
date1_idx = find([SG.Datenum] == datenum(2020,1,1));
date2_idx = find([SG.Datenum] == datenum(2020,12,31));

% 3. Convert to grids
[X1, Y1, Z1] = SG2grid(SG, date1_idx(1));
[X2, Y2, Z2] = SG2grid(SG, date2_idx(1));

% 4. Calculate volume change
Zd = Z2 - Z1;
total_volume_change = sum(Zd(:), 'omitnan');

% 5. Plot
figure
surf(X1, Y1, Zd)
shading flat
colormap(jet)
colorbar
title(['Volume Change: ' datestr(SG(date2_idx(1)).Datenum) ...
       ' vs ' datestr(SG(date1_idx(1)).Datenum)])
```

### Workflow B: Volume Analysis Across Mop Range (Cardiff Example)

```matlab
%% Setup
CpgDefineMopPath
MopStart = 668;
MopEnd = 682;

%% Load combined grid
CG = SGcombineMops(MopStart, MopEnd);

%% Find jetski surveys in date range
jetski = find(contains({CG.File}, 'umbo') & [CG.Datenum] >= datenum(2010,11,22) & [CG.Datenum] <= datenum(2011,3,10));

%% Calculate volumes
for j = 1:length(jetski)
    [X, Y, Z] = SG2grid(CG, jetski(j));
    
    % Volume above MSL (0.774m NAVD88)
    Z_subaerial = Z;
    Z_subaerial(Z < 0.774) = NaN;
    
    vol(j) = sum(Z_subaerial(:), 'omitnan');
    dates(j) = CG(jetski(j)).Datenum;
end

%% Plot time series
figure
plot(dates, vol, 'o-')
datetick('x')
ylabel('Subaerial Volume (m³)')
title(['Mop ' num2str(MopStart) '-' num2str(MopEnd)])
```

### Workflow C: Using ExamplePlotReachJetskiVolumeEvolution.m

```matlab
% 1. Open the script
edit ExamplePlotReachJetskiVolumeEvolution.m

% 2. Modify settings:
%    - mpath (data directory)
%    - MopStart, MopEnd (your area of interest)
%    - StartDate, EndDate (your time period)
%    - zRes (0.5m recommended for detail)

% 3. Run the entire script
% Script generates ~10-15 plots showing:
%    - Volume vs. elevation
%    - Time evolution
%    - Profile changes
%    - Statistical summaries
```

---

## Elevation Reference Levels

Common elevation thresholds used in analysis:

| Elevation (NAVD88) | Elevation (MSL) | Description |
|---|---|---|
| -3 m | -3.774 m | Offshore depth threshold |
| 0.0 m | -0.774 m | Mean Sea Level (MSL) equivalent |
| 0.774 m | 0 m | MSL (used as low-tide terrace/beach face boundary) |
| 1.344 m | +0.57 m | High water mark (typical beach/dune boundary) |
| 2.5 m | +1.726 m | Upper beach/dune zone |
| 4.7 m | +3.926 m | Example: Back of dune, base of riprap |

**Why these matter**:
- Subaerial volume: Z > 0.774m (MSL)
- Beach volume: 0.774m < Z < 2.5m
- Dune volume: Z > 2.5m (or custom threshold)

---

## Advanced Techniques

### 1. Volume by Elevation Zones

```matlab
% Divide profile into zones and calculate volumes separately
zones = struct();

% Subtidal zone: Z < 0.774m
Z_subtidal = Z;
Z_subtidal(Z >= 0.774) = NaN;
zones.subtidal_vol = sum(Z_subtidal(:), 'omitnan');

% Beach zone: 0.774m < Z < 2.5m
Z_beach = Z;
Z_beach(Z < 0.774 | Z >= 2.5) = NaN;
zones.beach_vol = sum(Z_beach(:), 'omitnan');

% Dune zone: Z >= 2.5m
Z_dune = Z;
Z_dune(Z < 2.5) = NaN;
zones.dune_vol = sum(Z_dune(:), 'omitnan');
```

### 2. Normalized Volume per Alongshore Length

```matlab
% Volume per unit alongshore distance (for comparing different reaches)
alongshore_length = (MopEnd - MopStart + 1) * 100;  % meters (100m per Mop)
vol_per_m = vol / alongshore_length;  % m³/m alongshore

fprintf('Volume change: %.0f m³/m (%.1f m³/m accumulated)\n', ...
    vol_per_m, vol_per_m * alongshore_length)
```

### 3. Contour Following Analysis (EulerianAnomaly Approach)

```matlab
% Track how specific elevation contours move over time

% Load GM (Global Mean) profiles
load(['M' num2str(MopNumber,'%5.5i') 'GM.mat'], 'GM')

% Select elevation of interest
target_elv = 2.0;  % m NAVD88 (upper beach)

% For each survey, find where profile crosses target elevation
for n = 1:size(SM,2)
    [x_intersect, ~] = intersections(...
        [SM(n).X1D(1) SM(n).X1D(end)],  % line extent
        [target_elv target_elv],         % horizontal line at target elv
        SM(n).X1D,                       % profile x
        SM(n).Z1Dmean                    % profile z
    );
    
    % Anomaly = deviation from mean
    x_mean = intersections(...
        [GM.X1D(1) GM.X1D(end)],
        [target_elv target_elv],
        GM.X1D,
        GM.Z1Dmean
    );
    
    anomaly(n) = x_intersect(1) - x_mean(1);
end

% Plot position anomaly over time
plot([SM.Datenum], anomaly)
datetick
ylabel('Contour Position Anomaly (m)')
```

### 4. Multi-Source Comparison

```matlab
% Compare volume changes from different survey sources

sources = {'GPS', 'LiDAR', 'Drone', 'Multibeam'};

for s = 1:length(sources)
    idx = strcmpi({SG.Source}, sources{s});
    if any(idx)
        vol_change(s) = mean_volume_change(SG(idx));
    else
        vol_change(s) = NaN;
    end
end

figure
bar(sources, vol_change)
ylabel('Mean Volume Change (m³)')
title(['Mop ' num2str(MopNumber)])
```

---

## Performance Tips

1. **Large datasets**: Use `CombineSGdata.m` instead of manual loops
2. **Memory**: Process Mops one at a time if analyzing entire coast
3. **Speed**: Pre-compute grid coordinates once, reuse in loops
4. **Visualization**: Use `imagesc` instead of `surf` for large grids (10x faster)
5. **Storage**: Only keep relevant elevation zones (Z between 0.774-4 m typically)

---

## Quick Reference: Key Variables

```matlab
% SG structure (loaded from M#####SG.mat)
SG(n).X          % UTM Easting (meters)
SG(n).Y          % UTM Northing (meters)
SG(n).Z          % Elevation NAVD88 (meters)
SG(n).Datenum    % Survey date (Matlab datenum)
SG(n).Source     % Survey source ('GPS', 'LiDAR', etc.)
SG(n).File       % Original file path

% After SG2grid conversion
[X, Y, Z] = SG2grid(SG, survey_index)
% X, Y are 2D arrays (UTM grid coordinates)
% Z is 2D elevation array with NaNs for no-data
% Each grid cell is 1m x 1m

% Volume calculations
vol = sum(Z(:), 'omitnan')           % Total volume (m³)
vol_per_area = vol / (size(Z,1)*size(Z,2))  % Avg depth (m)
vol_change = Z2 - Z1                 % Elevation difference map
net_erosion = sum(vol_change(vol_change<0))  % Total erosion volume
```

---

## Example Output: Cardiff Mop 668-682

From running `ExamplePlotReachJetskiVolumeEvolution.m` on a Cardiff date range:

```
The SG struct array has 5 Jumbo-Jetski Surveys.
3 Jumbo-Jetski Surveys found in the date range.

Volume change summary:
  Date 1 → Date 2: +45,230 m³ (net deposition)
  Date 2 → Date 3: -12,450 m³ (net erosion)
  Total change: +32,780 m³

Cross-shore redistribution:
  Erosion zone (x < 50m): -23,500 m³
  Deposition zone (50m < x < 150m): +56,280 m³
  Export (x > 150m): +0 m³
```

---

## References & Related Documentation

- **CODEMAP.md** - Overall toolbox structure and entry points
- **GetShoreface.m** - Beach morphology metric definitions
- **SG2grid.m** - Grid conversion documentation
- **CombineSGdata.m** - Multi-Mop data fusion

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Data loading fails** | Check `CpgDefineMopPath.m` - paths may need updating |
| **Volume is zero/NaN** | Check elevation thresholds - Z values may be outside expected range |
| **Grids don't align** | Use same `[X,Y]` extent for both surveys in difference calculation |
| **Large memory use** | Process fewer Mops at once; use `imagesc` instead of `surf` |
| **Time series gaps** | Some dates may have no surveys - check `[SG.Datenum]` |

---

**Created**: December 2025  
**Based on**: Analysis of 83 volume-related files in CPG toolbox
