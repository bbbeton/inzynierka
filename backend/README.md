# FastAPI Backend

This backend provides the map data layer for `flatground_app`.

## Features

- `GET /health`
- `GET /spots`
- `GET /spots/{id}`
- `POST /spots`
- `POST /spots/{id}/photos`
- Static photo hosting from `/uploads/...`

## Local setup

```powershell
cd backend
python -m pip install -r requirements.txt
copy .env.example .env
python scripts/migrate.py
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Running tests

From the repository root:

```powershell
python -m pytest backend/tests
```

## Flutter integration

For Android emulator:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```

For a physical phone on the same Wi-Fi, replace the URL with your computer's LAN IP:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.10:8000
```

For production backend default switching:

```powershell
flutter run --dart-define=APP_ENV=prod --dart-define=PROD_BACKEND_BASE_URL=https://your-render-service.onrender.com
```

## Environment variables

- `DATABASE_URL`: SQLAlchemy DB URL (Supabase Postgres in production)
- `STORAGE_PROVIDER`: `local` or `supabase`
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_SERVICE_KEY`: service role key used by backend write operations
- `SUPABASE_BUCKET`: storage bucket name (default `spot-photos`)
- `CORS_ALLOWED_ORIGINS`: comma-separated origins or `*`
- `MAX_UPLOAD_MB`: upload payload limit per file
- `CREATE_SPOT_LIMIT_PER_MINUTE`: basic unauth write protection
- `UPLOAD_PHOTOS_LIMIT_PER_MINUTE`: basic unauth upload protection

## Public deployment (Render + Supabase free tier)

1. Create Supabase project and public bucket (`spot-photos`).
2. Copy Postgres connection string (`DATABASE_URL`) and API credentials.
3. Connect repo to Render and use the root `render.yaml`.
4. Set secret env vars on Render:
   - `DATABASE_URL`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
5. Verify:
   - `GET /health`
   - `GET /spots`
   - create spot + photo from mobile app.

## Storage and persistence

- SQLite database: `backend/data/app.db`
- Uploaded photos: `backend/uploads/`
- Supabase mode: photos are uploaded directly to Supabase Storage with public URLs.
