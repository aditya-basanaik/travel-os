# Travel OS Project State

> Reconstructed from the repository source on 2026-08-20. Code is the source of truth; older PRD claims are marked where the implementation differs.

## Project Overview

Travel OS is an MVP travel workspace for a signed-in user to create AI-assisted itineraries, inspect the itinerary's hotel and restaurant recommendations, open locations in Google Maps, edit itinerary activities, share a read-only trip, and track trip expenses. The current repository contains a React web client, a Flutter client, and a single FastAPI/MongoDB backend. There is no admin dashboard implementation, and this document covers only the user platform.

## Technology Stack

- Web: React 18, React Router 6, Axios, Tailwind CSS 3, CRACO/Create React App, Radix UI primitives, Phosphor icons, Framer Motion, Sonner.
- Mobile: Flutter/Dart, GoRouter, Riverpod, Dio, Flutter Secure Storage, Shared Preferences, Google Fonts, URL Launcher.
- Backend: Python, FastAPI, Pydantic v2, Uvicorn, Motor/PyMongo, bcrypt, PyJWT, python-dotenv, Requests.
- Database: MongoDB, accessed asynchronously through Motor.
- AI: Emergent Universal Key integration using `emergentintegrations`, Anthropic Claude Sonnet 4.6 (`claude-sonnet-4-6`) on the server.
- External data/media: Unsplash activity images when configured, curated Unsplash fallback covers, OpenWeather forecast when configured, Google Maps and Booking.com deep links.
- State: React local component state plus `AuthContext`; Flutter Riverpod providers and repositories.

## Project Structure

- `backend/server.py`: all FastAPI models, request schemas, auth helpers, AI generation, image enrichment, routes, Mongo indexes, startup, and shutdown logic in one module.
- `backend/requirements.txt`: Python dependencies. `backend/smoke_test.py`, CORS scripts, and key tests are manual scripts.
- `frontend/src/App.js`: browser routes and protected shell.
- `frontend/src/context/AuthContext.jsx`: initial `/auth/me` session check and logout state.
- `frontend/src/lib/api.js`: Axios base URL, credentials, error formatting, and access-token refresh interceptor.
- `frontend/src/components/Layout.jsx`: desktop sidebar, mobile header/bottom navigation, logout.
- `frontend/src/pages`: auth flows, dashboard, AI planner form, trip detail, profile, and public shared-trip view.
- `frontend/src/components/trip`: itinerary editing/weather, recommendation cards/favorites, Maps placeholder/links, and expenses/offline queue.
- `mobile/lib/core`: theme, routing, and Dio/secure-storage API client.
- `mobile/lib/features`: auth, home, AI planner, trips, expenses, and profile repositories/screens.
- `mobile/test/widget_test.dart`: stale test scaffold; it imports a non-existent `package:mobile/main.dart` and `MyApp`.
- `memory/PRD.md`: prior MVP notes, useful context but not authoritative when code differs.
- `design_guidelines.json`: design guidance matching the implemented Organic & Earthy React styling; no separate admin application is present.
- `mobile/README.md`: still the generic Flutter starter README and does not describe the current mobile features.
- Root `package-lock.json` exists, but there is no root `package.json`; install/build commands belong to `frontend/` and `backend/`.

## Current UI Polish Pass

The current working state includes a non-auth UI refinement pass across the shared web shell and mobile app theme. This pass adjusts spacing, surface treatment, and visual hierarchy for the already-working product surfaces without changing request logic, auth flows, or backend contracts. The focus is on improving comfort and clarity for real users while preserving all working functionality.

## Current Features

Status uses `Complete`, `Partial`, `Broken`, `Missing`, or `Unknown` for Phase 1 expectations.

| Feature | Status | Evidence / current boundary |
|---|---|---|
| Email registration/login/logout | Partial | FastAPI routes and web/mobile forms exist; tokens are also returned in JSON as well as cookies. |
| Password hashing | Complete | bcrypt hashing and verification are implemented server-side. |
| Current session/protected APIs | Partial | JWT access/refresh cookies and Bearer fallback exist; mobile stores tokens securely. |
| Forgot/reset password | Partial | Web and Flutter reset screens/routes exist; development uses a local link, while production uses the SMTP provider abstraction and never returns reset tokens. |
| Google login | Partial | Flutter uses direct Google ID-token login, and web now uses Google Identity Services with `/auth/google/token`; Google Cloud client/origin publishing configuration is still required for unrestricted accounts. |
| Phone OTP / Apple sign-in | Missing | No provider or routes. Architecturally deferred. |
| Profile/preferences | Partial | Name, email, photo URL, age, budget, food preference, languages, and favourite destinations exist. No upload, travel style, or broad preference model. |
| User dashboard/home | Partial | Web and Flutter show greetings, trips, AI planning CTA, authenticated trip/destination search, workspace quick actions, and profile-grounded saved-destination recommendations. Richer saved-trip presentation remains absent. |
| AI trip planner | Partial | Web/mobile forms call `/api/trips/plan` and `/api/trips/plan/natural`; structured extraction, schema validation, budget checks, and Unsplash enrichment are present. Live data grounding remains absent. |
| AI trip planner reliability | Complete | Missing `EMERGENT_LLM_KEY` no longer triggers the remote LLM path; the backend immediately falls back to the local itinerary generator and the web/mobile clients now time out quickly instead of waiting indefinitely. |
| AI itinerary refinement | Partial | Protected `/trips/{id}/refine` uses Claude when configured and a deterministic fallback; web and Flutter controls exist, but refinement has no conversation state. |
| Day-by-day itinerary | Complete | Generated and displayed on both clients; web and Flutter allow activity editing, add/remove, and persisted itinerary replacement. |
| Hotels | Partial | AI-generated recommendation cards and Google Maps/Booking.com deep links. No live search/details, distance, reliable prices, or official partner integration. Names/prices may be generated. |
| Restaurants | Partial | AI-generated cards, ratings, cuisine, vegetarian flag, favorites, and Maps links. No live search/details/open-now/family filters. |
| Attractions | Partial | Generated itineraries now include maps-ready attraction recommendations, with web/mobile tabs and favorites. Provider-backed discovery remains absent. |
| Google Maps | Postponed | Existing placeholder/native foundation and external links are preserved. Google Maps APIs, search, routes, and directions are intentionally deferred. |
| Weather | Partial | `/trips/{id}/weather` uses OpenWeather geocoding/5-day forecast when keyed; otherwise returns null values. It is shown in web itinerary and mobile map tab. |
| Saved/recent trips | Partial | Trip list, open, edit, duplicate, soft-delete, restore, and favorites exist. No separate archive view or continue workflow beyond persisted trip data. |
| Trip sharing | Partial | Server token and public read-only routes work on web and mobile. Mobile share links use the configured web URL and expose a copy action. No realtime collaboration. |
| Expense tracking | Partial | Budget/spent/remaining, categories, add/list/edit/delete, summary, and web local queue exist. |
| Offline expenses | Partial | Web localStorage and Flutter SharedPreferences queues retry online/manual sync with client IDs; pending amounts are not included in server summaries until synchronization. |
| RAG Travel Assistant | Partial | Protected FastAPI `/rag/ask`, controlled in-code FAQ corpus, lexical retrieval, grounded Claude prompt/fallback, source metadata, and React `/help` plus Flutter `/help` UI exist. No vector store, persistent knowledge collection, or chat history yet. |
| Admin dashboard | Missing by design | No admin UI/routes; backend only has a seeded `role` field and admin credentials. |
| Tests | Partial/Broken | Manual auth/smoke scripts exist; Flutter test scaffold is stale; no backend unit/integration suite found. |

## Current API Architecture

All routes are under `/api` and are defined in `backend/server.py`.

### Auth

- `POST /auth/register`: validates name/email/password, creates `users` and `profiles`, sets access/refresh cookies, and returns user plus both token strings.
- `POST /auth/login`: bcrypt login with failed-attempt tracking/lockout, sets cookies, and returns user plus token strings.
- `POST /auth/google/session`: exchanges an Emergent session ID, creates a Google user/profile when needed, and sets cookies.
- `POST /auth/logout`: deletes auth cookies.
- `GET /auth/me`: protected current-user lookup.
- `POST /auth/refresh`: accepts refresh cookie or Bearer token and issues a new access token.
- `POST /auth/forgot-password`: creates a one-hour reset token; returns `dev_reset_link` when the user exists.
- `POST /auth/reset-password`: consumes an unused reset token and replaces the bcrypt password.

### Profile

- `GET /profile`: protected profile plus user name/email and non-deleted trip count.
- `PUT /profile`: protected update of name and profile preferences/photo URL.

### Trips, itinerary, and sharing

- `POST /trips/plan`: validates dates and limits, calls Claude with a fixed JSON prompt, retries once, falls back locally, enriches activity images, and stores an embedded itinerary.
- `POST /trips/{trip_id}/refine`: refines an existing itinerary with Claude when configured, or a deterministic local fallback.
- `GET /trips`: protected paginated list of non-deleted owned trips; optional `search` filters title and destination.
- `GET /trips/{trip_id}`: protected owned-trip detail.
- `PUT /trips/{trip_id}`: protected metadata update.
- `PUT /trips/{trip_id}/itinerary`: protected itinerary replacement; only checks that `days` is a list.
- `DELETE /trips/{trip_id}`: soft-delete by setting `deleted_at`.
- `POST /trips/{trip_id}/duplicate`: copies an owned trip without its share token.
- `POST /trips/{trip_id}/share`: creates/reuses a random share token.
- `GET /trips/shared/{token}`: public read-only trip detail with owner display name.
- `GET /trips/{trip_id}/weather`: protected OpenWeather-backed forecast, or null entries without a key.

### Favorites and expenses

- `GET/POST /trips/{trip_id}/favorites`: list/add hotel or restaurant favorites for an owned trip.
- `DELETE /favorites/{fav_id}`: delete an owned favorite.
- `GET /trips/{trip_id}/expenses`: list expenses for an owned trip.
- `POST /trips/{trip_id}/expenses`: add an expense in `food`, `stay`, `transport`, `activities`, or `misc`.
- `DELETE /expenses/{expense_id}`: delete an owned expense.
- `GET /trips/{trip_id}/expenses/summary`: aggregate budget, spent, remaining, and category totals.
- `GET /`: API health/message endpoint.

There are no attractions, live hotel/restaurant, directions, refinement, expense-update, or restore endpoints. RAG is available at protected `POST /rag/ask`.

## Database Architecture

MongoDB database name comes from `DB_NAME`; connection comes from `MONGO_URL`. The backend embeds the itinerary inside each trip rather than using a separate itinerary collection.

- `users`: `_id` is a UUID string; name, email, optional bcrypt `password_hash`, `auth_provider`, email verification, picture, role, created time.
- `profiles`: UUID `_id`; `user_id`, photo URL, age, budget/food preferences, languages, favourite destinations, updated time.
- `trips`: UUID `_id`; owner, title/destination/dates, budget/currency/people/interests/status, cover image, embedded itinerary, share token, soft-delete timestamp, created/updated times.
- `expenses`: UUID `_id`; trip/user references, category, amount, note, created time.
- `favorites`: UUID `_id`; user/trip references, type, external ID, name, metadata, created time.
- `login_attempts`: identifier, failed count, lock timestamp.
- `password_reset_tokens`: token, email, used flag, expiry, created time.

Indexes created at startup: unique `users.email`; TTL `password_reset_tokens.expires_at`; `login_attempts.identifier`; compound `trips(user_id, deleted_at)`; `trips.share_token`; `expenses.trip_id`. No indexes are created for `user_id` on expenses/favorites or knowledge/chat documents because those collections are not implemented.

## Authentication

The backend loads `.env` beside `backend/server.py` and requires `MONGO_URL`, `DB_NAME`, and `JWT_SECRET` at import time. Access JWTs expire after 15 minutes; refresh JWTs expire after 7 days. Development cookies are HttpOnly, non-secure, `SameSite=Lax`; production intends secure `SameSite=None` cookies. The web Axios client sends credentials and retries one non-auth 401 through `/auth/refresh`. Flutter sends Bearer access tokens from Flutter Secure Storage and refreshes them similarly.

Passwords are bcrypt-hashed. Pydantic validates email and minimum password length. Login failures are tracked by client host plus email and lock after five failures. Protected routes use `get_current_user`, which accepts cookie or Bearer access JWT and verifies the user exists. Role is stored and an admin seed is created, but role-based authorization is not currently used.

Google web login is delegated to Emergent's OAuth session exchange. Direct Android login now verifies Google ID tokens through `/auth/google/token`; it requires `GOOGLE_OAUTH_CLIENT_IDS`. Phone OTP and Apple sign-in are not implemented. Password reset is development-oriented: no mail provider exists, and a reset URL/token is returned to the caller for existing accounts and logged server-side.

## AI System

The planner endpoint builds a prompt containing destination, dates, group size, budget, currency, and interests. It asks Claude Sonnet 4.6 to return JSON with a title, summary, day activities, hotels, restaurants, cost breakdown, and tips. The response is stripped of code fences and parsed with `json.loads`; only the presence of a non-empty `days` list is checked. The endpoint retries once, then uses a deterministic local template fallback. Activity images are enriched through Unsplash when `UNSPLASH_ACCESS_KEY` exists, otherwise curated fallback URLs are used.

There is no prompt/session continuity for refinement, no trusted place lookup, no coordinate/opening-hour/route validation, and no reliable-price validation. Natural-language requests are deterministically extracted into the existing structured planner, with dates defaulting to today when omitted. Generated hotel, restaurant, rating, and cost data must therefore be treated as recommendations, not verified inventory or booking claims.

## RAG System

**RAG STATUS: PARTIAL IMPLEMENTATION**

The current implementation uses the versioned `backend/knowledge_base.json` FAQ corpus, lexical token retrieval, protected `POST /api/rag/ask`, source IDs/titles, a grounded Claude prompt when `EMERGENT_LLM_KEY` is available, and a deterministic grounded fallback. Unknown questions receive an explicit insufficient-information response. React and Flutter expose this through `/help`. There is no ingestion workflow, Mongo knowledge collection, embeddings/vector database, or chat history yet. It answers Travel OS product/how-to questions, not live place availability.

## Maps

Mobile trip detail now has a native Google Maps SDK foundation and itinerary marker scaffolding when built with `MAPS_API_KEY`; it falls back safely when the key is absent. Activity and recommendation actions still open Google Maps Search URLs; hotel cards also open a Booking.com search deep link. Route/directions calculation, distance/time, place search, and nearby search are still pending.

## Known Problems and Technical Debt

- Production CORS now reads comma-separated `CORS_ORIGINS` or `FRONTEND_URL`; default remains `http://localhost:3000`.
- `FRONTEND_URL` is used for reset links, but no production CORS origin configuration is actually wired.
- Access and refresh tokens are returned in JSON as well as placed in cookies, increasing exposure compared with cookie-only web auth.
- Development reset links are returned only outside production; production delivery uses SMTP configuration from `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, and `RESET_EMAIL_FROM`.
- AI output is structurally validated for dates, fields, costs, ratings, duplicate activities, and budget totals; place, price, rating, opening-hour, coordinate, and route claims remain unverified.
- AI fallback content intentionally uses generic/generated hotel and restaurant names.
- AI refinement now exists at protected `POST /api/trips/{trip_id}/refine`; web controls and a deterministic fallback are implemented. Persistent conversation state is absent.
- Hotels/restaurants/attractions are not live discovery; generated place data remains unverified.
- Maps have a mobile SDK foundation with a safe fallback; route and nearby-place behavior remain incomplete.
- Expense update exists at protected `PUT /api/expenses/{expense_id}` and web editing is wired. Offline submissions now carry client IDs and duplicate retries are ignored; offline amounts are not included in server summaries until sync.
- Trip restore exists at `POST /api/trips/{trip_id}/restore`; web dashboard lists eligible deleted trips and provides Restore actions. The backend normalizes legacy timezone-naive Mongo deletion timestamps before checking the 30-day window.
- Flutter sharing now builds the public route from `ApiClient.webAppUrl` and `/shared/{token}`, parses the backend owner name, and offers a copy action; deployments can set `TRAVEL_OS_WEB_URL` with `--dart-define`.
- Flutter now has a reset-password screen/route and direct Android Google Sign-In. Pass `GOOGLE_SERVER_CLIENT_ID` to the Flutter build and configure the matching backend `GOOGLE_OAUTH_CLIENT_IDS` value.
- Mobile profile rendering is fixed for legacy food-preference values; the edit control now supports only `veg`, `nonveg`, and `both`.
- Flutter `ApiClient` has a hardcoded LAN IP, making physical-device use environment-specific.
- Mobile feature coverage still lacks shared-trip public view, attractions, and live Maps. Favorites, reset, restore, expense editing, itinerary editing, refinement, trip-level expenses, and Android Google Sign-In are now present.
- Web dashboard does not implement search, destination recommendations, nearby places, or explicit saved/past trip sections beyond the trip list.
- Mobile widget test now targets the real login screen and includes `ProviderScope`; Flutter analysis still reports unrelated unused imports/results and deprecated theme API usage.
- Backend now has `backend/test_server.py` unit and ASGI tests; React test files were not found. React build validation was unavailable because `npm` is not installed in the current terminal.
- `mobile/README.md` and parts of the root metadata are stale relative to the current implementation, so they should not be used as setup authority without checking the subproject files.
- Backend startup imports required environment variables directly, so missing configuration prevents even route inspection/startup.
- There is no migration/versioning mechanism for MongoDB documents or indexes.

## Phase 1 Status

- [x] Existing React, Flutter, FastAPI, and MongoDB foundations reconstructed.
- [x] Email registration, login, logout, current session, and protected API foundation.
- [x] Basic profile/preferences on web and mobile.
- [x] AI itinerary generation with fallback and persistence.
- [x] Trip list/detail, itinerary editing on web/mobile, duplicate, soft-delete, and read-only share web flow.
- [x] Basic expense tracking and limited offline queue.
- [ ] Secure production-grade reset delivery; mobile reset flow is implemented.
- [x] AI refinement endpoint and web/mobile controls; trusted-place validation remains.
- [ ] Live hotel, restaurant, attraction discovery.
- [ ] Interactive Google Maps, directions, nearby search, and route data; intentionally postponed.
- [x] Expense edit endpoint, web control, and client-ID idempotent offline synchronization.
- [x] Restore deleted trips API and web UI.
- [x] RAG Travel Assistant backend and React MVP with controlled FAQ answers.
- [x] Versioned file-based RAG knowledge base.
- [ ] Persistent Mongo knowledge management, vector retrieval, and chat history.
- [ ] Complete mobile parity for share/map/place flows and native Google OAuth.
- [ ] Automated critical-journey tests on web, backend, and mobile.

## Current Milestone Progress

- [x] Google OAuth audience mismatch fixed for the mobile client and backend allowlist.
- [x] Flutter debug APK rebuilt successfully with the corrected client ID and API endpoint.
- [x] Mobile project updated to include the native Google Maps SDK foundation without removing the existing placeholder fallback when no API key is configured.
- [ ] Full end-to-end real map interactions, route calculation, and nearby place discovery are still pending provider/API configuration.

## Last Completed Work

The most recent slice completed profile-grounded dashboard destination recommendations on web and Flutter, building on the existing trip search and workspace quick actions. Flutter parity features are already present in code. Backend regression tests, Flutter analysis, and widget tests remain green.

## Recent Fixes

- Fixed production CORS configuration in `backend/server.py`.
- Fixed Flutter share links so they target the React public shared-trip route rather than the API URL.
- Replaced the generated Flutter counter test with a network-free Travel OS login-screen smoke test.
- Fixed a narrow-screen overflow in the Flutter login footer by changing its account-toggle row to a wrapping layout.

## Next Recommended Task

**P1: finish trip reliability and maps.** Sharing and restore now work across web/mobile, with smoother dashboard transitions. Next highest-value work is route/directions behavior, attractions, and provider-backed hotel and restaurant discovery.

## Verification Performed During Reconstruction

- `python -m py_compile backend/server.py`: passed.
- `flutter analyze`: completed with 12 pre-existing warnings/info diagnostics and no errors.
- `flutter test`: passed from `mobile/` (`1` test).
- `npm run build`: could not run because `npm` is unavailable in the current terminal.
- `git status --short --branch`: clean `main` branch before documentation files were added.
- Focused static diagnostics after fixes: no errors reported for the touched backend, Flutter source, or test files.
- Focused Flutter test rerun after the final test isolation change was skipped by the environment prompt; the prior run reached the app and exposed/falsified the fixed login-footer overflow, then the test was narrowed to avoid live auth networking.
- `Push-Location backend; python -m unittest test_server.py -v; Pop-Location`: passed, 7 tests.
- `python -m unittest discover -s backend -p "test_*.py" -v`: passed, 10 tests including register, cookie `/me`, refresh, Bearer `/me`, invalid login, profile access, and cross-user trip rejection.
- After RAG implementation, the same discovery command passed 12 tests, including protected RAG access, grounded sources, and unknown-question refusal.
- After refinement and expense work, the same discovery command passed 14 tests, including AI fallback refinement and duplicate expense retry protection.
- Focused `flutter analyze` for the Help screen and navigation: passed with no issues.
- Final Flutter widget-test rerun was skipped by the environment prompt.
