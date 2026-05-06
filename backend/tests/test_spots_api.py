from __future__ import annotations

import io
from pathlib import Path
from urllib.parse import urlparse


def _create_spot(client):
    response = client.post(
        "/spots",
        json={
            "name": "Spot Testowy",
            "type": "Street",
            "address": "Warsaw",
            "latitude": 52.2297,
            "longitude": 21.0122,
            "description": "Manual pad and ledge spot",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "environment" in body
    assert "storage" in body


def test_create_and_list_spots(client):
    created = _create_spot(client)
    assert created["name"] == "Spot Testowy"
    assert created["photo_urls"] == []

    response = client.get("/spots")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == created["id"]


def test_get_single_spot(client):
    created = _create_spot(client)

    response = client.get(f"/spots/{created['id']}")
    assert response.status_code == 200
    assert response.json()["name"] == "Spot Testowy"


def test_create_spot_rejects_invalid_coordinates(client):
    response = client.post(
        "/spots",
        json={
            "name": "Bad Spot",
            "type": "Street",
            "address": "Nowhere",
            "latitude": 120,
            "longitude": 21.0,
        },
    )
    assert response.status_code == 422


def test_upload_photo_updates_spot(client):
    created = _create_spot(client)
    response = client.post(
        f"/spots/{created['id']}/photos",
        files={"files": ("spot.jpg", io.BytesIO(b"fake-image"), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert len(body["photo_urls"]) == 1
    assert body["photos"][0]["file_name"] == "spot.jpg"


def test_upload_photo_rejects_non_image(client):
    created = _create_spot(client)
    response = client.post(
        f"/spots/{created['id']}/photos",
        files={"files": ("notes.txt", io.BytesIO(b"hello"), "text/plain")},
    )
    assert response.status_code == 400


def test_upload_photo_accepts_octet_stream_with_image_extension(client):
    created = _create_spot(client)
    response = client.post(
        f"/spots/{created['id']}/photos",
        files={"files": ("spot.jpg", io.BytesIO(b"fake-image"), "application/octet-stream")},
    )
    assert response.status_code == 200


def test_missing_spot_returns_404(client):
    response = client.get("/spots/999")
    assert response.status_code == 404


def test_create_spot_rate_limit(client):
    for _ in range(20):
        payload = {
            "name": f"Rate Spot {_}",
            "type": "Street",
            "address": "Warsaw",
            "latitude": 52.2297 + (_ * 0.001),
            "longitude": 21.0122 + (_ * 0.001),
        }
        assert client.post("/spots", json=payload).status_code == 201
    limited = client.post(
        "/spots",
        json={
            "name": "Rate Spot overflow",
            "type": "Street",
            "address": "Warsaw",
            "latitude": 52.5,
            "longitude": 21.5,
        },
    )
    assert limited.status_code == 429


def test_create_spot_rejects_blocked_text(client):
    response = client.post(
        "/spots",
        json={
            "name": "fake place",
            "type": "Street",
            "address": "Warsaw",
            "latitude": 52.2297,
            "longitude": 21.0122,
            "description": "all good",
        },
    )
    assert response.status_code == 400


def test_create_spot_rejects_duplicate_name(client):
    _create_spot(client)
    response = client.post(
        "/spots",
        json={
            "name": "Spot Testowy",
            "type": "Street",
            "address": "Other city",
            "latitude": 50.0,
            "longitude": 19.0,
        },
    )
    assert response.status_code == 409


def test_create_spot_rejects_too_close_location(client):
    _create_spot(client)
    response = client.post(
        "/spots",
        json={
            "name": "Nearby Spot",
            "type": "Street",
            "address": "Warsaw",
            "latitude": 52.22972,
            "longitude": 21.01222,
        },
    )
    assert response.status_code == 409


def test_delete_spot(client):
    created = _create_spot(client)
    response = client.delete(f"/spots/{created['id']}")
    assert response.status_code == 204
    fetch = client.get(f"/spots/{created['id']}")
    assert fetch.status_code == 404


def test_delete_spot_removes_uploaded_file(client):
    created = _create_spot(client)
    upload = client.post(
        f"/spots/{created['id']}/photos",
        files={"files": ("spot.jpg", io.BytesIO(b"fake-image"), "image/jpeg")},
    )
    assert upload.status_code == 200
    photo_url = upload.json()["photo_urls"][0]
    file_path = Path(client.app.state.upload_dir) / Path(urlparse(photo_url).path).name
    assert file_path.exists()

    deleted = client.delete(f"/spots/{created['id']}")
    assert deleted.status_code == 204
    assert not file_path.exists()


def test_update_spot_name_and_description(client):
    created = _create_spot(client)
    response = client.patch(
        f"/spots/{created['id']}",
        json={
            "name": "Updated Name",
            "type": "Plaza",
            "address": "Updated address",
            "latitude": 52.3,
            "longitude": 21.1,
            "description": "Updated description",
            "difficulty": "advanced",
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Updated Name"
    assert body["description"] == "Updated description"


def test_delete_photo_removes_uploaded_file(client):
    created = _create_spot(client)
    upload = client.post(
        f"/spots/{created['id']}/photos",
        files={"files": ("spot.jpg", io.BytesIO(b"fake-image"), "image/jpeg")},
    )
    assert upload.status_code == 200
    payload = upload.json()
    photo = payload["photos"][0]
    file_path = Path(client.app.state.upload_dir) / Path(urlparse(photo["url"]).path).name
    assert file_path.exists()

    response = client.delete(f"/spots/{created['id']}/photos/{photo['id']}")
    assert response.status_code == 200
    assert not file_path.exists()
