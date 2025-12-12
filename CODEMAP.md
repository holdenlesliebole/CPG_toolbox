# CPG Toolbox Code Map

## Overview

The **Coastal Processes Group (CPG) Toolbox** is a comprehensive MATLAB-based system for managing, processing, and analyzing beach morphology survey data collected along the California coast. The codebase contains 500+ files organized around a sophisticated data management pipeline that ingests multi-source survey data, aggregates it spatially and temporally, and provides tools for morphological analysis.

**Core Philosophy**: Data flows through a hierarchical aggregation pipeline:
- **SA** (Survey Averaged) → **SG** (Spatial Grid) → **SM** (Survey Morphology) → **GM** (Global Mean)
- Each level represents increasing spatial/temporal integration
- Supports ~11,594 coastal transects (MOPs) along California from MX to OR borders

---

## Data Structures (Core Data Types)

### SA - Survey Averaged Data
- **Purpose**: 1-meter spatial averages of raw survey points
- **Storage**: Individual Mop files `M#####SA.mat`
- **Content**: Structure array with fields:
  - `X, Y, Z` - UTM coordinates and elevation
  - `Datenum` - Survey date
  - `Source` - GPS, LiDAR, etc.
  - `File` - Original survey file path
  - `Class` - Point classification (land/water/error)

### SG - Spatial Grid Data
- **Purpose**: Interpolated elevation grids for each survey
- **Storage**: Individual Mop files `M#####SG.mat`
- **Content**: Regular UTM grids at 1m cross-shore and alongshore resolution
- **Use**: Volume calculations, elevation change maps, visualization

### SM - Survey Morphology
- **Purpose**: Cross-shore profile metrics extracted from surveys
- **Storage**: Individual Mop files `M#####SM.mat`
- **Content**: 
  - Profile elevation data at transect (alongshore) locations
  - Beach slope, beach width, dune elevation, etc.
  - Roughness metrics, sandbar position
- **Use**: Time-series analysis of profile evolution

### Survey (Master Inventory)
- **Purpose**: Metadata catalog of all processed survey files
- **Storage**: `SurveyMasterListWithMops.mat`
- **Content**: Struct array with:
  - File path, date, source
  - Mop range covered
  - File creation date
- **Use**: Tracking which surveys have been processed, finding new data to ingest

### GM - Global Mean
- **Purpose**: Monthly/periodic statistics aggregated from all surveys
- **Storage**: Individual Mop files `M#####GM.mat`
- **Use**: Identifying long-term trends and seasonal patterns

### Mop Table
- **Purpose**: Definition of transect locations and metadata
- **Storage**: `MopTableUTM.mat`
- **Content**: 
  - UTM coordinates for each Mop cross-shore transect
  - Mop numbers (1-11594)
  - Geographic regions, county boundaries
- **Use**: Coordinate transformations, defining analysis regions

---

## Main Entry Point Scripts

### Core Data Management Workflow

#### **CpgMopUpdateAll.m** ⭐ PRIMARY ENTRY POINT
- **Purpose**: Master orchestration script for complete data update
- **Workflow**:
  1. Updates SA files from survey inventory
  2. Updates SG files from SA
  3. Updates SM files from SG  
  4. Updates GM files from SM
  5. Updates all QC flags
- **Key Calls**: `CpgUpdateSAmatfiles`, `CpgUpdateSGmatfiles`, `CpgUpdateSMmatfiles`, `Cpg5UpdateGMmatfiles`

#### **MakeSurveyMasterListwithMops.m** ⭐ INITIALIZATION
- **Purpose**: Build/rebuild the survey inventory from raw data directories
- **Workflow**:
  1. Scans topobathy data directories for new surveys
  2. Reads survey file headers to extract metadata
  3. Assigns nearest Mop numbers to each survey
  4. Creates `SurveyMasterListWithMops.mat`
- **Frequency**: Run once during setup or when new surveys added to system
- **Key Calls**: `FindTopoBathySurveys`, `GetTransectLines`, `LatLon2MopxshoreX`

#### **CpgUpdateSAmatfiles.m**
- **Purpose**: Update individual Mop SA files with new survey data
- **Workflow**:
  1. Loads Survey inventory
  2. For each Mop: reads SA file (or creates new)
  3. Scans Survey list for new files affecting this Mop
  4. Reads survey data from disk, extracts points for this Mop
  5. Aggregates to 1m spatial grid averages
  6. Combines with existing data, removes duplicates
  7. Saves updated `M#####SA.mat`
- **Duration**: ~5-10 minutes for full state (depending on disk speed)
- **Key Calls**: `readSurveyFileUTM`, `CombineSurveyDateSourceData`, `AddFilesStructArrayToSAfiles`

#### **CpgUpdateSGmatfiles.m**
- **Purpose**: Generate interpolated elevation grids (SG) from SA points
- **Workflow**:
  1. For each Mop: loads SA data
  2. Creates UTM grid at 1m resolution (cross-shore × alongshore)
  3. Interpolates elevation onto grid using inverse distance weighting or kriging
  4. Saves `M#####SG.mat` with grid data
  5. Tracks which surveys contributed to each grid cell
- **Duration**: ~10-20 minutes for full state
- **Key Calls**: `SG2grid`, `BuildSG`

#### **CpgUpdateSMmatfiles.m**
- **Purpose**: Extract profile metrics from interpolated grids
- **Workflow**:
  1. For each Mop: loads SG grids
  2. Extracts cross-shore profile at each alongshore transect location
  3. Computes morphological metrics:
     - Beach slope, beach width, dune elevation
     - Roughness (high-frequency elevation variability)
     - Sandbar position and depth
  4. Saves `M#####SM.mat` with profile struct array
- **Duration**: ~5-10 minutes for full state
- **Key Calls**: `BuildSM`, `GetShoreface`

#### **Cpg5UpdateGMmatfiles.m** (v2 recommended)
- **Purpose**: Compute global means and statistics
- **Workflow**:
  1. For each Mop: loads SM data
  2. Computes monthly/seasonal averages across all surveys
  3. Computes trend lines, anomalies
  4. Saves `M#####GM.mat`
- **Duration**: ~5-10 minutes for full state
- **Key Calls**: Monthly aggregation functions

### Data Source-Specific Update Scripts

#### **CpgMopsUpdateJetski.m**
- **Purpose**: Process new jetski/GPS ATV survey data
- **Special Processing**:
  - Handles kinematic GPS data format
  - Applies tide corrections
  - Filters for subaerial data only (Z > some threshold)
  - Velocity-based outlier removal
- **Called By**: `CpgMopUpdateAll` (as option)

#### **CpgMopsUpdateIg8wheel.m**
- **Purpose**: Process iG8 wheeled ATV survey data
- **File Format**: DAT format with GNSS + RTK corrections
- **Processing**: Similar to jetski but with different kinematic model

#### **UpdateiG8wheelSAmatfiles.m**
- **Purpose**: Manual workflow for iG8 wheel surveys
- **Use Case**: When you have a single iG8 survey to process

#### **CpgMopsCheck.m**
- **Purpose**: Validation and diagnostic script
- **Checks**:
  - Data gaps in coverage
  - Dubious elevation values
  - Date consistency
  - File integrity
- **Output**: Diagnostic plots and warnings

### Setup/Initialization Scripts

#### **BuildCpgSurveyList.m**
- **Purpose**: Discover all topobathy and survey data files
- **Use Case**: Initial system setup or when new data added to shared drives
- **Output**: `CpgSurveyMasterList.mat`

#### **MakeSurveyMasterList.m**
- **Purpose**: Legacy version - creates basic survey inventory (now superseded by MakeSurveyMasterListwithMops)

#### **DefineMopPath.m** / **CpgDefineMopPath.m**
- **Purpose**: Sets system paths and data directory locations
- **Configuration**: Define mount points for MOPS data, survey directories
- **Called By**: Most update scripts at startup
- **Edit This For**: Changing data directory locations

---

## Functional Categories

### 📥 Data I/O (File Reading/Writing)

#### Survey File Reading
- `readSurveyFileUTM.m` - Read generic topobathy survey format (UTM coords)
- `readSurveyFileUTM2.m` - Variant with additional error handling
- `readSurveyFile.m` - Legacy version

#### LAS/LiDAR Data
- `lasdata.m` - LAS file class for reading/writing point clouds
- `testlas.m` - Test script for LAS reading

#### Multibeam/SHOALS
- `NoaaLas2mopLlzFiles.m` - Convert NOAA multibeam LAS to Mop LLZ format
- `readSurveyFileUTMold.m` - Legacy SHOALS format

#### Data Assembly
- `AddFilesStructArrayToSAfiles.m` - Append new survey files to SA struct
- `AddFilesStructArrayToSGfiles.m` - Append to SG files
- `AddFilesStructArrayToSMfiles.m` - Append to SM files

#### Special Format Readers
- `ViewDroneXYZ.m` - Read/visualize drone XYZ point cloud files
- `getztide.m` - Extract tide values from tide prediction files

### 🔀 Data Aggregation & Combination

#### Survey Combination
- `CombineSurveyDateSourceData.m` - Merge surveys with same date/source, remove duplicates
- `CombineSGdata.m` - Combine multiple SG grids
- `SAcombineMops.m` - Combine SA data across multiple Mops
- `SGcombineMops.m` - Combine SG grids across Mops

#### Grid Building
- `SG2grid.m` - Convert SG struct to regular UTM grid arrays
- `BuildSG.m` - Main routine for creating spatial grids from SA data
- `BuildSM.m` - Extract profiles and metrics from SG
- `BuildRC.m` - Build roughness/classification grids

#### Profile Extraction
- `GetNearestPointsProfile.m` - Extract profile at specific location
- `GetSAprofile.m` - Get raw SA profile data
- `GetShoreface.m` - Extract intertidal zone elevation profile
- `GetTransectLines.m` - Get MOPs transect line definitions

#### Spatial Operations
- `UTM2MopCoords.m` / `LatLon2MopxshoreX.m` - Convert coordinates to Mop-relative (x_shore, x_alongshore)
- `UTMalongshoreGrid.m` / `AlongshoreGrid.m` - Create alongshore interpolation grids
- `EqualSpacedPoints.m` - Generate regular point grids

### 📊 Plotting & Visualization

#### Time Series & Profile Plots
- `PlotLatestSurveyProfiles.m` - Plot most recent profiles for a region
- `PlotLast5QuarterlyProfiles.m` - Seasonal comparison plots
- `PlotLast4TruckProfiles.m` - Recent truck survey profiles
- `PlotMopShoreline.m` - Shoreline maps with Mop transects
- `PlotSGgridSAdata.m` - Overlay SA points on SG grid

#### Specialized Visualization
- `PlotBNevolution.m` / `PlotBNevolution582.m` - Sandbar evolution (creates GIFs)
- `SandbarTracker.m` - Interactive sandbar tracking visualization
- `SandbarTrackerBNanomaly.m` - Anomaly visualization
- `ContourTracker.m` - Contour evolution over time
- `ColorScatter.m` - Elevation data with color coding
- `ColorScatterProfile.m` - Profile with colored elevation zones
- `RoughnessColorScatter.m` - Roughness/classification scatter

#### Multi-Location Comparison
- `PlotShoals.m` - SHOALS survey footprints
- `PlotShoalsDataOnMap*.m` - Overlay SHOALS data on maps (Cardiff, Solana, Torrey variants)
- `CompareTest.m` - Compare survey datasets
- `CompareMasterLists.m` - Compare inventory lists

#### Example/Demo Scripts (27+ files)
- `ExampleDataSources.m` - Show available data sources for a Mop
- `ExamplePlot*.m` - Specific analysis workflows (CombinedJumboSGelevationChange, MopSlopeSineFits, etc.)
- `ExampleGetCpgMopsBeachWidths.m` - Extract beach width metrics
- `ExampleMopXmhwVsBeachSlope.m` - Correlation analysis examples
- Most start with "Example" and demonstrate complete workflows from data load to visualization

### ✓ Quality Control & Validation

#### Data Validation
- `ElevGoodnessQCv1.m` - Elevation error/uncertainty checking
- `CheckSGjumbos.m` - Verify jumbo survey data integrity
- `CheckForGpsSurveyFiles.m` - Validate GPS file presence
- `CheckForTrkSurveyFiles.m` - Validate truck survey files
- `CheckSurvey.m` - General survey validation routine

#### Anomaly Detection
- `SurveySpecialQC.m` - Detect unusual data patterns
- `CompareTest.m` - Compare datasets for consistency
- `ExampleQC.m` - Demo QC workflow

#### Visualization QC
- `TruckTifQC*.m` - Validate truck/TIF survey data
- `FindJumbos.m` - Identify jumbo survey records
- `ExampleTruckTifQC.m` - Example QC workflow

### 🌊 Core Physics & Analysis

#### Beach/Shoreface Metrics
- `GetShoreface.m` - Extract low-tide terrace and shoreface zone
- `GetMSLshoreline.m` - Shoreline position at mean sea level
- `GetReachAnnualMeanBeachWidths.m` - Beach width statistics

#### Roughness Analysis
- `GetProfileMedianRoughness.m` - Compute high-frequency roughness
- `GetMopShoalsRoughness.m` - Roughness from SHOALS data
- `FindMopShoalsRoughness.m` - Roughness grid creation
- `RoughnessShoalsComparison.m` - Compare roughness metrics across sources

#### Sandbar Tracking
- `SandbarTracker.m` - Track sandbar position through time
- `SandbarTrackerBN.m` - Sandbar anomaly tracking
- `SandbarBermTracker.m` - Terrace/berm position tracking
- `MatchMyBeachFace.m` - Profile matching for tracking

#### Volume & Change Analysis
- `DuneVolume.m` / `DuneVolume2024.m` - Dune volume calculations
- `GetAllMopsContourHistoryV2.m` - Elevation contour evolution
- `EulerianAnomaly.m` - Eulerian view of elevation anomalies
- `EulerianAnomalyMovie.m` - Time-lapse visualization

#### Tide & Wave Data
- `GetDailyMaxTide.m` - Extract tide predictions
- `MakeTideMatFiles.m` - Precompute tide tables
- `getwaves.m` - Get wave hindcast data
- `gettide.m` - Tide lookup functions

#### Specialized Physics
- `GetRmsdGMP.m` - RMSD metrics (Geometric Mean Profile?)
- Files in `Runup/` subdirectory - Wave runup calculations
- Files in `LongshoreTransport/` - Sediment transport analysis

### 🛠️ Utility & Helper Functions

#### Coordinate Transformations
- `UTM2MopCoords.m` - UTM to Mop-relative coordinates (x_shore, x_alongshore)
- `LatLon2MopxshoreX.m` - Lat/Lon to Mop coordinates
- `LatLon2MopFractionXshoreX.m` - Fractional Mop position
- `deg2utm.m`, `utm2deg.m` - Geographic coordinate conversions
- `ShoreBox2utm.m`, `utm2ShoreBox.m`, `deg2ShoreBox.m` - ShoreBox coordinate system

#### Mop Utilities
- `DefineMopCounties.m` - Associate Mops with counties
- `XY2MopNums.m` / `XY2MopNumsV2.m` - Find nearest Mop from coordinates
- `MopxshoreX2LatLonUTM.m` - Reverse Mop coordinate transformation

#### File System
- `CpgDefineMopPath.m` - Set data paths (called by most scripts)
- `MovedSurveyFiles.m` - Track relocated survey files

#### Data Structure Utilities
- `viewStruct.m` - Display structure contents
- `AddBytesToSAfiles.m` - Add metadata to structures
- `AddLatestSGmatfiles.m` - Append new grid data
- `AddLatestSMmatfiles.m` - Append new profile data
- `AddLatestSMmatfilesCart.m` - Cartesian coordinate version

#### Math/Analysis Utilities
- `linfit.m` - Linear regression with uncertainty
- `gapsize.m` - Analyze data gaps
- `point_to_line.m` - Distance to line calculations
- `runfilt2d.m` - 2D filtering
- `MonthColormap.m` - Create seasonal color maps
- `BeachColorbar.m` - Visualization colormaps

#### Grid Utilities
- `UTMalongshoreGrid.m` - Create alongshore interpolation grids
- `AlongshoreGrid.m` - Alongshore coordinate system
- `EqualSpacedPoints.m` - Regular point grid generation
- `SpatialAverageUTM.m` - Spatial averaging on UTM grid

#### Format Conversion
- `SM2CP.m` - Convert SM to CoastalProfiler format
- `SMtoShoreline.m` / `SMtoShorelineMHHW.m` - Extract shorelines
- `SM2sandbar.m` - Extract sandbar elevations
- `SMtoGrunionShoreline.m` - Special Grunion beach shoreline

### 📈 Data Analysis & Modeling

#### Profile Analysis
- `ExampleProfileAnalysis.m` - Complete workflow
- `ExampleProfileMetrics.m` - Calculate morphometrics
- `ProfileResponse*.png` - Example outputs

#### Forecasting
- `Mop582ShorelineForecast*.m` (Yates variants) - Wave-driven shoreline prediction
- `YatesConnorMop582ShorelineForecastLong.m` - Long-term forecasts
- `WaterLineForecast.m` - Water line evolution

#### Comparisons & Validation
- `CompareTest.m` - Compare datasets
- `CardiffplotLatestSurveyProfiles.m` - Regional analysis
- `ExampleSurveyVsVosPlots.m` - Compare with historical Vos data

### 📁 Project-Specific Workflows

#### Geographic Sub-Projects
- **Solana/** - Solana Beach nourishment analysis
  - `SolanaVolumeChange*.m` - Volume tracking
  - `PlotSolanaShoreboxChange*.m` - Shoreline evolution
- **ImperialBeach/** - Imperial Beach nourishment
  - `PlotIB*.m` - Analysis workflows
- **LongshoreTransport/** - Transport modeling
  - `GetMopDm.m` - Mean grain size
  - `GetMopSxx.m` - Radiation stress
- **Runup/** - Wave runup/swash
  - `GetMOPfreqSpectra.m` - Spectral analysis
  - `MopTWLNowcastForecast*.m` - Total water level prediction

#### Legacy/Old Code
- **old/** - Archive of superseded functions
  - `GetUTAirFileList.m` (Utah-specific, probably not relevant)

#### Interactive Tools
- **MopSAeditor/** - GUI tool for SA data editing
- **MopOverview/** - Regional overview tools
  - `PlotAllVolumes.m` - Multi-Mop volume comparison

---

## Typical Workflows

### Workflow 1: Update System with New Survey Data
```matlab
% 1. (Once at startup) Define data paths
CpgDefineMopPath

% 2. (Periodically) Rebuild survey inventory from raw data
MakeSurveyMasterListwithMops  % Finds all new survey files

% 3. Update all processed files
CpgMopUpdateAll  % Or run individual steps:
CpgUpdateSAmatfiles      % Raw data → 1m averaged points
CpgUpdateSGmatfiles      % Points → interpolated grids
CpgUpdateSMmatfiles      % Grids → profiles & metrics
Cpg5UpdateGMmatfilesV2   % Profiles → statistics
```

### Workflow 2: Analyze Single Mop Area
```matlab
CpgDefineMopPath
MopNumber = 582;

% Load data
load(['M' num2str(MopNumber,'%5.5i') 'SA.mat'], 'SA')    % Raw points
load(['M' num2str(MopNumber,'%5.5i') 'SM.mat'], 'SM')    % Profiles
load(['M' num2str(MopNumber,'%5.5i') 'GM.mat'], 'GM')    % Statistics

% Analyze/visualize
PlotLatestSurveyProfiles        % Recent surveys
PlotBNevolution                 % Sandbar evolution
GetShoreface(MopNumber)         % Beach metrics
```

### Workflow 3: Compare Multiple Data Sources
```matlab
% Load survey inventory
load SurveyMasterListWithMops.mat
load(['M' num2str(MopNumber,'%5.5i') 'SA.mat'], 'SA')

% Find surveys by source
gps_idx = strcmpi({SA.Source}, 'gps');
lidar_idx = strcmpi({SA.Source}, 'lidar');

% Compare
figure; scatter(SA(gps_idx).Datenum, SA(gps_idx).Z)
hold on; scatter(SA(lidar_idx).Datenum, SA(lidar_idx).Z)
```

### Workflow 4: Extract Beach Morphometrics
```matlab
% See ExampleMopBeachSlopeTimeSeries.m for full workflow
load(['M' num2str(MopNumber,'%5.5i') 'SM.mat'], 'SM')
slopes = [SM.BeachSlope];           % Beach slope time series
widths = [SM.BeachWidthMHW];        % Beach width time series
dates = [SM.Datenum];

figure
subplot(2,1,1); plot(dates, slopes); ylabel('Beach Slope')
subplot(2,1,2); plot(dates, widths); ylabel('Beach Width (m)')
datetick
```

---

## Data Source Legend

The codebase integrates 15+ survey data sources:

| Source Code | Full Name | Format | Resolution | Typical Coverage |
|---|---|---|---|---|
| **GPS** | GPS ATV/Jetski | Kinematic GPS | Variable | Subaerial, ~0.5-2m alongshore |
| **LiDAR** | Airborne LiDAR | LAZ/LAS point cloud | 1m² | Subaerial, large regions |
| **SHOALS** | NOAA SHOALS system | LAS bathymetry | ~1m | Nearshore, 0-25m depth |
| **CCC** | Coastal Conservancy | Survey data | Variable | Various, statewide |
| **USGS** | USGS topobathy | Multi-platform | Variable | Mixed sources |
| **Drone** | UAS/Drone surveys | XYZ point cloud | 0.05-0.2m | Ad-hoc areas |
| **Multibeam** | Multibeam sonar | MBDS data | 1-2m | Nearshore, high-res |
| **Truck** | Truck-based LiDAR | Mobile LAS | High-res | Local reaches |
| **Jumbo** | Jumbo airborne | High-altitude survey | Variable | Historical |

---

## Performance Notes

- **SA update**: ~5-10 minutes for full state (depends on Survey size)
- **SG update**: ~10-20 minutes (interpolation bottleneck)
- **SM update**: ~5-10 minutes
- **GM update**: ~5-10 minutes
- **Full system update**: ~30-50 minutes
- **Plotting functions**: Usually <1 minute

---

## Key Files to Edit for Configuration

1. **CpgDefineMopPath.m** - Data directory paths, mount points
2. **MakeSurveyMasterListwithMops.m** - Survey search directories, file patterns
3. **MopTableUTM.mat** - Mop coordinates (rare update)
4. **SurveyMasterListWithMops.mat** - Survey inventory (auto-generated)

---

## File Organization Summary

```
/toolbox/
├── Core Update Scripts (Cpg*.m)
│   └── CpgMopUpdateAll.m [PRIMARY ENTRY POINT]
├── Data Processing (Build*.m, Make*.m)
│   ├── BuildSAmatfiles.m
│   ├── BuildSGmatfiles.m  
│   ├── BuildSMmatfiles.m
│   └── MakeSurveyMasterListwithMops.m
├── Plot/Analysis (Plot*.m, Example*.m)
├── Physics Functions (Get*.m, *Tracker.m, *Anomaly.m)
├── Utilities (UTM*.m, *Coords.m, *Transform.m)
├── Specialized Projects
│   ├── Solana/
│   ├── ImperialBeach/
│   ├── Runup/
│   ├── LongshoreTransport/
│   └── MopOverview/
├── Data Files (*.mat)
│   ├── MopTableUTM.mat
│   ├── SurveyMasterListWithMops.mat
│   ├── M#####SA.mat (one per Mop)
│   ├── M#####SG.mat (one per Mop)
│   ├── M#####SM.mat (one per Mop)
│   └── M#####GM.mat (one per Mop)
└── Legacy Code (old/, .asv files)
```

---

## Getting Started

1. **First Run Setup**:
   - Edit `CpgDefineMopPath.m` to match your system's data paths
   - Run `MakeSurveyMasterListwithMops.m` to discover surveys
   
2. **Updating Data**:
   - Run `CpgMopUpdateAll.m` to process all new surveys
   - Or run individual `Cpg*Update*.m` scripts for specific steps
   
3. **Analysis**:
   - Start with `Example*.m` scripts to understand workflows
   - Use `PlotLatestSurveyProfiles.m` for visual inspection
   - Load SA/SG/SM/GM files directly for custom analysis

4. **Troubleshooting**:
   - Run `CpgMopsCheck.m` to validate data integrity
   - Check `SurveyMasterListWithMops.mat` to verify survey metadata
   - Look for `.asv` files (auto-save backups) if scripts crash

---

**Last Updated**: 2025-12-08  
**Documentation Generated**: Automated code analysis of 500+ MATLAB files  
**Data: Coastal Processes Group, Scripps Institution of Oceanography**
