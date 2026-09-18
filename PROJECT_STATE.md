# Travel OS Project State

> Current source-of-truth snapshot: 2026-09-18. Verify behavior in code and tests before extending it.

## Overview

Travel OS is a React web app and Flutter mobile app backed by FastAPI and MongoDB. It helps authenticated users plan trips with AI, edit itineraries, save recommendations, manage expenses, and share read-only trips. It is an MVP, not a live travel marketplace.

## Completed milestones

- Auth security and client parity: bcrypt passwords, login-failure lockout, access/refresh JWTs, protected `/auth/me`, password reset, cookie-authenticated web requests, Bearer-token mobile requests, and Google ID-token flows.
- Global favorites: web and Flutter clients can list, filter, add, and delete favorites across trip recommendations; the backend persists them independently of a single itinerary view.
- Itinerary day management: add/remove day endpoints and client controls, renumbering and date/cost normalization, plus the legacy string `day_number` data fix and regression coverage.
- Attraction model/provider abstraction: typed attraction data, provider interfaces, demo seed data, backend discovery/detail routes, and client attraction/favorites surfaces. The current provider data is static/demo, not a live third-party feed.
- AI planner and refinement: structured and natural-language planning, Claude integration when configured, deterministic local fallbacks, image enrichment, and persisted embedded itineraries.
- Supporting workflows: trip search, duplicate, soft-delete/restore, sharing, weather when configured, expenses with limited offline queues, and the FAQ-based help assistant.

## Known gaps and boundaries

- Phone OTP and Apple authentication are interface-only stubs/deferred; they are not real providers.
- There is no live third-party hotel, restaurant, or attraction data. Place names, ratings, prices, and demo attraction records are AI-generated or static demo data and must not be treated as verified inventory.
- Google Maps is intentionally frozen/postponed for this phase. The native foundation, placeholders, and external search links remain, but Maps search, routes, directions, nearby search, and trusted coordinates are not a completed product feature. Do not enable it without a dedicated future milestone.
- Password-reset production delivery depends on SMTP configuration; development uses a local reset link.
- Web auth uses HttpOnly cookies and Axios credentials. Mobile stores tokens securely and sends Bearer access tokens. Do not merge these contracts casually.
- Itineraries remain embedded in MongoDB `trips` documents; there is no migration framework.

## Architecture and structure

- `backend/server.py` is the backend source of truth for FastAPI routes, Pydantic models, auth helpers, AI planning, itinerary operations, favorites, attractions, and MongoDB access.
- `backend/auth_providers.py` defines auth provider boundaries; `backend/attraction_providers.py` defines attraction provider boundaries. These abstractions are the extension point for future real providers.
- `frontend/src/lib/api.js` uses cookie credentials and one refresh retry. `frontend/src/context/AuthContext.jsx` owns web session state.
- `mobile/lib/core/network/api_client.dart` owns Bearer token storage/refresh. Flutter repositories and Riverpod providers expose feature state to screens.
- `backend/knowledge_base.json` is the versioned FAQ corpus for the protected help assistant. It is not live place data.

## Data scripts

These scripts are manual operations and are not run automatically by the server:

```powershell
cd backend
python migrate_day_numbers.py --dry-run
python migrate_day_numbers.py
python seed_attractions.py
```

They load `backend/.env` and require a reachable MongoDB configured by `MONGO_URL` and `DB_NAME`. Review a dry run before applying the day-number migration. `seed_attractions.py --replace` deletes the existing demo attraction collection before reseeding.

## Verification and test counts

The current suites pass with 40 backend tests, 10 frontend tests, and 7 Flutter tests. `flutter analyze` reports 10 remaining diagnostics and no errors; they are listed in [AI_HANDOFF.md](AI_HANDOFF.md) because they require review or are in the frozen trip-detail surface.

## Priority next milestones

1. Create a dedicated Google Maps milestone covering provider configuration, place search, trusted coordinates, routes, directions, nearby search, and client UX.
2. Add real third-party provider integrations for hotels, restaurants, and attractions, with explicit freshness, pricing, availability, and attribution handling.
3. Implement real phone OTP and Apple authentication providers, including backend verification and web/mobile parity.