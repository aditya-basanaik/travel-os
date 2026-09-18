# Travel OS AI Handoff

> Use this as the cold-start guide. Preserve the existing architecture and data model.

## What exists

Travel OS is a FastAPI/MongoDB backend with React web and Flutter mobile clients. The completed vertical slice includes hardened auth, profiles, AI planning/refinement with local fallback, itinerary editing and day management, global favorites, static/demo attractions behind a provider abstraction, expenses, sharing, restore, weather, and the FAQ help assistant. The current verified test counts are 40 backend, 10 frontend, and 7 Flutter tests.

Hotels, restaurants, and attractions are not live third-party inventory. Treat all generated names, prices, ratings, and static demo records as unverified. Google Maps is frozen/postponed: preserve its placeholder/native foundation and external links, and do not enable new Maps behavior without a dedicated milestone.

## Architecture decisions

- Web auth is cookie-only at the client boundary: Axios sends credentials, the backend sets HttpOnly access/refresh cookies, and the web client retries one protected 401 through refresh.
- Mobile auth is Bearer-token based: Flutter stores access/refresh tokens in secure storage and the Dio client refreshes them when needed. Keep this separate from web cookie behavior.
- Auth and attractions use provider abstractions. Add future providers behind `backend/auth_providers.py` and `backend/attraction_providers.py`; do not put provider-specific logic throughout routes or clients.
- `backend/server.py` remains the single backend module and itineraries remain embedded in `trips` documents. A schema split or Mongo migration needs an explicit data plan.
- `backend/knowledge_base.json` is a versioned, controlled FAQ corpus. The RAG/help path must not be used as live availability or place lookup.

## Important locations

- `backend/server.py`: routes, models, auth, planning, itinerary day operations, favorites, attractions, and Mongo access.
- `backend/auth_providers.py`, `backend/attraction_providers.py`: provider extension points.
- `frontend/src/lib/api.js`, `frontend/src/context/AuthContext.jsx`: web API and session behavior.
- `mobile/lib/core/network/api_client.dart`, `mobile/lib/core/routing/app_router.dart`: mobile API/token and navigation behavior.
- `mobile/lib/features/trips/data/trips_repository.dart`: mobile trip/day operations.
- `backend/test_server.py`: backend regression suite.
- `frontend/src/pages/AuthPage.test.jsx`, `frontend/src/pages/ComponentPages.test.jsx`, `frontend/src/components/trip/ItineraryTab.test.jsx`: frontend tests.

## Manual data operations

The server does not run these automatically. From `backend/`, with `.env` configured and MongoDB reachable:

```powershell
python migrate_day_numbers.py --dry-run
python migrate_day_numbers.py
python seed_attractions.py
```

The first script normalizes legacy string itinerary day numbers; inspect the dry run before writing. The second seeds static demo attractions. `seed_attractions.py --replace` replaces that demo collection.

## Run the project

Create `backend/.env` from [backend/.env.example](backend/.env.example). Keep secrets there; do not copy secret values into source or docs.

```powershell
# terminal 1
cd backend
python -m pip install -r requirements.txt
python -m uvicorn server:app --host 0.0.0.0 --port 8001

# terminal 2
cd frontend
npm install
npm start

# terminal 3
cd mobile
flutter pub get
flutter run --dart-define=TRAVEL_OS_API_URL=http://10.0.2.2:8001
```

For a physical device, replace the mobile API URL with a reachable host address. Relevant optional defines are `GOOGLE_SERVER_CLIENT_ID` and `TRAVEL_OS_WEB_URL`; `MAPS_API_KEY` belongs only to the postponed Maps foundation.

## Run every test suite

```powershell
cd backend
python -m unittest discover -s . -p "test_*.py" -v

cd ..\frontend
npm test -- --watchAll=false --runInBand

cd ..\mobile
flutter analyze
flutter test
```

Expected current results: 40 backend tests, 10 frontend tests, and 7 Flutter tests. Flutter analysis has no errors but retains these 10 diagnostics for review:

- `expenses_screen.dart:216`: `BuildContext` used across an async gap; fixing requires checking the intended post-sync UI behavior.
- `trip_detail_screen.dart:40,43`: unused `_mapsApiKey` and `_mapController`; these belong to the intentionally frozen Maps foundation.
- `trip_detail_screen.dart:553,575`: unreferenced `_addDay` and `_removeDay`; removing them could erase planned day-management UI behavior, while wiring them is a feature change.
- `trip_detail_screen.dart:568,608,1306,1308,1413`: brace-style infos in the same frozen trip-detail file; defer with the Maps/day-management review.

## Next milestones, in order

1. **Dedicated Maps milestone:** decide provider configuration and implement trusted place search, coordinates, routes, directions, nearby search, and client behavior as one reviewed scope.
2. **Real travel providers:** integrate live hotel, restaurant, and attraction data with availability/pricing freshness, attribution, and failure handling.
3. **Real phone OTP and Apple auth:** implement provider verification, backend routes, secure account linking, and parity across web and mobile.

Do not add admin work, split the itinerary schema, replace the auth contract, commit `.env` values, or treat AI-generated travel data as verified without a separate review.