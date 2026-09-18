# Travel OS

Travel OS is a travel-planning MVP for creating AI-assisted itineraries, editing trips day by day, saving recommendations, tracking expenses, and sharing read-only trip links. It has a React web client, a Flutter mobile client, and a FastAPI/MongoDB backend.

## Current feature set

- Email registration, login, logout, refresh, protected sessions, password hashing, failed-login lockout, and password reset.
- Google ID-token authentication for web and Android, with provider-backed configuration.
- Profile preferences, AI itinerary generation and refinement, deterministic fallback planning, and natural-language trip requests.
- Itinerary activity editing plus add/remove day management, including legacy day-number normalization.
- Global favorites for hotels, restaurants, and attractions; attraction models and provider abstractions are implemented.
- Trip search, duplicate, soft-delete, restore, read-only sharing, weather when configured, expenses, and limited offline expense queues.
- Help assistant backed by the versioned FAQ knowledge base, with grounded fallback responses.

Hotels, restaurants, and attractions are not live inventory. Recommendations and prices are AI-generated or static demo data. External Maps links and the mobile Maps foundation remain available, but interactive Google Maps, routes, directions, and nearby search are intentionally frozen/postponed for this phase. Do not enable or extend Maps without a dedicated future milestone.

## Stack

- Backend: Python, FastAPI, Pydantic, Uvicorn, Motor/PyMongo, bcrypt, PyJWT, HTTPX tests.
- Web: React 18, React Router, Axios, CRACO/Create React App, Tailwind CSS, Radix UI, Framer Motion, Phosphor icons, Sonner.
- Mobile: Flutter/Dart, Riverpod, GoRouter, Dio, Flutter Secure Storage, Shared Preferences, Google Fonts, URL Launcher, and the frozen Google Maps foundation.
- Persistence: MongoDB, with itineraries embedded in `trips` documents.
- AI and enrichment: server-side Claude through Emergent Universal Key; optional Unsplash and OpenWeather integrations.

## Local development

Create `backend/.env` from [backend/.env.example](backend/.env.example), then provide MongoDB and the required development values there.

```powershell
cd backend
python -m pip install -r requirements.txt
python -m uvicorn server:app --host 0.0.0.0 --port 8001
```

The template documents required values such as `MONGO_URL`, `DB_NAME`, `JWT_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and `EMERGENT_LLM_KEY`, plus optional OAuth, CORS, image, weather, and SMTP settings. Keep secrets in `.env`; do not duplicate them in documentation or commit them.

### Web

```powershell
cd frontend
npm install
npm start
```

The web client uses `http://localhost:8001/api` by default. Set `REACT_APP_BACKEND_URL` when the backend is elsewhere. Google web login additionally uses `REACT_APP_GOOGLE_CLIENT_ID`.

### Mobile

```powershell
cd mobile
flutter pub get
flutter run --dart-define=TRAVEL_OS_API_URL=http://10.0.2.2:8001
```

For a physical device, use a reachable host address. Optional build defines include `GOOGLE_SERVER_CLIENT_ID`, `TRAVEL_OS_WEB_URL`, and the frozen `MAPS_API_KEY` foundation.

## Tests

```powershell
cd backend
python -m unittest discover -s . -p "test_*.py" -v

cd ..\frontend
npm test -- --watchAll=false --runInBand

cd ..\mobile
flutter analyze
flutter test
```

Current passing counts are 40 backend tests, 10 frontend tests, and 7 Flutter tests. Flutter analysis has 10 remaining diagnostics, all documented for manual review in the handoff; there are no analyzer errors.

## Project structure

- `backend/server.py`: FastAPI routes, models, auth, AI planning, favorites, attractions, itinerary operations, and persistence.
- `backend/auth_providers.py` and `backend/attraction_providers.py`: provider abstractions and integrations.
- `backend/seed_attractions.py`: manual demo-attraction seed script.
- `backend/migrate_day_numbers.py`: manual legacy itinerary day-number migration, with `--dry-run`.
- `backend/test_server.py`: backend unit and HTTP regression suite.
- `frontend/src/`: React routes, pages, shared shell, API client, and trip components.
- `frontend/src/pages/*.test.jsx` and `frontend/src/components/trip/ItineraryTab.test.jsx`: frontend tests.
- `mobile/lib/`: Flutter routing, theme, repositories, providers, and screens.
- `mobile/test/`: Flutter widget and phase-one regression tests.
- `memory/PRD.md`: historical product notes; implementation and these docs are authoritative.

See [PROJECT_STATE.md](PROJECT_STATE.md) for the current audit snapshot and [AI_HANDOFF.md](AI_HANDOFF.md) for continuation guidance.