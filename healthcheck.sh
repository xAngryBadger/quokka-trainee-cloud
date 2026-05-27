#!/bin/sh
# Healthcheck — valida endpoint /health da API de fora do container
# Uso: ./healthcheck.sh [HOST] [PORT]
# Sem dependencia de Python — usa wget apenas (compativel com busybox wget)

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}/health"

# Requisicao wget unica: captura codigo de status e corpo
response=$(wget -qO- --timeout=5 "$URL" 2>&1)
http_code=$?

if [ $http_code -ne 0 ]; then
  echo "CRITICO - HTTP ${http_code:-none} de ${URL}"
  exit 1
fi

# Verifica se o corpo da resposta contém "status":"healthy"
if echo "$response" | grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
  echo "OK - API saudavel em ${URL}"
  exit 0
else
  echo "CRITICO - API respondeu 200 mas corpo sem status healthy em ${URL}"
  exit 1
fi

# Extrai corpo (tudo apos a ultima linha em branco separando headers do corpo)
body=$(echo "$response" | sed -n '/^$/,$ p' | tail -n +2)

# Verifica se o corpo da resposta contém "status":"healthy"
if echo "$body" | grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"'; then
echo "OK - API saudavel em ${URL}"
exit 0
else
echo "CRITICO - API respondeu 200 mas corpo sem status healthy em ${URL}"
exit 1
fi
