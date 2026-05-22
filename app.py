from datetime import UTC, datetime

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.now(UTC).isoformat(),
            "version": "1.0.0",
        }
    )


@app.route("/")
def index():
    return jsonify({"message": "Trainee DevOps API"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)  # noqa: S104 — containers must bind to all interfaces
