from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }
    )


@app.route("/")
def index():
    return jsonify({"message": "Trainee DevOps API"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
