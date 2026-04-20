from __future__ import annotations

import uuid
from pathlib import Path
from typing import Protocol

import httpx
from fastapi import HTTPException, UploadFile, status

from .settings import settings


class StorageAdapter(Protocol):
    async def save(self, upload: UploadFile) -> tuple[str, str]:
        """Returns tuple[file_name, public_url]."""


class LocalStorageAdapter:
    def __init__(self, upload_dir: Path) -> None:
        self._upload_dir = upload_dir
        self._upload_dir.mkdir(parents=True, exist_ok=True)

    async def save(self, upload: UploadFile) -> tuple[str, str]:
        suffix = Path(upload.filename or "").suffix or ".jpg"
        file_key = f"{uuid.uuid4().hex}{suffix}"
        destination = self._upload_dir / file_key
        content = await upload.read()
        destination.write_bytes(content)
        return upload.filename or file_key, f"/uploads/{file_key}"


class SupabaseStorageAdapter:
    def __init__(self, *, base_url: str, service_key: str, bucket: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._service_key = service_key
        self._bucket = bucket

    async def save(self, upload: UploadFile) -> tuple[str, str]:
        suffix = Path(upload.filename or "").suffix or ".jpg"
        file_key = f"spots/{uuid.uuid4().hex}{suffix}"
        binary = await upload.read()

        upload_url = f"{self._base_url}/storage/v1/object/{self._bucket}/{file_key}"
        headers = {
            "apikey": self._service_key,
            "Authorization": f"Bearer {self._service_key}",
            "Content-Type": upload.content_type or "application/octet-stream",
            "x-upsert": "false",
        }
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(upload_url, headers=headers, content=binary)
        if response.status_code >= 300:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Photo upload to storage failed",
            )
        public_url = f"{self._base_url}/storage/v1/object/public/{self._bucket}/{file_key}"
        return upload.filename or file_key, public_url


def build_storage_adapter() -> StorageAdapter:
    if settings.storage_provider.lower() == "supabase":
        if not settings.supabase_url or not settings.supabase_service_key:
            raise RuntimeError("Supabase storage provider selected but credentials are missing")
        return SupabaseStorageAdapter(
            base_url=settings.supabase_url,
            service_key=settings.supabase_service_key,
            bucket=settings.supabase_bucket,
        )
    return LocalStorageAdapter(settings.upload_dir)
