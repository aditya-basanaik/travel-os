# Travel OS AI Handoff

> Handoff reconstructed from source on 2026-08-20. This is an existing MVP. Preserve its architecture and data; do not rebuild it.

## Current Project State

Travel OS is a user-facing travel planning MVP with a React web app, Flutter app, FastAPI backend, and MongoDB. The implemented vertical slice is email/Google-session auth, profile preferences, AI itinerary creation, persisted trips, web itinerary editing, hotel/restaurant recommendation cards, weather, share links, and expense tracking with limited offline queues. Admin is intentionally not built.

## Current Technology Stack

- React 18 + React Router + Axios + Tailwind/CRACO + Radix + Framer Motion.
- Flutter/Dart + GoRouter + Riverpod + Dio + Flutter Secure Storage + Shared Preferences.
- Python FastAPI + Pydantic + Motor/PyMongo + bcrypt + PyJWT + HTTPX test transport.
- MongoDB.
- Emergent Universal Key -> Claude Sonnet 4.6 for itinerary generation.
- Unsplash image enrichment, OpenWeather forecast, Google Maps/Booking.com external links.

## Current Architecture

`backend/server.py` is the single backend module. It owns Pydantic document/request models, JWT/bcrypt auth, all API routes, Claude calls, fallback itinerary generation, Unsplash images, weather, Mongo startup indexes, and shutdown. It stores itineraries embedded in `trips` documents.

The web API client uses `http://localhost:8001/api` by default and Axios credentials/cookie auth, with one refresh retry. The mobile client uses Dio Bearer tokens from secure storage and currently defaults to `http://172.19.47.12:8001/api` for non-web builds. React routes live in `frontend/src/App.js`; Flutter routes live in `mobile/lib/core/routing/app_router.dart`.

## Completed Features

- Email register/login/logout/me/refresh.
- Emergent-managed Google OAuth session exchange remains on web; Flutter Android uses Google Sign-In and sends an ID token to `/auth/google/token`. Direct Android login requires configured Google OAuth client IDs.
- bcrypt passwords and failed-login lockout.
- Forgot-password token creation and web reset form, development-only link delivery.
- Profile name, photo URL, age, budget preference, food preference, languages, favourite destinations.
- AI plan form on web/mobile; Claude JSON request, one retry, deterministic local fallback, persisted trip.
- Activity image enrichment and curated cover fallback.
- Trip list/detail, metadata update route, web activity edit/add/remove, duplicate, soft-delete.
- Web read-only shared trip view and share token generation.
- Hotel/restaurant AI recommendation cards, favorites, Maps links, Booking.com hotel deep links.
- Weather endpoint and client displays when OpenWeather is configured.
- Budget/spent/remaining expense summary, categories, add/list/delete.
- Web localStorage and Flutter SharedPreferences offline expense queues.

## Incomplete Features

- RAG Travel Assistant backend plus React and Flutter MVPs now exist; persistent/vector retrieval and chat history remain incomplete.
- AI itinerary refinement now exists at `POST /api/trips/{id}/refine` with web and Flutter controls plus local fallback.
- No attractions feature.
- No live hotel/restaurant discovery or trusted inventory validation.
- Maps are intentionally postponed. Existing placeholders and external links remain unchanged.
- Expense edit endpoint and web/Flutter controls now exist; web and Flutter offline submissions carry client IDs for idempotent retries.
- Trip restore endpoint and web/Flutter restore UI now exist.
- Mobile now has reset-password routing, favorites, editable itinerary activities, AI refinement, trip-level expenses, and direct Android Google Sign-In. It still lacks public shared-trip view and dashboard recommendation breadth.
- Web and Flutter now have trip search, dashboard workspace quick actions, and profile-grounded saved-destination recommendations. Separate saved/past trip experiences remain incomplete.
- Phone OTP and Apple Sign-In remain deferred.

## Known Bugs / Risks

1. Production CORS is now configurable through `CORS_ORIGINS` or `FRONTEND_URL`; verify the deployed origin list before production.
2. Flutter share URLs use `TRAVEL_OS_WEB_URL` (LAN default `http://172.19.47.12:3000`) and `/shared/{token}`; the mobile dialog has a copy action and shared-owner mapping. Set the define for deployed/mobile builds.
3. `mobile/test/widget_test.dart` now exercises the login screen without live auth networking; rerun it from `mobile/` to confirm the final isolated version.
4. Offline amounts are not included in server summaries until synchronization.
5. AI output validation is only JSON shape plus non-empty days; generated place/pricing claims are untrusted.
6. Password reset returns/logs reset tokens because SMTP is not configured.
7. Backend returns JWT strings in auth JSON in addition to cookies.
8. Mobile has a hardcoded LAN IP for non-web API access.
9. Backend has 15 unit/ASGI tests and all pass; no React test files were found. The Flutter widget test passes. Full Flutter analysis still reports existing warnings/deprecations.

## Important Files

- [backend/server.py](backend/server.py): backend source of truth.
- [frontend/src/App.js](frontend/src/App.js): web routes/protection.
- [frontend/src/lib/api.js](frontend/src/lib/api.js): web API/auth refresh.
- [frontend/src/pages/Planner.jsx](frontend/src/pages/Planner.jsx): web planner.
- [frontend/src/pages/TripDetail.jsx](frontend/src/pages/TripDetail.jsx): web trip shell.
- [frontend/src/components/trip/ItineraryTab.jsx](frontend/src/components/trip/ItineraryTab.jsx): web itinerary editing/weather.
- [frontend/src/components/trip/MapTab.jsx](frontend/src/components/trip/MapTab.jsx): Maps placeholder.
- [frontend/src/components/trip/ExpensesTab.jsx](frontend/src/components/trip/ExpensesTab.jsx): web expense queue.
- [mobile/lib/core/network/api_client.dart](mobile/lib/core/network/api_client.dart): mobile API/token handling.
- [mobile/lib/core/routing/app_router.dart](mobile/lib/core/routing/app_router.dart): mobile navigation.
- [mobile/lib/features/auth/data/auth_repository.dart](mobile/lib/features/auth/data/auth_repository.dart): mobile auth.
- [mobile/lib/features/trips/data/trips_repository.dart](mobile/lib/features/trips/data/trips_repository.dart): mobile trips/planning.
- [mobile/lib/features/expenses/data/expenses_repository.dart](mobile/lib/features/expenses/data/expenses_repository.dart): mobile offline expenses.
- [mobile/lib/features/help/presentation/help_screen.dart](mobile/lib/features/help/presentation/help_screen.dart): Flutter RAG assistant.
- [PROJECT_STATE.md](PROJECT_STATE.md): full reconstructed state and audit.

## Important API Endpoints

All are under `/api`:

- Auth: `/auth/register`, `/auth/login`, `/auth/logout`, `/auth/me`, `/auth/refresh`, `/auth/google/session`, `/auth/forgot-password`, `/auth/reset-password`.
- Profile: `GET/PUT /profile`.
- Planning: `POST /trips/plan`, `POST /trips/{id}/refine`.
- Trips: `GET /trips`, `GET/PUT/DELETE /trips/{id}`, `PUT /trips/{id}/itinerary`, `POST /trips/{id}/duplicate`, `POST /trips/{id}/share`, `GET /trips/shared/{token}`, `GET /trips/{id}/weather`.
- Places/favorites: `GET/POST /trips/{id}/favorites`, `DELETE /favorites/{id}`.
- Expenses: `GET/POST /trips/{id}/expenses`, `GET /trips/{id}/expenses/summary`, `PUT/DELETE /expenses/{id}`.
- RAG is available at protected `POST /api/rag/ask`; there are no refinement, attractions, live-place, directions, expense-update, or restore routes.

## Database Collections

`users`, `profiles`, `trips` with embedded itinerary, `expenses`, `favorites`, `login_attempts`, and `password_reset_tokens`. Startup creates unique `users.email`, TTL reset-token expiry, login-attempt identifier, trip owner/deleted compound, trip share token, and expense trip indexes. RAG currently uses the versioned `backend/knowledge_base.json` file and has no Mongo knowledge collection.

## Environment Variables Required

Backend import/startup expects:

- `MONGO_URL`
- `DB_NAME`
- `JWT_SECRET`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `EMERGENT_LLM_KEY` when using Claude

Optional integrations/configuration:

- `ENV=production`
- `FRONTEND_URL`
- `UNSPLASH_ACCESS_KEY`
- `OPENWEATHER_API_KEY`
- Web `REACT_APP_BACKEND_URL`

Do not commit secrets. The checked-in docs contain a test/admin email in the legacy testing playbook; treat credentials as sensitive and rotate them if real.

## Current AI Implementation

Claude is called server-side through `LlmChat` with a system instruction to return JSON only. The planner prompt requests days, activities, hotels, restaurants, costs, and tips. The response is parsed with `json.loads`, retried once, then replaced by a local template if it fails. Unsplash is queried for activity images when keyed. There is no refinement state or grounded place validation.

## Current RAG Implementation

**PARTIAL.** `backend/knowledge_base.json` contains the versioned controlled FAQ corpus. `backend/server.py` provides lexical retrieval, protected `POST /api/rag/ask`, source metadata, a grounded Claude prompt, and a deterministic fallback/refusal. React and Flutter expose the assistant at `/help` with starter questions, loading/error states, and source labels. There is no Mongo document ingestion, vector store, or chat history. Keep it separate from the AI trip planner and never use it for live availability or invented policies.

## Current Map Implementation

Maps are postponed by product direction. Keep the current placeholder/native foundation and external links until the dedicated Maps milestone.

Sharing and restore reliability fixes are complete across web and Flutter: mobile parses the backend `{items: [...]}` deleted-trip response, refreshes the deleted list after restore/delete, uses a LAN-capable web URL, and exposes a copy action for generated share links. Web sharing has a clipboard fallback for non-secure LAN contexts, and dashboard list transitions now use layout-aware easing.

The restore endpoint also normalizes legacy timezone-naive `deleted_at` values from MongoDB to UTC before applying the 30-day restore-window check; this prevents a server-side 500 during web or mobile restore.

The mobile profile page no longer crashes when an existing account has an older food-preference spelling. Values are normalized to the three supported choices: `veg`, `nonveg`, and `both`.

## Current Milestone Progress

- [x] Google OAuth audience mismatch fixed for the mobile client and backend allowlist.
- [x] Flutter debug APK rebuilt successfully with the corrected client ID and API endpoint.
- [x] Mobile map foundation updated for the Android SDK without removing the placeholder fallback.
- [x] Authenticated dashboard trip search, workspace quick actions, and profile-grounded recommendations on web and Flutter.
- [ ] Maps remain postponed.

## Last Changes

The Git history contains one initial project setup commit (`5ac8e1d`, 2026-08-16). This takeover fixed production CORS configuration, corrected Flutter public share URLs, replaced the stale mobile counter test, fixed a narrow-screen login-footer overflow, added `backend/test_server.py` with 12 passing unit/ASGI tests, and implemented the controlled RAG backend, versioned JSON knowledge base, and React/Flutter `/help` UIs. It also added HTTPX to backend requirements plus `PROJECT_STATE.md` and this handoff document. Database behavior was not changed.

## Current Task

Continue Milestone 2 maps and trip reliability without changing the existing architecture.

## Next Task

Add richer saved/recent trip presentation, then strengthen the AI planner and add Maps-ready attractions without implementing Maps.

## Do Not Touch Without Review

- Do not replace `backend/server.py` with a new architecture.
- Do not migrate MongoDB or split embedded itineraries without a data migration plan.
- Do not replace JWT/cookie/Bearer auth without auditing both clients.
- Do not treat AI-generated hotels, restaurants, prices, or ratings as verified data.
- Do not add admin dashboard work during Phase 1.
- Do not expose or commit `.env` values, API keys, database credentials, or reset tokens.
- Do not reset Git, delete untracked work, or overwrite existing client integrations.
