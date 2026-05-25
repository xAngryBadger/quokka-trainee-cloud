# syntax=docker/dockerfile:1
# ==============================================================================
# ESTÁGIO 1: BUILDER
# Propósito: Instalar dependências em ambiente isolado.
# Por quê: Separamos ferramentas de "build" (pip, gcc, etc.) do runtime final.
# Isso mantém a imagem final leve e segura, excluindo caches e headers de build.
# ==============================================================================
FROM python:3.12.7-alpine3.20 AS builder

# Define o diretório de trabalho para o build
WORKDIR /build

# Copia apenas a lista de dependências primeiro
# Por quê: Aproveita o cache de camadas do Docker. Se requirements.txt não mudou,
# o Docker pula o passo caro de 'pip install' em builds subsequentes.
COPY requirements.txt .

# Instala dependências em um prefixo específico (/install)
# Nota: Usamos 'pip install' padrão para máxima compatibilidade.
# (Anteriormente usava --mount=type=cache para BuildKit, mas removido para compatibilidade).
RUN pip install --prefix=/install -r requirements.txt

# ==============================================================================
# ESTÁGIO 2: RUNTIME
# Propósito: Criar ambiente mínimo e seguro para rodar a aplicação.
# Por quê: Multi-stage permite copiar APENAS as bibliotecas necessárias do Stage 1,
# deixando para trás compiladores, headers e arquivos temporários.
# ==============================================================================
FROM python:3.12.7-alpine3.20

# Metadata: Identifica o mantenedor e propósito da imagem
LABEL maintainer="Trainee Cloud & IA - Isaac Nathan"
LABEL description="API Flask com Health Check para pipeline CI/CD"

# SEGURANÇA: Cria usuário não-root
# Por quê: Rodar como 'root' dentro de container é perigoso. Se um atacante explorar
# a aplicação, terá privilégios limitados (appuser) ao invés de controle total.
RUN adduser -D -s /bin/sh appuser

# Define o diretório de trabalho final da aplicação
WORKDIR /app

# Copia as dependências instaladas do builder stage
# Caminho: /install (do builder) -> /usr/local (no runtime)
COPY --from=builder /install /usr/local

# Copia o código fonte da aplicação
COPY app.py .

# PERMISSÕES: Garante que o usuário não-root seja dono dos arquivos
# Por quê: Permite que a aplicação leia seu próprio código se necessário, mas previne modificação.
RUN chown -R appuser:appuser /app

# SEGURANÇA: Troca para o usuário não-root
# Por quê: Aplica o princípio do menor privilégio.
USER appuser

# REDE: Expõe a porta 5000
# Por quê: Informa ao Docker e ferramentas de orquestração (K8s, ECS) que a aplicação escuta na 5000.
EXPOSE 5000

# HEALTHCHECK: Define como o Docker verifica se a aplicação está viva
# Comando: Tenta buscar o endpoint /health.
# Lógica: Usa urllib para verificar conectividade E afirma HTTP 200 OK.
# Por quê: Se a aplicação travar ou retornar erros 500, o Docker marca o container como 'unhealthy',
# acionando restart (no Swarm/K8s) ou alertando o operador.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
CMD python -c "import urllib.request; r=urllib.request.urlopen('http://localhost:5000/health'); assert r.status==200" || exit 1

# CMD: Comando executado quando o container inicia
# Ferramenta: Gunicorn (WSGI Server de Produção)
# Config: 2 workers, 4 threads cada, bound a 0.0.0.0:5000
# Por quê Gunicorn? O servidor built-in do Flask é apenas para desenvolvimento. Gunicorn é estável,
# lida com requisições concorrentes e é production-ready.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "app:app"]
