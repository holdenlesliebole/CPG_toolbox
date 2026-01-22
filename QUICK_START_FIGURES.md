# QUICK START: Run Your Figures

## Files Created (All in `/Users/holden/Documents/Scripps/Research/toolbox/`)

| Script | Output | What It Shows |
|--------|--------|---------------|
| `Figure1_SiteMap.m` | `Figure_1_SiteMap.png` | Study site map with MOPs & PUV sensors |
| `Figure2_WaveClimate.m` | `Figure_2_WaveClimate.png` | 10-year wave context + experiment period |
| `Figure3_ProfileEvolution.m` | `Figure_3_ProfileEvolution.png` | Profile evolution at 4 key dates |
| `Figure4_WavesVolumesWidth.m` | `Figure_4_WavesVolumesWidth.png` | 5-panel: Hs, volumes, beach width |
| `Figure5_DepthPartitioned.m` | `Figure_5_DepthPartitioned.png` | Depth-binned volumes + Hovmöller |
| `Figure6_EnergyFlux.m` | `Figure_6_EnergyFlux.png` | Energy flux & bed stress at 2 depths |
| `Figure7_FluxResponse.m` | `Figure_7_FluxResponse.png` | F³ model fit & time series comparison |
| `Figure8_ConceptualSchematic.m` | `Figure_8_ConceptualSchematic.png` | Mechanism diagram (no data needed) |

---

## 30-Second Setup

1. **Set output directory** (same in all scripts):
   ```matlab
   OutputDir = '/Users/holden/Documents/Scripps/Research/toolbox/Figures/';
   ```

2. **Update your MOP range** (line 15-16 in most scripts):
   ```matlab
   MopStart = 580;  % Your start MOP
   MopEnd = 589;    % Your end MOP
   ```

3. **Update date range** (script-specific, usually lines 18-22):
   ```matlab
   DateStart = datenum(2022, 10, 1);
   DateEnd = datenum(2024, 10, 31);
   ```

4. **Run one figure at a time to test**:
   ```matlab
   Figure1_SiteMap        % Test Figure 1
   Figure2_WaveClimate    % Test Figure 2
   % ... etc
   ```

---

## What Each Figure Needs (Data Requirements)

| Figure | Needs SM? | Needs SA? | Needs SG? | Needs Waves? | Needs Mop.mat? |
|--------|-----------|-----------|-----------|--------------|-----------------|
| **1** | ✓ | ✓ | ✗ | ✗ | **✓✓✓** |
| **2** | ✗ | ✗ | ✗ | **✓✓✓** | ✗ |
| **3** | **✓✓✓** | ✗ | ✗ | ✗ | ✗ |
| **4** | **✓✓✓** | ✗ | ✗ | **✓✓** | ✗ |
| **5** | **✓✓✓** | ✗ | ✗ | ✗ | ✗ |
| **6** | ✗ | ✗ | ✗ | **✓✓✓** | ✗ |
| **7** | ✗ | ✗ | ✗ | **✓✓✓** | ✗ |
| **8** | ✗ | ✗ | ✗ | ✗ | ✗ |

**Key**: ✓ = helpful, ✓✓ = important, ✓✓✓ = critical

---

## Recommended Run Order

### **Phase 1: Context Figures** (no real data needed yet)
1. Run `Figure8_ConceptualSchematic.m` first ← **ALWAYS WORKS** (pure illustration)
2. Run `Figure2_WaveClimate.m` ← uses synthetic demo data, shows wave forcing
3. Run `Figure1_SiteMap.m` ← requires MopTableUTM.mat only

### **Phase 2: Survey Data Figures** (needs SM files)
4. Run `Figure3_ProfileEvolution.m` ← Load your M**SG**SM.mat files, check date matching
5. Run `Figure4_WavesVolumesWidth.m` ← Integrate volume calculations
6. Run `Figure5_DepthPartitioned.m` ← Add depth binning

### **Phase 3: Wave-Interaction Figures** (needs wave data + morphology)
7. Run `Figure6_EnergyFlux.m` ← Pure wave forcing (CDIP data)
8. Run `Figure7_FluxResponse.m` ← Needs both Hs(t) and Δz(t) observations

### **Phase 4: Publication Assembly**
- All 8 PNG files ready for PowerPoint/manuscript
- Resize/crop as needed in figure editor
- All at 300 DPI (publication ready)

---

## Replacing Synthetic Data with Real Data (Template)

Each figure that shows synthetic data has this pattern:

```matlab
%% CREATE SYNTHETIC DATA (Replace with real data loading)
Hs_series = 2 + 1.5*sin(...);  % ← DELETE THIS LINE
Hs_series(Hs_series < 0) = 0.1;
```

**Replace with your data loading**:

```matlab
%% LOAD REAL DATA
ncfile = 'CDIP100_hindcast.nc';  % Your wave data file
wavehs = ncread(ncfile, 'waveHs');
wavetime = ncread(ncfile, 'waveTime');
wavetime = datetime(wavetime, 'ConvertFrom', 'posixTime');

% Convert to datenum for compatibility
t_series = datenum(wavetime);
Hs_series = wavehs;
```

---

## Customization Checklist

### ☐ Study Site & Coordinates
- [ ] Update MopStart/MopEnd in all 8 scripts
- [ ] Update PUV coordinates in Figure 1 (lines 20-22)
- [ ] Verify BuoyID matches your wave station (Figure 2, line 17)

### ☐ Date Ranges
- [ ] Set DateStart/DateEnd for your study period (script-specific)
- [ ] Verify SM/SA files exist for target survey dates
- [ ] Check date formats (should be datenum, not datetime)

### ☐ Data Loading
- [ ] Replace synthetic data sections with real data loading
- [ ] Test one script at a time to debug path/format issues
- [ ] Verify output PNG files are being created

### ☐ Visual Customization
- [ ] Adjust figure sizes if needed (position property)
- [ ] Change colors to match brand guidelines
- [ ] Modify font sizes for readability
- [ ] Add/remove legend items as needed

### ☐ Final Output
- [ ] All 8 PNG files generated at 300 DPI
- [ ] Verified images in Output folder
- [ ] Copied to PowerPoint/manuscript directory
- [ ] Checked for quality/clarity at final size

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| "File not found" M0058*.mat | Data not in path | Check `addpath` statements, verify file exists |
| Blank figure, no data | Synthetic data section | Replace synthetic lines with real data loading |
| Google Map not showing | Network issue | Comment out `plot_google_map()` line, use gray background |
| Arrays size mismatch | Profiles different lengths | Use `interp1()` to common grid size |
| Dates don't align | Date format mismatch | Ensure all dates are `datenum` not `datetime` |

---

## Documentation Files

📄 **Full Details**: `/Users/holden/Documents/Scripps/Research/toolbox/FIGURE_GENERATION_GUIDE.md`
- Complete specification for each figure
- Data structure explanations
- Code patterns and best practices

📄 **This Summary**: `/Users/holden/Documents/Scripps/Research/toolbox/FIGURE_SCRIPTS_SUMMARY.md`
- Workflow instructions
- Data requirements per figure
- Troubleshooting guide

📄 **Code Guide**: Look at reference scripts:
- `TBR23/TorreyRecoveryEvolutionMeanProfiles.m` ← Profile plotting reference
- `ExamplePlotReachJetskiVolumeEvolution.m` ← Volume analysis reference
- `MopRangeElevationChangeMap.m` ← Multi-panel layout reference

---

## Running All Figures at Once

```matlab
% Run all 8 figures in sequence
for fig_num = 1:8
    script_name = ['Figure' num2str(fig_num) '_*'];
    % (Run each manually or modify to auto-find)
end

% Or simply:
Figure1_SiteMap
Figure2_WaveClimate
Figure3_ProfileEvolution
Figure4_WavesVolumesWidth
Figure5_DepthPartitioned
Figure6_EnergyFlux
Figure7_FluxResponse
Figure8_ConceptualSchematic

% All 8 PNG files now in /Figures/
```

---

## Output Files

After running all scripts, you'll have:
```
Figures/
├── Figure_1_SiteMap.png
├── Figure_2_WaveClimate.png
├── Figure_3_ProfileEvolution.png
├── Figure_4_WavesVolumesWidth.png
├── Figure_5_DepthPartitioned.png
├── Figure_6_EnergyFlux.png
├── Figure_7_FluxResponse.png
└── Figure_8_ConceptualSchematic.png
```

All ready for PowerPoint! 🎉

---

**TL;DR**: 
1. Update MOP range & dates in each script
2. Replace synthetic data with real SM/wave loading
3. Run scripts one at a time
4. PNG files auto-save to Figures/ folder
5. Import into PowerPoint

Good luck! 📊
