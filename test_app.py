from app import app


def test_health():
    """Testa endpoint de health check."""
    client = app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "healthy"


def test_index():
    """Testa endpoint raiz."""
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200


def test_404_error():
    """Testa handler de erro 404 para rotas nao existentes."""
    client = app.test_client()
    response = client.get("/nonexistent")
    assert response.status_code == 404
    assert response.json["error"] == "not_found"


def test_500_error_handler():
    """Testa handler de erro 500 retorna resposta correta."""
    from app import handle_error

    with app.test_request_context("/test"):
        response = handle_error(Exception("test error"))
        assert response[1] == 500
        assert response[0].json["error"] == "internal_server_error"
