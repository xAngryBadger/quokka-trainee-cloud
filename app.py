"""
API Trainee DevOps — Aplicação Flask com logging e tratamento de erros para produção.

Esta é uma API simples de health check para o desafio Trainee Cloud & IA.
Usa Gunicorn WSGI server (veja CMD do Dockerfile) para deploy em produção.
"""

import logging
import sys
from datetime import UTC, datetime
from typing import Any

from flask import Flask, Response, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


def get_client_key():
    """
    Obtém endereço IP do cliente para rate limiting.
    Usa header X-Forwarded-For quando atrás de ALB/reverse proxy.
    Fallback para remote_address se header não presente.
    """
    if request.headers.get("X-Forwarded-For"):
        return request.headers.get("X-Forwarded-For").split(",")[0].strip()
    return get_remote_address()


# Configura logging estruturado
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [%(name)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configura rate limiting
# Nota: Armazenamento em memória significa que rate limits NÃO são compartilhados entre réplicas do container.
# Para produção com múltiplas tasks ECS, use Redis: storage_uri="redis://..."
# Veja README para limitações e recomendações.
limiter = Limiter(
    key_func=get_client_key,
    app=app,
    default_limits=["100 per hour"],
    storage_uri="memory://",
)

# Garante que todos os logs vão para stdout para captura do Docker
app.logger.handlers = []
app.logger.addHandler(logging.StreamHandler(sys.stdout))
app.logger.setLevel(logging.INFO)


@app.before_request
def log_request() -> None:
    """Registra requisições de entrada para observabilidade."""
    logger.info(f"GET {request.path} from {request.remote_addr}")


@app.after_request
def log_response(response: Response) -> Response:
    """Registra status codes das respostas."""
    logger.info(f"Response {response.status_code} for {request.path}")
    return response


@app.errorhandler(Exception)
def handle_error(e: Exception) -> tuple[Response, int]:
    """Handler global de erros - previne que exceções não tratadas vaze informações."""
    logger.error(f"Unhandled exception in {request.path}: {str(e)}", exc_info=True)
    return jsonify({"error": "internal_server_error"}), 500


@app.errorhandler(404)
def handle_404(e: Exception) -> tuple[Response, int]:
    """Trata erros 404 graciosamente."""
    logger.info("404 Not Found: %s", request.path)
    return jsonify({"error": "not_found"}), 404


@app.route("/health")
@limiter.limit("10 per minute")
def health() -> tuple[Response, int] | Response:
    """
    Endpoint de health check.

    Retorna:
        JSON com status, timestamp (ISO8601 UTC) e versão.
    """
    try:
        health_data: dict[str, Any] = {
            "status": "healthy",
            "timestamp": datetime.now(UTC).isoformat(),
            "version": "1.0.0",
        }
        logger.debug("Health check passed")
        return jsonify(health_data)
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", exc_info=True)
        return jsonify({"error": "health_check_failed", "message": str(e)}), 500


@app.route("/")
@limiter.limit("10 per minute")
def index() -> Response | tuple[Response, int]:
    """
    Endpoint raiz.

    Retorna:
        JSON com mensagem de boas-vindas.
    """
    try:
        return jsonify({"message": "Trainee DevOps API"})
    except Exception as e:
        logger.error(f"Index endpoint error: {str(e)}", exc_info=True)
        return jsonify({"error": "internal_server_error", "message": str(e)}), 500


if __name__ == "__main__":
    # NOTA: Isso é apenas para teste de desenvolvimento local.
    # Produção usa Gunicorn (veja CMD do Dockerfile).
    # O servidor dev do Flask é single-threaded e não é production-ready.
    logger.warning("Running Flask dev server (NOT for production use)")
    app.run(host="0.0.0.0", port=5000, debug=False) # noqa: S104
