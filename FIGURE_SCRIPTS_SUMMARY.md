# MATLAB Figure Generation Scripts - Summary

## Quick Links

All scripts are located in: `/Users/holden/Documents/Scripps/Research/toolbox/`

---

## MAIN FIGURE SCRIPTS (8 Total)

### **Figure 1: Study Site & Instrumentation Map** (`Figure1_SiteMap.m`)
- **Output**: `Figure_1_SiteMap.png`
- **Purpose**: Establishes spatial context with MOP transects, PUV sensors, bathymetric contours
- **Key Components**:
  - Google Maps satellite background (via `plot_google_map.m`)
  - MOP transect lines from `MopTableUTM.mat`
  - PUV sensor location markers (5m, 7m depths)
  - Scale bar and north arrow
- **Data Requirements**:
  - `MopTableUTM.mat` - loaded automatically
  - PUV coordinates (currently placeholder - **UPDATE NEEDED**)
  - Bathymetry grid (optional - for contours)
- **Customization Points**:
  - Lines 20-22: Update PUV coordinates to actual locations
  - Line 16: Adjust MOP range for your study area
  - Line 38: Modify Google Maps satellite zoom/extent as needed

---

### **Figure 2: Wave Climate Context** (`Figure2_WaveClimate.m`)
- **Output**: `Figure_2_WaveClimate.png`
- **Purpose**: 10-year wave context with focus on 2022-2024 experiment window
- **3 Panels**:
  1. Monthly Hs with ±1σ envelope (10-year context)
  2. Daily Hs & Tp during experiment (7-day smoothed)
  3. Wave energy anomalies (above/below long-term mean)
- **Key Components**:
  - Synthetic wave data (demo) or real CDIP hindcast
  - Monthly statistics with confidence bands
  - Daily time series with dual-axis (Hs & Tp)
  - Color-coded anomaly bars (red=energetic, blue=calm)
- **Data Requirements**:
  - CDIP buoy data (`CDIP[ID]BP.mat` or netcdf access)
  - Wave height and period time series
- **Customization Points**:
  - Line 16: Update BuoyID and MopNumber
  - Lines 18-22: Adjust date ranges to your analysis period
  - Line 100+: Replace synthetic data generation with real data loader

---

### **Figure 3: Cross-Shore Profile Evolution** (`Figure3_ProfileEvolution.m`)
- **Output**: `Figure_3_ProfileEvolution.png`
- **Purpose**: Alongshore-averaged profiles at key survey dates
- **4 Panels**:
  1. Absolute elevations (4 key dates)
  2. Elevation change from baseline (Oct 2022)
  3. Subaerial profile evolution (Z > MSL)
  4. Subaqueous detail (Z < MSL)
- **Key Components**:
  - SM file loading and concatenation across MOPs
  - Cross-shore interpolation to uniform grid
  - Tide datum reference lines (MHHW, MSL, MLLW)
  - 4m pivot depth marked
- **Data Requirements**:
  - `M[MOPNUM]SM.mat` files for each MOP in range
  - Survey dates within ±3 days matching
- **Customization Points**:
  - Lines 15-16: MOP range
  - Lines 20-24: Survey dates (change as needed)
  - Line 26: Cross-shore interpolation distance
  - Line 27: Maximum cross-shore distance to display

---

### **Figure 4: Waves, Volumes & Beach Width** (`Figure4_WavesVolumesWidth.m`)
- **Output**: `Figure_4_WavesVolumesWidth.png`
- **Purpose**: 5-panel stacked time series showing wave forcing and morphological response
- **5 Panels** (top to bottom):
  1. Significant wave height Hs
  2. Total volume change (stacked red/green bars)
  3. Subaerial volume only
  4. Subaqueous volume by depth (shallow vs. deep)
  5. Beach width at fixed elevation (MSL)
- **Key Components**:
  - Synthetic volume data (demo) - replace with real SM/SG loading
  - Color coding: green=accretion, red=erosion
  - Stacked area plots for depth partitioning
  - 30-day smoothing for trends
- **Data Requirements**:
  - SM files for volume calculations (one SM struct per MOP per date)
  - Wave height time series
- **Customization Points**:
  - Lines 15-17: MOP range and date range
  - Line 22: Reaches into synthetic data section (lines 35-55) - **REPLACE WITH REAL DATA LOADING**
  - Line 33: Alongshore reach length calculation

---

### **Figure 5: Depth-Partitioned Volume Change** (`Figure5_DepthPartitioned.m`)
- **Output**: `Figure_5_DepthPartitioned.png`
- **Purpose**: Quantifies depth-dependent recovery with 4m pivot depth
- **2 Panels**:
  1. Stacked area: Time series of volume by depth bin (4 zones)
  2. Hovmöller: Space-time elevation change contours
- **4 Depth Zones** (defined in code):
  - Deep: -10 to -6 m
  - Mid: -6 to -4 m (pivot zone)
  - Shallow: -4 to -2 m
  - Inner: -2 m to MSL
- **Key Components**:
  - Zone-based volume aggregation
  - Stacked area with distinct colors per zone
  - Hovmöller colormap (hot, reversed)
  - Zone boundaries overlaid as white dashed lines
- **Data Requirements**:
  - Synthetic depth-partitioned volumes (demo) - replace with real binning
  - SM files with elevation data for zone assignment
- **Customization Points**:
  - Lines 21-28: Zone elevation boundaries (change if using different zones)
  - Lines 60-80: Synthetic data generation (replace with real SM file loading)

---

### **Figure 6: Bottom Energy Flux & Bed Stress** (`Figure6_EnergyFlux.m`)
- **Output**: `Figure_6_EnergyFlux.png`
- **Purpose**: Shows depth-dependent forcing and mobilization thresholds
- **3 Panels**:
  1. Bottom energy flux F(t) at 5m and 7m
  2. Bed shear stress τ_b with critical threshold τ_c = 0.2 Pa
  3. Orbital velocity amplitude U_b at both depths
- **Key Components**:
  - Wu dispersion relation solver (nested function)
  - Parametric wave spectrum generation
  - Group velocity calculation at each frequency
  - Energy flux integration over frequency bands
  - Shields parameterization for bed stress
- **Data Requirements**:
  - Wave parameters (Hs, Tp) time series
  - PUV water depths (5m, 7m)
  - (Optional) Spectral data from CDIP
- **Customization Points**:
  - Lines 16-18: Depth values and date range
  - Line 25: Critical shear stress threshold (default 0.2 Pa)
  - Line 35: Friction coefficient f_w (default 0.015)
  - Lines 75-105: Synthetic wave generation (replace with real data)

---

### **Figure 7: Flux-Response Relationship & Model** (`Figure7_FluxResponse.m`)
- **Output**: `Figure_7_FluxResponse.png`
- **Purpose**: Demonstrates nonlinear cubic (F³) scaling between energy flux and morphology
- **6 Panels**:
  1. Scatter Δz vs F (shows threshold)
  2. Scatter Δz vs F³ (linear relationship)
  3. 2D histogram of joint distribution
  4-5. Time series observed vs. model (combined panel)
  6. Residuals and error metrics
- **Key Components**:
  - Threshold detection (F > F_c)
  - Cubic scaling model: Δz ∝ (F - F_c)³
  - Linear least-squares fit in F³ space
  - R² goodness-of-fit metric
  - Residual analysis with std bands
- **Data Requirements**:
  - Elevation change observations Δz(t)
  - Energy flux time series F(t)
  - Survey dates aligned with wave data
- **Customization Points**:
  - Line 19: Energy flux activation threshold F_threshold (default 0.3 m³/s)
  - Lines 30-40: Synthetic data generation (replace with real observed data)
  - Line 32: Model scaling coefficient a_model

---

### **Figure 8: Conceptual Schematic** (`Figure8_ConceptualSchematic.m`)
- **Output**: `Figure_8_ConceptualSchematic.png`
- **Purpose**: Visual summary of depth-partitioned recovery mechanism
- **Features**:
  - Cross-shore profile sketch
  - 3 colored zones (shallow/mid/deep)
  - Sediment transport arrows (magnitude & direction)
  - 5-step process chain (shoaling → skewness → stress → transport → morphology)
  - 4m pivot depth highlighted in red
  - Numbered process boxes with connecting arrows
  - Governing equation: dη/dt = α F³
- **No Data Requirements** - Pure schematic
- **Customization Points**:
  - Lines 50-60: Zone background colors and transparency
  - Lines 100-170: Arrow positions and process box locations
  - Line 210: Equation text (edit for different notation/parameters)

---

## REFERENCE GUIDE

### Master Data Structures Used
| Structure | Purpose | Loading |
|-----------|---------|---------|
| **SM** | Survey Means (profiles averaged) | `load(['M' sprintf('%5.5d', MopNum) 'SM.mat'], 'SM')` |
| **SA** | Survey Array (point cloud data) | `load(['M' sprintf('%5.5d', MopNum) 'SA.mat'], 'SA')` |
| **SG** | Survey Grid (gridded data) | `load(['M' sprintf('%5.5d', MopNum) 'SG.mat'], 'SG')` |
| **Mop** | MOP transect table | `load('MopTableUTM.mat', 'Mop')` |

### Key Conversion Factors
- **NAVD88 to MSL**: Subtract 0.774 m
- **MSL to MHHW**: Add 0.792 m (to 1.566 m NAVD88)
- **1 MOP alongshore**: ~100 m

### Useful Functions in Your Toolbox
- `plot_google_map.m` - Satellite map background
- `polarmap.m` - Red-Blue colormap (erosion-accretion)
- `GetAllNearestPointsProfile.m` - Extract profiles
- `LinearDispersion.m` - Wave dispersion solver
- `movmean()` - MATLAB moving average

---

## WORKFLOW: From Data to Figures

### Step 1: Update Data Paths & Locations
- Edit `OutputDir` in each script (currently `./Figures/`)
- Update MOP ranges to match your study area (e.g., 576-590 for Torrey Pines)
- Update BuoyID and survey date ranges

### Step 2: Load Real Data
Most scripts start with synthetic/demo data for testing. Replace:
- **Wave data**: Lines with synthetic `Hs_series = ...` → Load from CDIP netcdf
- **SM/SA files**: Synthetic volume generation → Real SM file loading
- **Elevation data**: Synthetic profiles → Real SM/SG extraction

### Step 3: Run Individual Figures
```matlab
% Option A: Run one at a time
Figure1_SiteMap       % Opens map with instrumentation
Figure2_WaveClimate   % 3-panel wave context
Figure3_ProfileEvolution  % 4 survey date comparison
% etc.

% Option B: Run all in batch
for f = 1:8
    eval(['Figure' num2str(f) '_(scriptname)'])
end
```

### Step 4: Customize & Iterate
- Adjust color schemes (lines with `color` properties)
- Change font sizes / label positions
- Modify panel sizes / aspect ratios (lines with `'position'`)
- Add statistical overlays or annotations

### Step 5: Export for Publication
All scripts save as PNG at 300 DPI (publication quality). For PowerPoint:
- Recommended size: 7×5 inches (single) or 14×8 inches (multi-panel)
- Check figure aspect ratio matches your slide template

---

## COMMON EDITS & TROUBLESHOOTING

### Problem: "File not found" (SM.mat, SG.mat, etc.)
**Solution**: 
1. Check `addpath` statements at script top
2. Verify MOP numbers exist in your data
3. Use `dir(['M0058*'])` to see available files

### Problem: "Google Maps fails to load"
**Solution**: 
1. Check internet connection
2. Try comment out `plot_google_map()` line
3. Use `[1 1 1] * 0.95` for gray background instead

### Problem: "Synthetic data instead of real data" (Figures 2, 4, 5, 6, 7)
**Solution**: 
1. Replace synthetic data generation section with real data loading
2. Example template (use this pattern):
```matlab
% OLD (synthetic):
Hs_series = 2 + 1.5*sin(...) + 0.4*randn(...);

% NEW (real data from CDIP):
ncread(dsurl, 'waveHs');  % Load from netcdf
```

### Problem: "Arrays size mismatch" when concatenating profiles
**Solution**: 
1. Use `isnan()` to filter bad data
2. Use `interp1()` to put profiles on common grid
3. Check SM struct fields exist before accessing

---

## SUPPLEMENTAL FIGURES (Outlined)

Scripts for supplemental figures are not yet written but can follow same template:

### SI Figure S1: Grain Size Distributions
```matlab
% Plot cumulative PSD curves from sediment samples
load SedimentSamples.mat
semilogx(phi, cumulative_psd)
```

### SI Figure S2: Instrument Photos
```matlab
% 4-panel montage of equipment
im1 = imread('PUV_photo.jpg');
im2 = imread('LiDAR_photo.jpg');
% ... arrange in subplot grid
```

### SI Figure S3-S10: Similar pattern...

---

## NEXT STEPS

1. **Update data paths**: Edit paths in lines 10-15 of each script
2. **Load real survey data**: Replace synthetic generation blocks with SM/SA loading
3. **Run scripts individually**: Test each figure before running batch
4. **Customize colors/fonts**: Match your publication style guide
5. **Generate final figures**: Run complete batch and export to PowerPoint

---

## Support Files in Toolbox

- `FIGURE_GENERATION_GUIDE.md` - Detailed specification for each figure
- `MopRangeElevationChangeMap.m` - Reference for multi-panel elevation maps
- `TBR23/TorreyRecoveryEvolutionMeanProfiles.m` - Reference for profile evolution
- `ExamplePlotReachJetskiVolumeEvolution.m` - Reference for volume analysis

---

**Last Updated**: January 2026
**Author**: GitHub Copilot (with technical guidance from research toolbox)
