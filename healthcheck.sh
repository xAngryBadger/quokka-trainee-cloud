#!/bin/sh
# Healthcheck — validates API /health endpoint from outside the container
# Usage: ./healthcheck.sh [HOST] [PORT]

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}/health"

# Check HTTP status code
http_code=$(wget --spider -S "$URL" 2>&1 | awk '/HTTP\//{print $2}' | tail -1)

if [ "$http_code" != "200" ]; then
  echo "CRITICAL - HTTP ${http_code:-none} from ${URL}"
  exit 1
fi

# Check response body contains healthy status
status=$(python3 -c "import urllib.request, json; r=urllib.request.urlopen('${URL}'); print(json.loads(r.read())['status'])" 2>/dev/null)

if [ "$status" = "healthy" ]; then
  echo "OK - API is healthy at ${URL}"
  exit 0
else
  echo "CRITICAL - API responded 200 but status=${status:-empty} at ${URL}"
  exit 1
fi
