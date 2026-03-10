# Use Python 3.12 to match project requirements
FROM python:3.12-slim AS base

# Install system dependencies (GDAL for geospatial operations)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gdal-bin \
    libgdal-dev \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set GDAL environment variables
ENV GDAL_CONFIG=/usr/bin/gdal-config \
    GDAL_DATA=/usr/share/gdal

# Install uv using pip (more reliable in Docker)
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /app

# Copy only dependency files first (for Docker layer caching)
COPY pyproject.toml uv.lock README.md ./

# Install dependencies using uv (without installing the project itself yet)
RUN uv sync --frozen --no-dev --no-install-project

# Add the virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Copy project source code
COPY src ./src
COPY configs ./configs

# Now install the project in editable mode
RUN uv pip install --no-deps -e .

# Create non-root user for security
RUN useradd -m -u 1000 flooduser && \
    chown -R flooduser:flooduser /app
USER flooduser

# Create data directory (to be mounted as volume)
RUN mkdir -p /app/data/raw /app/data/processed /app/data/inter

# Set default config path as environment variable
ENV DEFAULT_CONFIG=/app/configs/config_delft.yaml

# Default command (can be overridden)
CMD ["sh", "-c", "python -m src.pipeline -c ${DEFAULT_CONFIG}"]