# Paper Figures - Complete Resource Index

## Overview

You now have **8 complete MATLAB scripts** for generating publication-quality figures for your depth-partitioned beach recovery paper, plus comprehensive documentation and reference guides.

---

## 📋 What You Have

### **8 Figure Scripts** (ready to run)
All located in: `/Users/holden/Documents/Scripps/Research/toolbox/`

```
Figure1_SiteMap.m
Figure2_WaveClimate.m
Figure3_ProfileEvolution.m
Figure4_WavesVolumesWidth.m
Figure5_DepthPartitioned.m
Figure6_EnergyFlux.m
Figure7_FluxResponse.m
Figure8_ConceptualSchematic.m
```

Each script:
- ✓ Fully commented with user settings section
- ✓ Produces publication-quality PNG at 300 DPI
- ✓ Comes with synthetic demo data (easy to test)
- ✓ Clear instructions for replacing with real data
- ✓ Customizable font sizes, colors, labels

---

## 📚 Documentation (3 Guides)

### 1. **FIGURE_GENERATION_GUIDE.md** (Comprehensive)
📖 **What**: Complete technical specification for every figure

**Contains**:
- Part 1: Useful existing codes in your toolbox (with file names!)
- Part 2: Figure-by-figure specifications (purpose, data requirements, code patterns)
- Part 3: Data workflow & loading patterns
- Part 4: Reusable code patterns (profile concatenation, volume binning, etc.)
- Part 5: Visualization best practices (colormaps, fonts, datums)
- Part 6: File output & saving
- Quick reference table matching each figure to reference scripts

**Use this when**: You need deep technical details, want to understand the theory, need exact code patterns

---

### 2. **FIGURE_SCRIPTS_SUMMARY.md** (Workflow Focused)
🔧 **What**: Practical guide to running and customizing your scripts

**Contains**:
- Quick links to all 8 scripts
- Script-by-script breakdown:
  - Output filename
  - What it visualizes
  - Key components
  - Data requirements table
  - Customization points (with line numbers!)
- Master data structures (SM, SA, SG, Mop)
- Useful functions in your toolbox
- Step-by-step workflow
- Common edits & troubleshooting
- Supplemental figures outline

**Use this when**: You want to run a figure, customize it, or debug a problem

---

### 3. **QUICK_START_FIGURES.md** (Minimal/Fast)
⚡ **What**: 30-second setup guide

**Contains**:
- One-line table of all 8 scripts and outputs
- 30-second setup checklist
- Data requirements matrix (which figures need which data)
- Recommended run order (3 phases)
- Template for replacing synthetic data
- Customization checklist
- Common issues table
- Output directory structure

**Use this when**: You just want to run the scripts NOW

---

## 🎯 Getting Started (Pick Your Path)

### Path A: "I just want to see what these look like" (5 minutes)
1. Open MATLAB
2. cd to `/Users/holden/Documents/Scripps/Research/toolbox/`
3. Run: `Figure8_ConceptualSchematic` ← Works with ZERO data
4. Run: `Figure2_WaveClimate` ← Uses synthetic demo data
5. Look at generated PNG files in `Figures/` folder

### Path B: "I want to understand what each figure does" (20 minutes)
1. Read: **QUICK_START_FIGURES.md** (sections on run order & data requirements)
2. Read: **FIGURE_GENERATION_GUIDE.md** Part 2 (figure-by-figure specs)
3. Skim the "Purpose" and "Key Components" for Figures 1-8
4. Decide which figures match your analysis

### Path C: "I need to integrate my real data" (1-2 hours)
1. Read: **QUICK_START_FIGURES.md** (full setup instructions)
2. Read: **FIGURE_SCRIPTS_SUMMARY.md** (workflow & customization)
3. Update MOP range and date ranges in each script
4. Replace synthetic data sections with your SM file loading
5. Run scripts one at a time, test outputs
6. Customize colors/fonts/labels to match your style

### Path D: "I need to deeply customize or troubleshoot" (2+ hours)
1. Read: **FIGURE_GENERATION_GUIDE.md** (complete technical reference)
2. Review reference scripts in toolbox:
   - `TBR23/TorreyRecoveryEvolutionMeanProfiles.m`
   - `ExamplePlotReachJetskiVolumeEvolution.m`
   - `MopRangeElevationChangeMap.m`
3. Study code patterns in Part 4 of FIGURE_GENERATION_GUIDE.md
4. Modify scripts as needed

---

## 🗂 File Organization

```
/Users/holden/Documents/Scripps/Research/toolbox/
│
├── 📄 FIGURE_GENERATION_GUIDE.md        ← Comprehensive specification
├── 📄 FIGURE_SCRIPTS_SUMMARY.md         ← Workflow & reference
├── 📄 QUICK_START_FIGURES.md            ← Quick setup guide
├── 📄 THIS FILE (INDEX.md)              ← You are here
│
├── 🟠 Figure1_SiteMap.m                 ← Study site map
├── 🟠 Figure2_WaveClimate.m             ← Wave context
├── 🟠 Figure3_ProfileEvolution.m        ← Profile evolution
├── 🟠 Figure4_WavesVolumesWidth.m       ← Multi-panel time series
├── 🟠 Figure5_DepthPartitioned.m        ← Depth-binned analysis
├── 🟠 Figure6_EnergyFlux.m              ← Bottom forcing
├── 🟠 Figure7_FluxResponse.m            ← F³ model skill
├── 🟠 Figure8_ConceptualSchematic.m     ← Mechanism diagram
│
└── 📁 Figures/                          ← Output folder (auto-created)
    ├── Figure_1_SiteMap.png             ← (generated)
    ├── Figure_2_WaveClimate.png         ← (generated)
    └── ... 6 more PNG files
```

---

## 🎨 Figure Overview (1-Sentence Summaries)

| # | Title | One-Liner |
|---|-------|-----------|
| **1** | Study Site & Instrumentation | Geographic context with MOP transects and sensor locations |
| **2** | Wave Climate Context | 10-year wave history highlighting experiment period forcing |
| **3** | Cross-Shore Profile Evolution | Alongshore-averaged beach profile changes at 4 key dates |
| **4** | Waves, Volumes & Beach Width | 5-panel time series showing wave-morphology linkage |
| **5** | Depth-Partitioned Recovery | Volume change separated by elevation zone with Hovmöller |
| **6** | Bottom Energy Flux & Bed Stress | Depth-dependent wave forcing at 5m and 7m |
| **7** | Flux-Response Relationship | Nonlinear F³ scaling model demonstrating threshold behavior |
| **8** | Conceptual Schematic | Process chain from wave shoaling through beach accretion |

---

## 💡 Key Features

✓ **All synthetic demo data included** - test scripts without real data first  
✓ **Publication quality** - 300 DPI PNG, ready for journals/conferences  
✓ **Fully commented code** - understand every line with inline explanations  
✓ **Customization points marked** - clear line numbers for common edits  
✓ **Reference functions documented** - know which toolbox functions to use  
✓ **Troubleshooting guides** - solve common problems quickly  
✓ **No dependencies** - only built-in MATLAB functions + your toolbox  

---

## ⚠️ Important Notes

### Data That's Still Needed
- **PUV coordinates** (Figure 1) - currently placeholder at line 20-22
- **Real SM/SA survey files** (Figures 3, 4, 5) - synthetic data included but replace with yours
- **Real wave data** (Figures 2, 6, 7) - synthetic generation shown but should load from CDIP
- **Elevation observations** for F³ model (Figure 7) - synthetic data included

### Next Steps
1. ✅ **Done**: Script structure complete
2. 📌 **TODO**: Load your actual MOP range & survey dates
3. 📌 **TODO**: Replace synthetic data sections with real SM file loading
4. 📌 **TODO**: Replace synthetic wave data with CDIP netcdf loading
5. 📌 **TODO**: Customize colors/fonts to match publication style

### Scripts Requiring Minimal Customization
- **Figure 1** (Site map) - just needs MopTableUTM.mat + MOP range
- **Figure 8** (Schematic) - no data needed, pure illustration
- **Figure 2** (Wave climate) - works with synthetic demo data, easy to upgrade

---

## 📞 Support Resources

### In Your Toolbox (Reference Scripts)
- `TBR23/TorreyRecoveryEvolutionMeanProfiles.m` - Best reference for profile plotting patterns
- `ExamplePlotReachJetskiVolumeEvolution.m` - Template for volume analysis with depth binning
- `MopRangeElevationChangeMap.m` - Reference for multi-panel elevation change maps
- `PlotLast5QuarterlyProfiles.m` - Profile legend/formatting examples

### MATLAB Documentation
- `movmean()` - Smoothing data (used in all scripts)
- `interp1()` - Cross-shore interpolation (Figures 3, 4, 5)
- `datenum()` / `datetick()` - Time series formatting (Figures 2, 4, 6, 7)
- `pcolor()` / `contourf()` - 2D gridded data plotting (Figures 5, heat maps)

---

## 🚀 Quick Command Reference

```matlab
% Test one figure (no data needed)
Figure8_ConceptualSchematic

% Test wave climate (synthetic data)
Figure2_WaveClimate

% Run your full analysis
Figure1_SiteMap
Figure3_ProfileEvolution
Figure4_WavesVolumesWidth
Figure5_DepthPartitioned
Figure6_EnergyFlux
Figure7_FluxResponse

% Check outputs
ls Figures/*.png   % See all generated PNG files
```

---

## 📊 Figure Dependency Map

```
NO DATA          WAVE DATA ONLY        SURVEY DATA ONLY      BOTH NEEDED
    ↓                  ↓                     ↓                    ↓
    
Figure 8         Figure 2              Figure 1             Figure 4
(Schematic)      (Climate)             (Site Map)           (Vol + Waves)
                 Figure 6              Figure 3             Figure 7
                 (Energy Flux)         (Profiles)           (F³ Model)
                 Figure 7*             Figure 5
                 (F³ Model)*           (Depth Zones)

* Figure 7 marked with * needs BOTH to show R² fit, but survives with synthetic data
```

---

## ✅ Verification Checklist

Before using in paper, verify:

- [ ] All 8 scripts run without errors
- [ ] PNG files generate in expected location
- [ ] Figures display correctly at intended size
- [ ] Data ranges match your study period
- [ ] MOP numbers match your study site
- [ ] Color schemes appropriate for publication (check color-blind mode)
- [ ] Font sizes readable at publication size
- [ ] Legends/labels clear and complete
- [ ] Axis units correct (m, m/s, m³/s, etc.)
- [ ] All figures saved at 300+ DPI

---

## 📈 What's Next?

1. **Run Figure 8** (conceptual schematic) - 0 data needed, immediate success
2. **Run Figure 2** (wave climate) - synthetic data, tests plotting infrastructure
3. **Update MOP/date ranges** in all scripts to match your study
4. **Run Figures 3, 4, 5** - integrate your SM file loading
5. **Run Figures 1, 6, 7** - integrate wave data
6. **Customize visual appearance** - colors, fonts, annotations
7. **Generate final output** - all 8 PNG ready for publication

---

## 📝 Citation & Credits

These scripts are built on patterns from:
- Your existing `MopRangeElevationChangeMap.m` (multi-panel structure)
- `ExamplePlotReachJetskiVolumeEvolution.m` (volume analysis)
- `TorreyRecoveryEvolutionMeanProfiles.m` (profile evolution)

All tailored to your paper's specific scientific goals and figure specifications.

---

## 🎓 Learning Outcomes

After working through these scripts, you'll understand:
- ✓ How to load and manipulate survey data structures (SM, SA, SG)
- ✓ Cross-shore interpolation techniques for profile comparison
- ✓ Depth-binning methods for volume analysis
- ✓ Wave dispersion and energy flux calculations
- ✓ Nonlinear modeling approaches (F³ scaling)
- ✓ Multi-panel figure creation and layout optimization
- ✓ Publication-quality figure generation with MATLAB

---

**Version**: 1.0  
**Date**: January 2026  
**Status**: ✅ Ready to use

Start with **QUICK_START_FIGURES.md** or **Figure8_ConceptualSchematic.m**!
