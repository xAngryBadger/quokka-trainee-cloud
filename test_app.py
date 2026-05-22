from app import app


def test_health():
    client = app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "healthy"


def test_index():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200


def test_404_error():
    """Test 404 error handler for non-existent routes."""
    client = app.test_client()
    response = client.get("/nonexistent")
    assert response.status_code == 404
    assert response.json["error"] == "not_found"


def test_500_error_handler():
    """Test 500 error handler returns correct response."""
    from app import handle_error
    with app.test_request_context("/test"):
        response = handle_error(Exception("test error"))
        assert response[1] == 500
        assert response[0].json["error"] == "internal_server_error"
