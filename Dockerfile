# syntax=docker/dockerfile:1
# Stage 1: Builder — dependency install isolated from runtime
# Separating install from runtime means the final image excludes
# pip cache, build tools, and any transitive build artifacts.
# Pinning to specific Alpine version for reproducibility and supply-chain security
FROM python:3.12.7-alpine3.20 AS builder

WORKDIR /build

# Cache invalidated only when requirements change — code rebuilds don't
# trigger pip reinstall, cutting build time on iteration.
# --mount=type=cache reuses pip download cache across builds (requires BuildKit).
COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt


# Stage 2: Runtime — minimal image, non-root, hardened
# Pinning to specific Alpine version for reproducibility and supply-chain security
FROM python:3.12.7-alpine3.20

LABEL maintainer="Trainee Cloud & IA"
LABEL description="API Flask — Health Check para pipeline CI/CD"

# Non-root user: a compromised process has no root privileges inside the container
RUN adduser -D -s /bin/sh appuser

WORKDIR /app

# Dependencies from builder — no pip cache, no build toolchain
COPY --from=builder /install /usr/local

# Copy application source code
COPY app.py .

# Ensure appuser owns the application files
RUN chown -R appuser:appuser /app

# Switch to non-root user for security (least privilege)
USER appuser

# Expose port 5000 for Flask/Gunicorn
EXPOSE 5000

# Use Gunicorn production WSGI server with 2 workers, 4 threads each
# More robust than Flask dev server for concurrent requests
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; r=urllib.request.urlopen('http://localhost:5000/health'); assert r.status==200" || exit 1

# Run Gunicorn WSGI server (production-ready)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "app:app"]
