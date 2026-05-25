#!/bin/sh
# Healthcheck — valida endpoint /health da API de fora do container
# Uso: ./healthcheck.sh [HOST] [PORT]
# Sem dependencia de Python — usa wget apenas (compativel com busybox wget)

HOST="${1:-localhost}"
PORT="${2:-5000}"
URL="http://${HOST}:${PORT}/health"

# Requisicao wget unica: captura codigo de status e corpo
# busybox wget suporta -q -O- e -S (headers da resposta do servidor)
response=$(wget -qO- --timeout=5 -S "$URL" 2>&1)

# Extrai codigo HTTP dos headers (ultima ocorrencia para redirecionamentos)
http_code=$(echo "$response" | awk '/HTTP\//{print $2}' | tail -1)

if [ "$http_code" != "200" ]; then
echo "CRITICO - HTTP ${http_code:-none} de ${URL}"
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
