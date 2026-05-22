# syntax=docker/dockerfile:1
# Stage 1: Builder — dependency install isolated from runtime
# Separating install from runtime means the final image excludes
# pip cache, build tools, and any transitive build artifacts.
FROM python:3.12-alpine AS builder

WORKDIR /build

# Cache invalidated only when requirements change — code rebuilds don't
# trigger pip reinstall, cutting build time on iteration.
# --mount=type=cache reuses pip download cache across builds (requires BuildKit).
COPY requirements.txt .

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt


# Stage 2: Runtime — minimal image, non-root, hardened
FROM python:3.12-alpine

LABEL maintainer="Trainee Cloud & IA"
LABEL description="API Flask — Health Check para pipeline CI/CD"

# Non-root user: a compromised process has no root privileges inside the container
RUN adduser -D -s /bin/sh appuser

WORKDIR /app

# Dependencies from builder — no pip cache, no build toolchain
COPY --from=builder /install /usr/local

COPY app.py .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5000

# Healthcheck validates both connectivity AND HTTP 200 —
# urlopen alone doesn't catch 5xx responses
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; r=urllib.request.urlopen('http://localhost:5000/health'); assert r.status==200" || exit 1

CMD ["python", "app.py"]
