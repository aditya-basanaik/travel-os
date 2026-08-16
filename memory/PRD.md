# Travel OS — PRD

## Original Problem Statement
AI-powered travel planning app (web, mobile-first) that lets a user plan an entire trip — itinerary, budget, hotels, restaurants, map, expenses — in one place instead of five apps. Phase 1 / MVP only; production-grade basics (security, data integrity, UX polish), no over-engineering.

## User Choices (confirmed)
- AI: Claude Sonnet 4.6 via Emergent Universal Key (server-side only)
- Auth: Email/password (JWT + bcrypt, httpOnly cookies) + Emergent-managed Google login. Phone OTP & Apple DEFERRED.
- Maps: placeholder screen until user provides Google Maps Platform key
- Hotels/Restaurants: AI-generated recommendations + deep-links to Google Maps / Booking.com (no partner APIs yet)
- Expenses: basic localStorage offline queue with sync — included

## Assumptions Made
- Platform stack used: React + FastAPI + MongoDB (instead of Node/PostgreSQL from the brief; MongoDB fits JSONB-style itinerary docs)
- Currency is per-trip (default ₹), not a global setting
- No SMTP provider in MVP → password reset returns a `dev_reset_link` in the API response and logs it server-side
- Trip cover image is auto-picked from a curated Unsplash set by destination keywords (no S3 upload yet)
- Soft-delete sets `deleted_at`; 30-day purge/restore job not built yet

## Architecture
- Backend: FastAPI (`/app/backend/server.py`), MongoDB via motor, JWT access (15 min) + refresh (7d) httpOnly cookies, bcrypt, brute-force lockout (5 attempts / 15 min via login_attempts collection), Claude itinerary generation with 1 retry + graceful 502
- Frontend: React + Tailwind + shadcn, Organic & Earthy design (forest green/sand/terracotta, Outfit + DM Sans), mobile bottom glass nav / desktop sidebar, sonner toasts, framer-motion
- Collections: users, profiles, trips (embedded itinerary), expenses, favorites, login_attempts, password_reset_tokens

## User Personas
- Solo/couple travellers planning budget-conscious trips
- Trip organizers who share read-only itineraries with companions

## Implemented (2026-08-06)
- Auth: register, login, logout, me, refresh, forgot/reset password (dev link), Google OAuth via Emergent, rate-limited login, admin seed (basanaikaditya2@gmail.com)
- Profile: view/edit (name, photo URL, age validation, budget pref, food pref, languages, favourite destinations, past trips count)
- AI Trip Planner: form (destination, dates, budget+currency, people, interest chips) → Claude-generated structured itinerary (days, activities, hotels, restaurants, cost breakdown, tips), stored in DB, editable
- Saved Trips: grid dashboard, share (public read-only link), duplicate, soft-delete, pagination-ready API
- Hotels & Restaurants tabs: recommendation cards, ratings, deep-links (Google Maps, Booking.com), favorites toggle
- Map tab: placeholder with key-notice + per-stop Google Maps links
- Expenses: budget/spent/remaining cards, progress bar, category breakdown, add/delete, offline localStorage queue + auto-sync badge
- Verified: auth curl flow, AI plan generation (Goa 3-day trip), login→dashboard UI

## Prioritized Backlog
### P0 (next)
- Fix any bugs from testing round 1
- Google Maps Platform integration once user provides API key (embedded map, directions, nearby search, server-side Places cache)
### P1
- Phone OTP login (needs Twilio/MSG91 keys) + Apple Sign-In (needs Apple developer creds)
- S3 profile photo / trip cover upload (object storage playbook)
- SMTP for real password-reset emails (SendGrid/Resend)
- Restore deleted trip within 30 days (UI + endpoint)
### P2
- Pagination UI on trips list, image lazy-load audit
- Expense charts (recharts), multi-currency conversion
- Offline-first beyond expenses

## Out of Scope (per brief — do not build)
In-app payments/booking engine, group planning, native apps, localization, push notifications, social feed
