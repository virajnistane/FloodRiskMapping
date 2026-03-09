# Design Document: Flood Risk Mapping Pipeline

## Overview

This document describes the key design choices made in the flood risk mapping pipeline. The system is designed to be modular, configurable, and testable, with a focus on reproducibility and maintainability.

## Table of Contents

1. [Architecture](#architecture)
2. [Configuration System](#configuration-system)
3. [Modular Design](#modular-design)
4. [Type Safety](#type-safety)
5. [Testing Strategy](#testing-strategy)
6. [CLI Design](#cli-design)
7. [Data Management](#data-management)
8. [Visualization](#visualization)
9. [Future Enhancements](#future-enhancements)

---

## Architecture

### Core Principles

The pipeline follows these core architectural principles:

1. **Separation of Concerns**: Each module handles a specific aspect of the pipeline (data loading, processing, visualization)
2. **Configuration-Driven**: All parameters are externalized to YAML configuration files
3. **Composability**: Components can be used independently or composed together
4. **Reproducibility**: Configuration files and DVC enable full reproducibility of results

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    CLI Interface                             │
│              (pipeline.py, viz.py)                           │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ├─────> Config (config.py)
                        │       - YAML parsing
                        │       - Path management
                        │       - Parameter validation
                        │
                        ├─────> Data Loading (load_data.py)
                        │       - DEM reading (rasterio)
                        │       - Metadata extraction
                        │
                        ├─────> Processing
                        │       │
                        │       ├─> CoastlineBuffer (coastline_buffer.py)
                        │       │   - Vector buffer creation
                        │       │   - Rasterization
                        │       │
                        │       └─> FloodRiskPipeline (pipeline.py)
                        │           - Flood mask computation
                        │           - Polygon extraction
                        │           - Area calculation
                        │
                        └─────> Visualization (viz.py)
                                - Flood maps
                                - Multi-layer overlays
```

---

## Configuration System

### Design Choice: YAML over INI

**Decision**: Use YAML for configuration files instead of INI format.

**Rationale**:
- **Nested Structure**: YAML supports hierarchical configuration (info, data, pipeline, visualization sections)
- **Type Support**: Native support for strings, numbers, booleans, and null values
- **Comments**: Better commenting support for documentation
- **Industry Standard**: YAML is widely used in data science and DevOps workflows

**Example Structure**:
```yaml
info:
  name: "delft"
  description: "Flood risk mapping for Delft"
  
data:
  raw_dir: "data/raw"
  dem_file: "dem_delft.tif"
  
pipeline:
  water_level: 2.0
  metric_crs: 3857
```

### Multi-Configuration Architecture

**Design Choice**: Support multiple configuration files instead of a single monolithic config.

**Rationale**:
- **Regional Independence**: Different regions (Delft, Nice) can have independent configurations
- **Parallel Execution**: Multiple configs enable parallel processing of different regions
- **Output Isolation**: Prevents output file collisions (e.g., flood_map_delft.png vs flood_map_nice.png)
- **Experimentation**: Easy to create new configs for experiments without modifying existing ones

**Implementation**: `configs/config_delft.yaml`, `configs/config_nice.yaml`

### Config Class Design

**Design Choice**: Use a Python class with properties instead of raw dictionaries.

**Rationale**:
- **Type Safety**: Properties provide clear interfaces with type hints
- **Validation**: Centralized validation and path resolution
- **Defaults**: Graceful handling of missing optional parameters
- **IDE Support**: Better autocomplete and documentation
- **Path Management**: Automatic creation of output directories

**Key Features**:
```python
@property
def dem_path(self) -> Path:
    """Resolves and returns absolute DEM path."""
    return self.raw_dir / self._config["data"]["dem_file"]
```

---

## Modular Design

### Module Structure

```
src/
├── __init__.py        # Package initialization
├── py.typed           # PEP 561 marker for type checking
├── config.py          # Configuration management
├── load_data.py       # DEM loading utilities
├── coastline.py       # Legacy coastline processing
├── coastline_buffer.py # Coastline buffer creation
├── pipeline.py        # Main flood risk pipeline
└── viz.py             # Visualization functions
```

### Design Choices

1. **Single Responsibility**: Each module has one primary responsibility
2. **Minimal Dependencies**: Modules depend only on what they need
3. **Testability**: Each module can be tested independently
4. **Reusability**: Functions can be imported and used in notebooks or other scripts

### FloodRiskPipeline Class

**Design Choice**: Encapsulate pipeline logic in a stateful class.

**Rationale**:
- **State Management**: Maintains DEM dataset, coastline buffer, and computed results
- **Method Chaining**: Natural workflow with sequential method calls
- **Context Preservation**: CRS, transforms, and metadata preserved throughout pipeline
- **Extensibility**: Easy to add new methods or override behavior

**Usage Pattern**:
```python
pipeline = FloodRiskPipeline(config=cfg, dem_path=cfg.dem_path, ...)
dem = pipeline.load_dem(cfg.dem_path)
mask = pipeline.compute_flood_mask(dem)
pipeline.save_flood_raster(dem, mask, output_path)
```

---

## Type Safety

### Design Choice: Full Type Hints with mypy

**Decision**: Add type hints to all functions and use mypy for static type checking.

**Rationale**:
- **Early Error Detection**: Catch type errors before runtime
- **Documentation**: Type hints serve as inline documentation
- **IDE Support**: Better autocomplete and refactoring tools
- **Code Quality**: Encourages clearer interfaces and better design

### PEP 561 Compliance

**Design Choice**: Add `py.typed` marker file.

**Rationale**:
- **Library Stubs**: Enables type checkers to recognize the package
- **Import Checking**: Resolves "Cannot find implementation or library stub" warnings
- **Best Practice**: Follows Python typing best practices

### Type Stubs

**Design Choice**: Install type stub packages for dependencies.

**Packages**:
- `pandas-stubs`: Type hints for pandas operations
- `types-shapely`: Type hints for Shapely geometry operations
- `types-pyyaml`: Type hints for YAML parsing

**Mypy Configuration**:
```ini
[mypy]
ignore_missing_imports = True

[mypy-rasterio.*]
ignore_missing_imports = True
```

---

## Testing Strategy

### Test Structure

```
tests/
├── __init__.py
├── test_config.py           # Configuration system tests
├── test_load_data.py        # DEM loading tests
├── test_coastline_buffer.py # Coastline buffer tests
├── test_pipeline.py         # Pipeline integration tests
└── test_viz.py              # Visualization tests
```

### Design Choices

#### 1. Pytest Framework

**Rationale**:
- **Fixtures**: Reusable test data and setup code
- **Parametrization**: Test multiple scenarios efficiently
- **Assertions**: Clear, informative failure messages
- **Plugins**: Extensible with pytest plugins

#### 2. Fixture-Based Testing

**Design Choice**: Use pytest fixtures for common test data (DEM datasets, configs, paths).

**Example**:
```python
@pytest.fixture
def test_config():
    """Fixture to load test configuration."""
    return load_config("configs/config_delft.yaml")

@pytest.fixture
def test_dem():
    """Fixture to load test DEM."""
    return load_dem(Path("data/raw/dem_delft.tif"))
```

**Benefits**:
- **DRY Principle**: Avoid duplicating setup code
- **Isolation**: Each test gets fresh instances
- **Cleanup**: Automatic resource cleanup

#### 3. Temporary File Handling

**Design Choice**: Use `tmp_path` fixture for all file outputs in tests.

**Rationale**:
- **Isolation**: Tests don't interfere with each other
- **Cleanup**: pytest automatically removes temporary directories
- **Safety**: No risk of overwriting production data

#### 4. Conditional Testing

**Design Choice**: Use `pytest.skip()` for tests requiring external data.

**Example**:
```python
if not dem_path.exists():
    pytest.skip(f"Test DEM file not found: {dem_path}")
```

**Benefits**:
- **Flexibility**: Tests run in CI without requiring large data files
- **Documentation**: Clearly indicates data dependencies
- **Developer Experience**: Tests pass even if optional data is missing

#### 5. Test Coverage

**Coverage Areas**:
- **Unit Tests**: Individual functions with mocked/temporary data
- **Integration Tests**: End-to-end workflows with real data
- **Error Handling**: Invalid inputs, missing files, edge cases
- **Property Tests**: Verify expected relationships (e.g., higher water level → more flooding)

**Test Count**: 60 comprehensive tests covering all modules

---

## CLI Design

### Design Choice: argparse with Config Files

**Decision**: Use argparse for CLI with `-c/--config` flag to specify configuration files.

**Rationale**:
- **Simplicity**: Single flag controls all parameters
- **Reproducibility**: Config files can be version controlled
- **Flexibility**: Easy to switch between different configurations
- **Standard Library**: No external dependencies for CLI parsing

**Usage**:
```bash
python -m src.pipeline -c configs/config_delft.yaml
python -m src.viz -c configs/config_nice.yaml
```

### Design Choice: Module Execution (`python -m`)

**Decision**: Run scripts as modules rather than direct execution.

**Rationale**:
- **Import Resolution**: Proper handling of relative imports
- **Package Structure**: Maintains clean package structure
- **Best Practice**: Aligns with Python packaging standards

### Help Text

**Design Choice**: Provide detailed help messages with defaults.

**Example**:
```python
parser.add_argument(
    "-c", "--config",
    default="configs/config_delft.yaml",
    help="Path to configuration file (default: configs/config_delft.yaml)"
)
```

---

## Data Management

### DVC Integration

**Design Choice**: Use DVC (Data Version Control) for large data files.

**Rationale**:
- **Version Control**: Track data changes without storing large files in Git
- **Reproducibility**: Link code versions with data versions
- **Collaboration**: Share data via remote storage
- **Efficiency**: Only download data when needed

**DVC Files**:
- `data/processed/flood_mask_*.tif.dvc`
- `data/processed/flood_polygons_*.gpkg.dvc`
- `data/processed/flood_summary_*.txt.dvc`

### Directory Structure

**Design Choice**: Separate raw, intermediate, and processed data.

```
data/
├── raw/              # Original, immutable input data
├── interim/          # Intermediate processing results
└── processed/        # Final outputs
    └── flood_maps/   # Visualization outputs (not tracked by DVC)
```

**Rationale**:
- **Data Pipeline**: Clear flow from raw to processed
- **Reproducibility**: Raw data never modified
- **Organization**: Easy to identify data stage
- **Cleanup**: Safe to delete interim/processed and regenerate

### Visualization Outputs

**Design Choice**: Store plots in `processed/flood_maps/` subdirectory, tracked by Git (not DVC).

**Rationale**:
- **Lightweight**: PNG images are small enough for Git
- **Convenience**: No need to `dvc pull` for visualizations
- **Documentation**: Plots serve as documentation in README
- **Separation**: Clearly distinguishes raster data (DVC) from plots (Git)

---

## Visualization

### Design Choices

#### 1. Matplotlib for Visualization

**Rationale**:
- **Integration**: Works seamlessly with rasterio and numpy
- **Flexibility**: Full control over plot appearance
- **Publication Quality**: High-resolution outputs
- **Familiar**: Standard tool in scientific Python

#### 2. Figure Cleanup

**Design Choice**: Always call `plt.close()` after saving figures.

**Rationale**:
- **Memory Management**: Prevents memory leaks in batch processing
- **Resource Cleanup**: Releases figure resources
- **Best Practice**: Professional matplotlib usage

**Implementation**:
```python
fig, ax = plt.subplots(figsize=(12, 10))
# ... plotting code ...
fig.savefig(output_path, dpi=300, bbox_inches="tight")
plt.close(fig)
```

#### 3. Configurable Visualization

**Design Choice**: All visualization parameters in config files.

**Parameters**:
- `dpi`: Output resolution
- `figsize`: Figure dimensions
- `cmap_dem`: DEM colormap
- `cmap_flood`: Flood overlay colormap
- `output paths`: Separate files per configuration

**Benefits**:
- **Consistency**: Uniform appearance across runs
- **Customization**: Per-region styling without code changes
- **Reproducibility**: Exact visual outputs can be recreated

#### 4. Multiple Output Formats

**Design Choice**: Support PNG, JPG, PDF, and other formats via file extension.

**Implementation**: Matplotlib automatically detects format from extension.

**Example**:
```python
plot_flood(dem_path, mask_path, "output.png")  # PNG
plot_flood(dem_path, mask_path, "output.pdf")  # PDF
```

---

## Future Enhancements

### Potential Improvements

1. **Performance Optimization**
   - Chunked processing for very large DEMs
   - Parallel processing for multiple regions
   - Caching of intermediate results

2. **Extended Functionality**
   - Multiple water level scenarios in single run
   - Uncertainty quantification
   - Temporal flood evolution modeling
   - Building/infrastructure exposure analysis

3. **Additional Outputs**
   - Interactive maps (Folium, Leaflet)
   - 3D visualizations
   - Animated flood sequences
   - Statistical reports (CSV, JSON)

4. **Cloud Integration**
   - Cloud-optimized GeoTIFF (COG) support
   - S3/Azure blob storage for DVC remote
   - Serverless execution on AWS Lambda/GCP Functions

5. **Validation and Quality Assurance**
   - Validation against historical flood data
   - Automated quality checks for DEM inputs
   - Sensitivity analysis tools
   - Model performance metrics

6. **Documentation Enhancements**
   - API documentation with Sphinx
   - Jupyter notebook tutorials
   - Video walkthroughs
   - Case study examples

### Backward Compatibility

All future enhancements should maintain backward compatibility with existing configuration files and APIs. Deprecation warnings should be used before removing functionality.

---

## Design Philosophy Summary

The flood risk mapping pipeline is designed with these overarching principles:

1. **Clarity over Cleverness**: Code should be easy to understand and maintain
2. **Configuration over Code**: Parameters belong in config files, not hardcoded
3. **Testing is Non-Negotiable**: All code should be thoroughly tested
4. **Reproducibility First**: Results should be exactly reproducible from code + config + data
5. **Modularity Enables Reuse**: Components should work independently and together
6. **Type Safety Prevents Errors**: Static type checking catches bugs before runtime
7. **Documentation is Code**: README, docstrings, and type hints are essential

---

## References

- [PEP 561 - Distributing and Packaging Type Information](https://www.python.org/dev/peps/pep-0561/)
- [Rasterio Documentation](https://rasterio.readthedocs.io/)
- [GeoPandas User Guide](https://geopandas.org/)
- [pytest Documentation](https://docs.pytest.org/)
- [DVC Documentation](https://dvc.org/doc)
- [Python Type Hints - mypy](https://mypy.readthedocs.io/)

---

**Document Version**: 1.0  
**Last Updated**: March 10, 2026  
**Authors**: Flood Risk Mapping Team
