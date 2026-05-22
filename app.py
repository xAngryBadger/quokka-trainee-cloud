"""
Trainee DevOps API — Flask application with production logging and error handling.

This is a simple health check API for the Trainee Cloud & IA challenge.
Uses Gunicorn WSGI server (see Dockerfile CMD) for production deployment.
"""

import logging
import sys
from datetime import UTC, datetime
from typing import Any

from flask import Flask, Response, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [%(name)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configure rate limiting
limiter = Limiter(
    key_func=get_remote_address,
    app=app,
    default_limits=["100 per hour"],
    storage_uri="memory://",
)

# Ensure all logs go to stdout for Docker capture
app.logger.handlers = []
app.logger.addHandler(logging.StreamHandler(sys.stdout))
app.logger.setLevel(logging.INFO)


@app.before_request
def log_request() -> None:
    """Log incoming requests for observability."""
    logger.info(f"GET {request.path} from {request.remote_addr}")


@app.after_request
def log_response(response: Response) -> Response:
    """Log response status codes."""
    logger.info(f"Response {response.status_code} for {request.path}")
    return response


@app.errorhandler(Exception)
def handle_error(e: Exception) -> tuple[Response, int]:
    """Global error handler - prevents unhandled exceptions from leaking info."""
    logger.error(f"Unhandled exception in {request.path}: {str(e)}", exc_info=True)
    return jsonify({"error": "internal_server_error"}), 500


@app.errorhandler(404)
def handle_404(e: Exception) -> tuple[Response, int]:
    """Handle 404 errors gracefully."""
    logger.info("404 Not Found: %s", request.path)
    return jsonify({"error": "not_found"}), 404


@app.route("/health")
@limiter.limit("10 per minute")
def health() -> tuple[Response, int] | Response:
    """
    Health check endpoint.

    Returns:
        JSON with status, timestamp (ISO8601 UTC), and version.
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
    Root endpoint.

    Returns:
        JSON welcome message.
    """
    try:
        return jsonify({"message": "Trainee DevOps API"})
    except Exception as e:
        logger.error(f"Index endpoint error: {str(e)}", exc_info=True)
        return jsonify({"error": "internal_server_error", "message": str(e)}), 500


if __name__ == "__main__":
    # NOTE: This is only for local development testing.
    # Production uses Gunicorn (see Dockerfile CMD).
    # The Flask dev server is single-threaded and not production-ready.
    logger.warning("Running Flask dev server (NOT for production use)")
    app.run(host="0.0.0.0", port=5000, debug=False)  # noqa: S104
