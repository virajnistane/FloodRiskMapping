# Known Limitations and Simplifications

## Overview

This document outlines the known limitations, simplifications, and assumptions in the flood risk mapping pipeline. Understanding these limitations is crucial for proper interpretation of results and identifying areas for future improvement.

## Table of Contents

1. [Model Simplifications](#model-simplifications)
2. [Data Assumptions](#data-assumptions)
3. [Computational Limitations](#computational-limitations)
4. [Visualization Constraints](#visualization-constraints)
5. [Implications for Use](#implications-for-use)
6. [Recommended Improvements](#recommended-improvements)

---

## Model Simplifications

### 1. No Hydrodynamics

**Limitation**: The pipeline uses a simple "bathtub" or "static inundation" model that does not incorporate hydrodynamic processes.

**What is Missing**:
- No water flow simulation
- No momentum equations (Navier-Stokes, shallow water equations)
- No wave dynamics or surge modeling
- No flow velocity calculations
- No temporal evolution of flooding
- No consideration of flow routing through channels

**Impact**:
- Cannot model how water spreads over time
- Cannot identify flow paths or velocities
- Cannot model wave action or storm surge dynamics
- May overestimate flooding in areas protected by topographic barriers
- Cannot model flood duration or recession

**When This Matters**:
- Coastal storm surge modeling
- River flooding with complex flow patterns
- Urban flooding with drainage network effects
- Dam break scenarios
- Situations requiring evacuation time estimates

### 2. Simple Threshold-Based Approach

**Limitation**: Flood identification is based solely on comparing elevation to a static water level threshold.

**Implementation**:
```python
flood_mask = dem < water_level
```

**What is Missing**:
- No connectivity analysis (isolated depressions)
- No consideration of hydraulic connectivity to water sources
- No differentiation between coastal and inland flooding
- No accounting for surface roughness or obstacles

**Impact**:
- May identify low-lying areas as flooded even if not hydraulically connected to flood source
- Cannot distinguish between pluvial (rainfall), fluvial (river), and coastal flooding mechanisms
- Overestimates flooding in landlocked depressions without water sources

**Example Issue**:
A valley below sea level but separated from the ocean by a mountain would incorrectly show as flooded.

### 3. Static Water Level

**Limitation**: Uses a single static water level across the entire domain.

**What is Missing**:
- No temporal variation (tides, storm surge timing)
- No spatial variation in water surface elevation
- No backwater effects
- No consideration of water sources or sinks
- No modeling of sea level rise scenarios over time

**Impact**:
- Cannot model tidal cycles
- Cannot capture storm surge peak vs. baseline conditions
- Cannot model incremental sea level rise impacts
- Assumes instantaneous flooding everywhere simultaneously

### 4. No Drainage or Infiltration

**Limitation**: Does not model water removal processes.

**What is Missing**:
- No infiltration into soil
- No evaporation
- No pumping or drainage systems
- No urban drainage networks (sewers, storm drains)
- No natural drainage channels
- No permeable vs. impermeable surface distinction

**Impact**:
- Cannot estimate flood recession time
- Cannot model effectiveness of drainage infrastructure
- Overestimates flooding in well-drained areas
- Cannot assess pump capacity requirements

### 5. No Subsurface Hydrology

**Limitation**: Ignores groundwater and subsurface water movement.

**What is Missing**:
- No groundwater interaction
- No aquifer effects
- No soil saturation modeling
- No capillary action
- No seepage through levees or dikes

**Impact**:
- Cannot model groundwater flooding
- Cannot assess levee seepage risks
- Cannot model salt water intrusion
- Ignores soil moisture contributions to surface flooding

### 6. Simplified Coastline Buffer

**Limitation**: The coastline buffer is a simple geometric buffer without physical process modeling.

**Implementation**:
```python
buffered_coastline = coastline.buffer(distance_meters)
```

**What is Missing**:
- No wave run-up calculations
- No consideration of beach slope or bathymetry
- No storm surge modeling
- No tide effects
- No wave height or period effects
- No consideration of coastal protection structures

**Impact**:
- Buffer distance is arbitrary without physical basis
- Cannot model different storm intensities accurately
- May under/overestimate actual coastal flood extent
- Cannot assess effectiveness of seawalls or dikes

---

## Data Assumptions

### 1. Perfect DEM Accuracy

**Assumption**: The Digital Elevation Model (DEM) perfectly represents ground surface elevation.

**Reality**:
- DEMs have vertical accuracy errors (typically ±0.5m to ±2m depending on source)
- Vegetation and buildings may not be removed (DTM vs DSM)
- Horizontal resolution limits small feature representation
- Temporal changes (construction, erosion) may not be reflected
- Interpolation artifacts in data-sparse areas

**Impact**:
- Flood extent uncertainty proportional to DEM error
- Small elevation differences near threshold are unreliable
- Buildings may be incorrectly treated as high ground
- Features smaller than DEM resolution are missed

**Mitigation Strategies**:
- Use highest resolution DEM available
- Validate DEM against ground control points
- Account for vertical error in water level thresholds
- Use LiDAR-derived DEMs when possible

### 2. Coastline Accuracy

**Assumption**: The coastline shapefile accurately represents the land-water boundary.

**Reality**:
- Coastlines change over time (erosion, accretion, construction)
- Resolution may miss small inlets or features
- May represent different tidal states
- Human modification (harbors, jetties) may not be current

**Impact**:
- Coastal buffer may not capture actual shoreline complexity
- Flood extent near coast may be inaccurate
- Island and lagoon effects may be misrepresented

### 3. Static Topography

**Assumption**: Topography does not change during the analysis period.

**Reality**:
- Erosion and sedimentation modify elevation
- Construction changes surface elevation
- Subsidence or uplift (especially coastal areas)
- Seasonal vegetation changes

**Impact**:
- Long-term flood risk projections become less reliable
- Scenarios spanning decades may have significant topographic changes
- Sediment deposition during flooding not modeled

### 4. No Land Use Consideration

**Assumption**: Surface properties do not affect flooding.

**What is Ignored**:
- Buildings act as obstacles to flow
- Urban surfaces are impermeable
- Agricultural fields have different infiltration rates
- Forests slow water movement
- Roads and embankments channel water

**Impact**:
- Cannot model urban flooding patterns accurately
- Cannot assess green infrastructure benefits
- Cannot differentiate flood behavior in different land use zones

### 5. No Infrastructure Effects

**Assumption**: No human infrastructure affects flooding.

**What is Ignored**:
- Levees and flood walls
- Dams and reservoirs
- Bridges and culverts (can create backwater)
- Pump stations
- Drainage channels
- Underground utilities (may allow subsurface flow)

**Impact**:
- May predict flooding in protected areas
- Cannot assess infrastructure failure scenarios
- Cannot model infrastructure capacity exceedance

---

## Computational Limitations

### 1. Memory Constraints

**Limitation**: Large DEMs may exceed available memory.

**Current Implementation**: Loads entire DEM into memory at once.

**Impact**:
- Maximum DEM size limited by available RAM
- High-resolution continental-scale analysis not feasible
- May require tiling or downsampling

**Typical Limits** (approximate):
- 16 GB RAM: ~10,000 × 10,000 pixel DEM (float32)
- 32 GB RAM: ~20,000 × 20,000 pixel DEM (float32)
- 64 GB RAM: ~40,000 × 40,000 pixel DEM (float32)

### 2. Single-Threaded Processing

**Limitation**: Most operations are not parallelized.

**Impact**:
- Processing time scales linearly with data size
- Cannot leverage multi-core processors efficiently
- Batch processing of multiple regions is sequential

**Typical Processing Time**:
- Small region (1000×1000 px): seconds
- Medium region (10,000×10,000 px): minutes
- Large region (50,000×50,000 px): tens of minutes

### 3. No Progressive or Streaming Processing

**Limitation**: Cannot process data in chunks or tiles.

**Impact**:
- Must load entire dataset regardless of area of interest
- Cannot process cloud-hosted data efficiently (COGs)
- Memory usage scales with input size

### 4. Limited Error Handling

**Limitation**: May fail ungracefully with malformed inputs.

**Examples**:
- Missing CRS information in DEM
- Mismatched CRS between DEM and coastline
- Corrupted raster files
- Invalid nodata values

**Impact**:
- Requires manual intervention to diagnose issues
- Less robust in automated workflows

---

## Visualization Constraints

### 1. Static 2D Maps Only

**Limitation**: Produces only static 2D map images.

**What is Missing**:
- No interactive maps (zoom, pan, query)
- No 3D visualization of flood depth
- No temporal animations
- No web-based viewers
- No overlay on modern map services (Google Maps, OpenStreetMap)

**Impact**:
- Limited stakeholder engagement
- Difficult to communicate uncertainty
- Cannot explore results interactively

### 2. Fixed Color Schemes

**Limitation**: Colormaps are predefined in configuration.

**Impact**:
- May not be colorblind-accessible
- Cannot adjust dynamically based on data range
- May not meet specific publication requirements

### 3. No Uncertainty Visualization

**Limitation**: Does not visualize DEM uncertainty or model limitations.

**Impact**:
- Users may overinterpret results
- Cannot communicate confidence levels spatially
- Difficult to identify high-confidence vs. low-confidence areas

### 4. Limited Output Formats

**Current Support**: Raster (GeoTIFF), Vector (GeoPackage, Shapefile), Plots (PNG, PDF)

**What is Missing**:
- No KML/KMZ for Google Earth
- No GeoJSON for web applications
- No vector tiles for web mapping
- No cloud-optimized formats for streaming

---

## Implications for Use

### Appropriate Use Cases

This tool is suitable for:

1. **Preliminary screening** of flood-prone areas
2. **Comparative analysis** between scenarios (e.g., 1m vs. 2m sea level rise)
3. **Educational purposes** to understand topographic flood susceptibility
4. **Data exploration** before detailed modeling
5. **Rapid assessment** in data-poor environments
6. **Communication** of general flood risk concepts

### Inappropriate Use Cases

This tool should **NOT** be used for:

1. **Regulatory flood mapping** (use FEMA/official models instead)
2. **Insurance risk assessment** (requires detailed hydrodynamic models)
3. **Engineering design** of flood protection structures
4. **Emergency response planning** requiring accurate inundation timing
5. **Legal or liability decisions** based on flood extent
6. **Fine-scale property-level assessments** (DEM resolution matters)
7. **Real-time flood forecasting** (requires meteorological input and hydrodynamics)

### Recommended Decision Framework

| Decision Type | Suitable? | Recommendation |
|---------------|-----------|----------------|
| Policy discussions | ✅ Yes | Good for illustrating concepts |
| Infrastructure siting | ⚠️ Caution | Use with detailed follow-up |
| Public communication | ✅ Yes | Clear about limitations |
| Detailed design | ❌ No | Use advanced hydrodynamic models |
| Emergency evacuation | ❌ No | Use real-time forecast models |
| Academic research | ✅ Yes | Acknowledge limitations in papers |
| Stakeholder engagement | ✅ Yes | Effective visualization tool |

---

## Recommended Improvements

### Short-Term (Minimal Code Changes)

1. **Connectivity Analysis**: Add option to only include flood areas connected to coastline/rivers
2. **Uncertainty Bands**: Add ±error bands around water level threshold based on DEM accuracy
3. **Multiple Scenarios**: Enable batch processing of multiple water levels
4. **Better Documentation**: Add warning messages about limitations in outputs
5. **Quality Checks**: Validate DEM properties (CRS, resolution) before processing

### Medium-Term (Moderate Development)

1. **Basic Flow Routing**: Implement D8 or similar algorithm to identify flow paths
2. **Tiled Processing**: Support chunked processing for large DEMs
3. **Interactive Visualization**: Generate Leaflet/Folium interactive maps
4. **Cloud Optimization**: Support Cloud-Optimized GeoTIFFs (COGs)
5. **Parallelization**: Use Dask or multiprocessing for batch operations
6. **Validation Tools**: Compare against historical flood extents

### Long-Term (Significant Development)

1. **Simplified Hydrodynamics**: Integrate 2D shallow water solver (e.g., LISFLOOD-FP lite)
2. **Infrastructure Database**: Include levees, dams, and protection structures
3. **Temporal Modeling**: Add time-series capability for storm surge or SLR
4. **Coupled Modeling**: Interface with meteorological/oceanographic models
5. **Machine Learning**: Use ML to correct bathtub model biases
6. **Uncertainty Quantification**: Monte Carlo simulation with DEM error propagation
7. **Web Platform**: Deploy as web service with cloud processing

---

## Validation and Quality Assurance

### Current Limitations in Validation

1. **No Comparison to Observations**: Does not validate against historical flood events
2. **No Skill Metrics**: Cannot compute accuracy, precision, recall against known floods
3. **No Sensitivity Analysis**: Uncertainty in inputs not systematically explored
4. **No Benchmark Datasets**: No standard test cases for model verification

### Recommended Validation Approaches

1. **Historical Comparison**: Compare model outputs to documented historical floods
2. **Cross-Model Comparison**: Compare to outputs from advanced hydrodynamic models
3. **Expert Review**: Have domain experts evaluate results for plausibility
4. **Sensitivity Testing**: Vary DEM vertical accuracy, water level, buffer distance
5. **Commission/Omission Analysis**: Identify false positives and false negatives

---

## Disclaimer

**This flood risk mapping tool is a simplified screening model and should not be used as the sole basis for critical decisions.** Results represent topographic susceptibility to inundation under idealized conditions, not predictions of actual flood extent. 

For applications requiring high accuracy, regulatory compliance, or public safety, consult with professional hydrologists and use advanced hydrodynamic models that account for:
- Dynamic water flow
- Time-dependent processes
- Infrastructure effects
- Detailed calibration and validation
- Uncertainty quantification

**Users are responsible for understanding these limitations and using outputs appropriately.**

---

## References and Further Reading

### Advanced Flood Modeling Tools

- **HEC-RAS**: US Army Corps of Engineers hydrodynamic model
- **MIKE FLOOD**: DHI's integrated flood modeling suite
- **LISFLOOD-FP**: Fast 2D flood inundation model
- **Delft3D**: Deltares' 3D hydrodynamic modeling suite
- **ANUGA**: Australian National University's tsunami and flood model

### Methodological Papers

- Bates, P. D., & De Roo, A. P. (2000). A simple raster-based model for flood inundation simulation. *Journal of Hydrology*.
- Gallien, T. W. et al. (2011). Predicting tidal flooding of urbanized embayments: A modeling framework and data requirements. *Coastal Engineering*.
- Seenath, A., et al. (2016). Hydrodynamic versus GIS modelling for coastal flood vulnerability assessment: Which is better for guiding coastal management? *Ocean & Coastal Management*.

### Standards and Guidelines

- FEMA Guidelines and Standards for Flood Risk Analysis and Mapping
- EU Floods Directive (2007/60/EC)
- ISO 19115 - Geographic Information Metadata

---

**Document Version**: 1.0  
**Last Updated**: March 10, 2026  
**Status**: Living document - update as model evolves
