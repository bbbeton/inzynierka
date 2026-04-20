from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class SkateSpot(Base):
    __tablename__ = "skate_spots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[str] = mapped_column(String(80), nullable=False)
    address: Mapped[str] = mapped_column(String(255), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[str] = mapped_column(String(32), nullable=False, default="beginner")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    photos: Mapped[list["SpotPhoto"]] = relationship(
        back_populates="spot",
        cascade="all, delete-orphan",
        order_by="SpotPhoto.id",
    )


class SpotPhoto(Base):
    __tablename__ = "spot_photos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    spot_id: Mapped[int] = mapped_column(ForeignKey("skate_spots.id"), nullable=False)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    url: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    spot: Mapped[SkateSpot] = relationship(back_populates="photos")
