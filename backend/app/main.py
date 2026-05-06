from __future__ import annotations

import logging
import math
import time

from fastapi import Depends, FastAPI, File, HTTPException, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session, selectinload

from .database import Base, engine, get_db
from .models import SkateSpot, SpotPhoto
from .schemas import SkateSpotCreate, SkateSpotRead, SkateSpotUpdate
from .settings import settings
from .storage import StorageAdapter, build_storage_adapter


logger = logging.getLogger("flatground.backend")

app = FastAPI(title=settings.app_name, version=settings.app_version)
settings.upload_dir.mkdir(parents=True, exist_ok=True)
app.state.upload_dir = settings.upload_dir
app.state.storage_adapter = build_storage_adapter()
app.state.rate_buckets: dict[str, list[float]] = {}
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

Base.metadata.create_all(bind=engine)
with engine.begin() as conn:
    columns = {col["name"] for col in inspect(conn).get_columns("skate_spots")}
    if "difficulty" not in columns:
        conn.execute(text("ALTER TABLE skate_spots ADD COLUMN difficulty VARCHAR(32) DEFAULT 'beginner'"))
    conn.execute(text("UPDATE skate_spots SET difficulty='beginner' WHERE difficulty IS NULL OR difficulty=''"))


def _get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _enforce_rate_limit(request: Request, *, key: str, limit: int) -> None:
    ip = _get_client_ip(request)
    bucket_key = f"{key}:{ip}"
    now = time.time()
    window_start = now - 60
    history = app.state.rate_buckets.get(bucket_key, [])
    history = [ts for ts in history if ts >= window_start]
    if len(history) >= limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests, please retry later",
        )
    history.append(now)
    app.state.rate_buckets[bucket_key] = history


def _guard_text(content: str | None, *, field_name: str) -> None:
    if not content:
        return
    lowered = content.lower()
    for bad_word in settings.forbidden_words:
        if bad_word and bad_word in lowered:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Blocked content in {field_name}",
            )


def _normalize_spot_name(name: str) -> str:
    cleaned = " ".join(name.strip().split())
    return " ".join(part.capitalize() for part in cleaned.split(" "))


def _serialize_spot(spot: SkateSpot) -> SkateSpotRead:
    return SkateSpotRead(
        id=spot.id,
        name=spot.name,
        type=spot.type,
        address=spot.address,
        latitude=spot.latitude,
        longitude=spot.longitude,
        description=spot.description,
        difficulty=(spot.difficulty or "beginner"),
        created_at=spot.created_at,
        photo_urls=[photo.url for photo in spot.photos],
        photos=spot.photos,
    )


def _distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance using haversine formula."""
    earth_radius_m = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return earth_radius_m * c


def _is_supported_image_upload(file: UploadFile) -> bool:
    content_type = (file.content_type or "").lower()
    if content_type.startswith("image/"):
        return True
    # Some mobile clients send generic multipart mime types.
    file_name = (file.filename or "").lower()
    allowed_extensions = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic")
    return file_name.endswith(allowed_extensions)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {
        "status": "ok",
        "environment": settings.environment,
        "storage": settings.storage_provider,
    }


@app.get("/spots", response_model=list[SkateSpotRead])
def list_spots(db: Session = Depends(get_db)) -> list[SkateSpotRead]:
    spots = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .order_by(SkateSpot.created_at.desc())
        .all()
    )
    return [_serialize_spot(spot) for spot in spots]


@app.get("/spots/{spot_id}", response_model=SkateSpotRead)
def get_spot(spot_id: int, db: Session = Depends(get_db)) -> SkateSpotRead:
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    if spot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Spot not found")
    return _serialize_spot(spot)


@app.post("/spots", response_model=SkateSpotRead, status_code=status.HTTP_201_CREATED)
def create_spot(
    payload: SkateSpotCreate,
    request: Request,
    db: Session = Depends(get_db),
) -> SkateSpotRead:
    _enforce_rate_limit(
        request,
        key="create_spot",
        limit=settings.create_spot_limit_per_minute,
    )
    _guard_text(payload.name, field_name="name")
    _guard_text(payload.type, field_name="type")
    _guard_text(payload.description, field_name="description")

    normalized_name = _normalize_spot_name(payload.name)
    existing_same_name = (
        db.query(SkateSpot)
        .filter(SkateSpot.name.ilike(normalized_name))
        .first()
    )
    if existing_same_name is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A spot with this name already exists",
        )

    all_spots = db.query(SkateSpot).all()
    for existing in all_spots:
        distance = _distance_meters(
            payload.latitude,
            payload.longitude,
            existing.latitude,
            existing.longitude,
        )
        if distance < settings.min_spot_distance_meters:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Spot too close to an existing spot ({distance:.1f} m)",
            )

    spot_payload = payload.model_dump()
    spot_payload["name"] = normalized_name
    spot = SkateSpot(**spot_payload)
    db.add(spot)
    db.commit()
    db.refresh(spot)
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot.id)
        .first()
    )
    return _serialize_spot(spot)


@app.post("/spots/{spot_id}/photos", response_model=SkateSpotRead)
async def upload_spot_photos(
    spot_id: int,
    request: Request,
    files: list[UploadFile] = File(...),
    db: Session = Depends(get_db),
) -> SkateSpotRead:
    _enforce_rate_limit(
        request,
        key="upload_photo",
        limit=settings.upload_photos_limit_per_minute,
    )
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    if spot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Spot not found")

    if not files:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No files uploaded")

    storage: StorageAdapter = app.state.storage_adapter
    max_size_bytes = settings.max_upload_mb * 1024 * 1024

    for file in files:
        if not _is_supported_image_upload(file):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Unsupported file type"
                    f" filename={file.filename!r} content_type={file.content_type!r}"
                ),
            )
        file.file.seek(0, 2)
        file_size = file.file.tell()
        file.file.seek(0)
        if file_size > max_size_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File too large: {file.filename}",
            )
        stored_file_name, public_url = await storage.save(file)

        photo = SpotPhoto(
            spot_id=spot.id,
            file_name=stored_file_name,
            url=public_url,
        )
        db.add(photo)

    db.commit()
    db.refresh(spot)
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot.id)
        .first()
    )
    return _serialize_spot(spot)


@app.delete("/spots/{spot_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_spot(spot_id: int, db: Session = Depends(get_db)) -> None:
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    if spot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Spot not found")
    storage: StorageAdapter = app.state.storage_adapter
    for photo in spot.photos:
        try:
            await storage.delete(photo.url)
        except Exception:  # pragma: no cover - best effort cleanup
            logger.warning("Storage cleanup failed for deleted spot photo url=%s", photo.url)
    db.delete(spot)
    db.commit()
    return None


@app.delete("/spots/{spot_id}/photos/{photo_id}", response_model=SkateSpotRead)
async def delete_spot_photo(spot_id: int, photo_id: int, db: Session = Depends(get_db)) -> SkateSpotRead:
    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    if spot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Spot not found")
    photo = db.query(SpotPhoto).filter(SpotPhoto.id == photo_id, SpotPhoto.spot_id == spot_id).first()
    if photo is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo not found")
    storage: StorageAdapter = app.state.storage_adapter
    try:
        await storage.delete(photo.url)
    except Exception:  # pragma: no cover - best effort cleanup
        logger.warning("Storage cleanup failed for deleted photo url=%s", photo.url)
    db.delete(photo)
    db.commit()
    refreshed = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    return _serialize_spot(refreshed)


@app.patch("/spots/{spot_id}", response_model=SkateSpotRead)
def update_spot(
    spot_id: int,
    payload: SkateSpotUpdate,
    db: Session = Depends(get_db),
) -> SkateSpotRead:
    _guard_text(payload.name, field_name="name")
    _guard_text(payload.type, field_name="type")
    _guard_text(payload.description, field_name="description")

    spot = (
        db.query(SkateSpot)
        .options(selectinload(SkateSpot.photos))
        .filter(SkateSpot.id == spot_id)
        .first()
    )
    if spot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Spot not found")

    normalized_name = _normalize_spot_name(payload.name)
    existing_same_name = (
        db.query(SkateSpot)
        .filter(SkateSpot.id != spot_id)
        .filter(SkateSpot.name.ilike(normalized_name))
        .first()
    )
    if existing_same_name is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A spot with this name already exists",
        )

    all_spots = db.query(SkateSpot).filter(SkateSpot.id != spot_id).all()
    for existing in all_spots:
        distance = _distance_meters(
            payload.latitude,
            payload.longitude,
            existing.latitude,
            existing.longitude,
        )
        if distance < settings.min_spot_distance_meters:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Spot too close to an existing spot ({distance:.1f} m)",
            )

    spot.name = normalized_name
    spot.type = payload.type.strip()
    spot.address = payload.address.strip()
    spot.latitude = payload.latitude
    spot.longitude = payload.longitude
    spot.description = payload.description
    spot.difficulty = payload.difficulty
    db.commit()
    db.refresh(spot)
    return _serialize_spot(spot)


@app.middleware("http")
async def request_log_middleware(request: Request, call_next):
    started = time.time()
    response = await call_next(request)
    elapsed_ms = int((time.time() - started) * 1000)
    logger.info(
        "%s %s -> %s (%sms)",
        request.method,
        request.url.path,
        response.status_code,
        elapsed_ms,
    )
    return response
