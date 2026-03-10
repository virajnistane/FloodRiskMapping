# Docker Deployment Guide

## Overview

This project includes Docker support for containerized deployment, making it easy to run the flood risk mapping pipeline in any environment without manual dependency installation.

## Quick Start

### Build the Image

```bash
docker build -t floodriskmap:latest .
```

### Run the Pipeline

```bash
# Using default config
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs:/app/configs \
  floodriskmap:latest

# Using specific config
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs:/app/configs \
  -e DEFAULT_CONFIG=/app/configs/config_nice.yaml \
  floodriskmap:latest

# Run visualization
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs:/app/configs \
  floodriskmap:latest \
  python -m src.viz -c /app/configs/config_delft.yaml
```

## Using Docker Compose

Docker Compose simplifies multi-container workflows:

```bash
# Build and run pipeline
docker-compose up floodmap

# Run visualization
docker-compose up viz

# Run both
docker-compose up

# Build without cache
docker-compose build --no-cache

# Run in background
docker-compose up -d
```

### With DVC and AWS S3

```bash
# Set AWS credentials in environment
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1

# Run with DVC push
docker-compose run floodmap python -m src.pipeline -c /app/configs/config_delft.yaml --push-data
```

## Volume Mounts

The container expects three volume mounts:

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `./data` | `/app/data` | Input/output data files |
| `./configs` | `/app/configs` | Configuration files |
| `./data/processed` | `/app/data/processed` | Output results |

**Example**:
```bash
docker run --rm \
  -v /path/to/your/data:/app/data \
  -v /path/to/your/configs:/app/configs \
  floodriskmap:latest
```

## Environment Variables

Configure the container with environment variables:

```bash
docker run --rm \
  -e DEFAULT_CONFIG=/app/configs/config_nice.yaml \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs:/app/configs \
  floodriskmap:latest
```

## Interactive Mode

For debugging or exploration:

```bash
# Start interactive shell
docker run -it --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/configs:/app/configs \
  floodriskmap:latest \
  /bin/bash

# Inside container
python -m src.pipeline -c /app/configs/config_delft.yaml
python -m src.viz -c /app/configs/config_delft.yaml
pytest tests/  # If tests are copied
```

## Advanced Usage

### Custom Python Commands

```bash
# Run Python interactively
docker run -it --rm \
  -v $(pwd)/data:/app/data \
  floodriskmap:latest \
  python

# Run specific script
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/notebooks:/app/notebooks \
  floodriskmap:latest \
  python /app/notebooks/analysis.py
```

### Jupyter Notebook in Container

Add to Dockerfile:
```dockerfile
RUN uv pip install jupyter
EXPOSE 8888
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--allow-root", "--no-browser"]
```

Run:
```bash
docker run -p 8888:8888 \
  -v $(pwd)/notebooks:/app/notebooks \
  -v $(pwd)/data:/app/data \
  floodriskmap:latest
```

### Multi-Stage Build (Smaller Image)

For production, use multi-stage builds to reduce image size:

```dockerfile
# Builder stage
FROM python:3.12-slim AS builder
# ... install dependencies ...

# Runtime stage
FROM python:3.12-slim
COPY --from=builder /app/.venv /app/.venv
# ... minimal runtime files ...
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Docker Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t floodriskmap:${{ github.sha }} .
      
      - name: Run tests in container
        run: |
          docker run --rm floodriskmap:${{ github.sha }} \
            pytest tests/
      
      - name: Push to registry
        if: github.ref == 'refs/heads/main'
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker tag floodriskmap:${{ github.sha }} yourusername/floodriskmap:latest
          docker push yourusername/floodriskmap:latest
```

## Cloud Deployment

### AWS ECS

```bash
# Build for ARM64 (Graviton)
docker build --platform linux/arm64 -t floodriskmap:arm64 .

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker tag floodriskmap:latest YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/floodriskmap:latest
docker push YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/floodriskmap:latest

# Run on ECS Fargate
# Create task definition with S3 permissions, mount EFS for data
```

### Google Cloud Run

```bash
# Build and push to GCR
gcloud builds submit --tag gcr.io/YOUR_PROJECT/floodriskmap

# Deploy
gcloud run deploy floodriskmap \
  --image gcr.io/YOUR_PROJECT/floodriskmap \
  --platform managed \
  --region us-central1 \
  --memory 4Gi \
  --timeout 3600
```

### Kubernetes

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: floodmap-delft
spec:
  template:
    spec:
      containers:
      - name: floodmap
        image: floodriskmap:latest
        env:
        - name: DEFAULT_CONFIG
          value: /app/configs/config_delft.yaml
        volumeMounts:
        - name: data-volume
          mountPath: /app/data
        - name: config-volume
          mountPath: /app/configs
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: flood-data-pvc
      - name: config-volume
        configMap:
          name: flood-configs
      restartPolicy: OnFailure
```

## Troubleshooting

### GDAL Issues

**Error**: `ERROR 4: Unable to open EPSG support file`

**Solution**: Ensure GDAL environment variables are set:
```dockerfile
ENV GDAL_DATA=/usr/share/gdal
ENV PROJ_LIB=/usr/share/proj
```

### Permission Errors

**Error**: `Permission denied: '/app/data/processed'`

**Solution**: Ensure mounted volumes have correct permissions:
```bash
# On host
chmod -R 755 data/

# Or run as root (not recommended)
docker run --user root ...
```

### Out of Memory

**Error**: Container killed due to OOM

**Solution**: Increase memory limit:
```bash
docker run --memory=4g --memory-swap=4g ...
```

Or in docker-compose.yml:
```yaml
services:
  floodmap:
    mem_limit: 4g
    memswap_limit: 4g
```

### Slow Builds

**Solution**: Use build cache and .dockerignore:
```bash
# Ensure .dockerignore excludes data/ and .venv/
docker build --cache-from floodriskmap:latest -t floodriskmap:latest .
```

## Best Practices

1. **Use .dockerignore** – Exclude unnecessary files (data/, .venv/, .git/)
2. **Layer caching** – Copy dependency files before source code
3. **Non-root user** – Run container as unprivileged user
4. **Multi-stage builds** – Separate build and runtime stages
5. **Health checks** – Add HEALTHCHECK instruction for production
6. **Security scanning** – Use `docker scan` or Trivy
7. **Pin versions** – Use specific Python/GDAL versions, not `latest`
8. **Secrets management** – Use Docker secrets or env files, never bake into image

## Image Size Optimization

Current image: ~800 MB (with GDAL dependencies)

**Optimizations**:
- Use `python:3.12-slim` (current): ~150 MB base
- Multi-stage build: Reduces to ~600 MB
- Alpine Linux: ~400 MB (but GDAL compatibility issues)
- Distroless: ~550 MB (no shell, very secure)

## Reference

- [Dockerfile](../Dockerfile)
- [docker-compose.yml](../docker-compose.yml)
- [.dockerignore](../.dockerignore)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

**Document Version**: 1.0  
**Last Updated**: March 10, 2026  
**Maintained by**: Flood Risk Mapping Team
