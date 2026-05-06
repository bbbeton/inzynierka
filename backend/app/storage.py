from __future__ import annotations

import mimetypes
import uuid
from pathlib import Path
from typing import Protocol
from urllib.parse import urlparse

import httpx
from fastapi import HTTPException, UploadFile, status

from .settings import settings


class StorageAdapter(Protocol):
    async def save(self, upload: UploadFile) -> tuple[str, str]:
        """Returns tuple[file_name, public_url]."""

    async def delete(self, public_url: str) -> None:
        """Deletes file by its public URL. Should be best-effort for missing files."""


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

    async def delete(self, public_url: str) -> None:
        parsed_path = urlparse(public_url).path
        uploads_prefix = "/uploads/"
        if not parsed_path.startswith(uploads_prefix):
            return
        file_key = parsed_path[len(uploads_prefix) :]
        if not file_key:
            return
        target = self._upload_dir / file_key
        if target.exists():
            target.unlink()


class SupabaseStorageAdapter:
    def __init__(self, *, base_url: str, service_key: str, bucket: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._service_key = service_key
        self._bucket = bucket

    async def save(self, upload: UploadFile) -> tuple[str, str]:
        suffix = Path(upload.filename or "").suffix or ".jpg"
        file_key = f"spots/{uuid.uuid4().hex}{suffix}"
        binary = await upload.read()
        normalized_content_type = (upload.content_type or "").strip().lower()
        if (
            not normalized_content_type
            or normalized_content_type == "application/octet-stream"
        ):
            guessed, _ = mimetypes.guess_type(upload.filename or file_key)
            normalized_content_type = guessed or "image/jpeg"

        upload_url = f"{self._base_url}/storage/v1/object/{self._bucket}/{file_key}"
        headers = {
            "apikey": self._service_key,
            "Authorization": f"Bearer {self._service_key}",
            "Content-Type": normalized_content_type,
            "x-upsert": "false",
        }
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(upload_url, headers=headers, content=binary)
            # Some storage gateways expect PUT on this endpoint.
            if response.status_code in {404, 405}:
                response = await client.put(upload_url, headers=headers, content=binary)
        if response.status_code >= 300:
            upstream_body = response.text.strip()
            trimmed_body = upstream_body[:500] if upstream_body else "<empty>"
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=(
                    "Photo upload to storage failed "
                    f"(status={response.status_code}, bucket={self._bucket}): {trimmed_body}"
                ),
            )
        public_url = f"{self._base_url}/storage/v1/object/public/{self._bucket}/{file_key}"
        return upload.filename or file_key, public_url

    async def delete(self, public_url: str) -> None:
        parsed_path = urlparse(public_url).path
        prefix = f"/storage/v1/object/public/{self._bucket}/"
        if parsed_path.startswith(prefix):
            file_key = parsed_path[len(prefix) :]
        else:
            file_key = public_url.strip()
        if not file_key:
            return

        delete_url = f"{self._base_url}/storage/v1/object/{self._bucket}/{file_key}"
        headers = {
            "apikey": self._service_key,
            "Authorization": f"Bearer {self._service_key}",
        }
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.delete(delete_url, headers=headers)
        if response.status_code in {200, 204, 404}:
            return
        upstream_body = response.text.strip()
        trimmed_body = upstream_body[:500] if upstream_body else "<empty>"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=(
                "Photo delete from storage failed "
                f"(status={response.status_code}, bucket={self._bucket}): {trimmed_body}"
            ),
        )


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
