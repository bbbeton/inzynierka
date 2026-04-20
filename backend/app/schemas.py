from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SpotPhotoRead(BaseModel):
    id: int
    file_name: str
    url: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SkateSpotBase(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: str = Field(min_length=1, max_length=80)
    address: str = Field(min_length=1, max_length=255)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    description: str | None = Field(default=None, max_length=2000)
    difficulty: Literal["beginner", "intermediate", "advanced"] = "beginner"


class SkateSpotCreate(SkateSpotBase):
    pass


class SkateSpotUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: str = Field(min_length=1, max_length=80)
    address: str = Field(min_length=1, max_length=255)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    description: str | None = Field(default=None, max_length=2000)
    difficulty: Literal["beginner", "intermediate", "advanced"] = "beginner"


class SkateSpotRead(SkateSpotBase):
    id: int
    created_at: datetime
    photo_urls: list[str]
    photos: list[SpotPhotoRead]

    model_config = ConfigDict(from_attributes=True)
