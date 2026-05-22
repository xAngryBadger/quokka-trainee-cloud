#!/bin/sh
# Healthcheck — validates API /health endpoint from outside the container
# Usage: ./healthcheck.sh [HOST] [PORT]
# No python dependency — uses wget only (compatible with busybox wget)

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}/health"

# Single wget request: capture both status code and body
# busybox wget supports -q -O- and -S (server response headers)
response=$(wget -qO- --timeout=5 -S "$URL" 2>&1)

# Extract HTTP status code from headers (last occurrence for redirects)
http_code=$(echo "$response" | awk '/HTTP\//{print $2}' | tail -1)

if [ "$http_code" != "200" ]; then
    echo "CRITICAL - HTTP ${http_code:-none} from ${URL}"
    exit 1
fi

# Extract body (everything after the last blank line separating headers from body)
body=$(echo "$response" | sed -n '/^$/,$ p' | tail -n +2)

# Check that the response body contains "status":"healthy"
if echo "$body" | grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
    echo "OK - API is healthy at ${URL}"
    exit 0
else
    echo "CRITICAL - API responded 200 but body missing healthy status at ${URL}"
    exit 1
fi
