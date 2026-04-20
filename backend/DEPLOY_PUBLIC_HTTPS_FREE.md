## Public HTTPS Deployment (Free): Render + Supabase

This guide makes the backend reachable outside home Wi-Fi over HTTPS, using free tiers.

### 1) Create Supabase free project

1. Create a Supabase project (free plan).
2. In `Project Settings -> Database`, copy the Postgres connection string.
3. In `Storage`, create a public bucket named `spot-photos`.
4. In `Project Settings -> API`, copy:
   - `Project URL` -> `SUPABASE_URL`
   - `service_role` key -> `SUPABASE_SERVICE_KEY`

### 2) Create/Update Render web service

1. Create a new Render **Web Service** from this repo.
2. Render should pick [`render.yaml`](../render.yaml) automatically.
3. Set environment variables in Render:
   - `ENVIRONMENT=production`
   - `DATABASE_URL=<Supabase Postgres URL>`
   - `STORAGE_PROVIDER=supabase`
   - `SUPABASE_URL=<project URL>`
   - `SUPABASE_SERVICE_KEY=<service_role key>`
   - `SUPABASE_BUCKET=spot-photos`
   - `CORS_ALLOWED_ORIGINS=https://flatground-map-backend.onrender.com`
4. Deploy.

Notes:
- The service is free-tier and may sleep when idle.
- TLS/HTTPS certificate is managed by Render automatically.

### 3) Verify secure public API

Use your public URL, e.g. `https://flatground-map-backend.onrender.com`.

Check health:

```bash
curl https://flatground-map-backend.onrender.com/health
```

Expected:
- `200 OK`
- JSON includes `"environment": "production"` and `"storage": "supabase"`

### 4) Verify from outside home network

From phone on mobile data (Wi-Fi off):
1. Open `https://flatground-map-backend.onrender.com/health` in browser.
2. Confirm response is reachable and valid JSON.

### 5) Point Flutter app to production backend

The app already supports prod endpoint in [`flatground_app/lib/services/skate_spot_api.dart`](../flatground_app/lib/services/skate_spot_api.dart).

Run/build with:

```bash
flutter run --dart-define APP_ENV=prod
```

Or force explicit backend URL:

```bash
flutter run --dart-define BACKEND_BASE_URL=https://flatground-map-backend.onrender.com
```

### 6) Security checklist

- Do not commit `.env` or service keys.
- Keep `CORS_ALLOWED_ORIGINS` explicit (no `*` in production).
- Keep rate limit and upload size defaults from [`backend/app/settings.py`](app/settings.py).
- Confirm photo URLs are HTTPS.

