# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **CPG (Coastal Processes Group) Toolbox** - a MATLAB-based system for managing beach morphology survey data along the California coast (~11,594 Mop transects from Mexico to Oregon). It integrates 15+ survey sources (GPS, LiDAR, Drone, SHOALS multibeam, etc.) into a unified data pipeline.

## Architecture: Hierarchical Data Pipeline

Data flows through four processing stages, each with its own file type:

```
Survey Files (raw)
       ↓
   SA (Survey Averaged)    M#####SA.mat   1m spatial averages
       ↓
   SG (Spatial Grid)       M#####SG.mat   Interpolated elevation grids
       ↓
   SM (Survey Morphology)  M#####SM.mat   Cross-shore profiles & metrics
       ↓
   GM (Global Mean)        M#####GM.mat   Monthly/seasonal statistics
```

**Mop numbering**: Always use 5-digit format with leading zeros (e.g., `M00582SA.mat`)

## Key Entry Points

| Script | Purpose |
|--------|---------|
| `CpgDefineMopPath.m` | **Edit first** - sets data directory paths |
| `MakeSurveyMasterListwithMops.m` | Run once to discover all surveys |
| `CpgMopUpdateAll.m` | Master update script - runs all 4 stages |

**Individual stage updates** (run in order if doing partial updates):
1. `CpgUpdateSAmatfiles.m` - Raw → SA
2. `CpgUpdateSGmatfiles.m` - SA → SG
3. `CpgUpdateSMmatfiles.m` - SG → SM
4. `Cpg5UpdateGMmatfiles.m` - SM → GM

## Data Loading Pattern

```matlab
CpgDefineMopPath
MopNumber = 582;
load(['M' num2str(MopNumber,'%5.5i') 'SA.mat'], 'SA')   % Point cloud data
load(['M' num2str(MopNumber,'%5.5i') 'SM.mat'], 'SM')   % Profile metrics
```

## Coordinate Systems & Datums

- **Primary datum**: NAVD88 (all elevations stored in NAVD88)
- **MSL conversion**: MSL = NAVD88 - 0.774 m
- **MHW level**: 1.344 m NAVD88
- **Subaerial threshold**: Z > 0.774 m NAVD88

Coordinate transformations:
- `UTM2MopCoords.m` - UTM → Mop-relative (x_shore, x_alongshore)
- `LatLon2MopxshoreX.m` - Lat/Lon → Mop coordinates
- `deg2utm.m` / `utm2deg.m` - Geographic conversions

## Important Data Structures

**Survey** (in `SurveyMasterListWithMops.mat`): Master inventory of all survey files with metadata (date, source, Mop range, file path)

**SA struct fields**: X, Y, Z (UTM), Datenum, Source, File, Class

**SM struct fields**: BeachSlope, BeachWidthMHW, DuneElev, Datenum (plus profile elevation data)

**MopTableUTM.mat**: Definition of all 11,594 transect locations

## Core Analysis Functions

- `GetShoreface.m` - Extract beach metrics (slope, width, dune elevation)
- `SG2grid.m` - Convert SG struct to regular grid arrays for volume calculations
- `DuneVolume.m` / `DuneVolume2024.m` - Dune volume calculations
- `SandbarTracker.m` - Track sandbar position through time
- `EulerianAnomaly.m` - Elevation contour anomalies

## Validation & Diagnostics

- `CpgMopsCheck.m` - Diagnostic script with data integrity checks and plots
- `ElevGoodnessQCv1.m` - Elevation error checking
- `CheckSurvey.m` - General survey validation

## Existing Documentation

See these files for detailed workflows:
- `CODEMAP.md` - Complete architectural overview with 500+ file catalog
- `SAND_VOLUME_ANALYSIS.md` - Guide to volume calculations with code examples
- `FIGURE_GENERATION_GUIDE.md` - Publication figure specifications
- `QUICK_START_FIGURES.md` - Rapid setup for figure scripts

## System Requirements

- Requires network access to `/volumes/group` for full survey data (remote mount to reefbreak server)
- Local data path configured in `CpgDefineMopPath.m` (currently set to `/Users/William/Desktop/MOPS/`)
- Full system update takes ~30-50 minutes
