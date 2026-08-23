# Travel OS

Travel OS is a travel-planning MVP with a React web app, a Flutter mobile app, a FastAPI backend, and MongoDB persistence.

## Current stack

- Web: React + CRACO + Tailwind
- Mobile: Flutter + Riverpod + GoRouter
- Backend: FastAPI + MongoDB + JWT auth
- AI: itinerary generation and refinement with a server-side Claude fallback
- Maps: native Google Maps foundation is in progress, with a safe fallback preserved when no key is configured

## Local development

### Backend

From the project root:

```bash
cd backend
pip install -r requirements.txt
python -m uvicorn server:app --host 0.0.0.0 --port 8001
```

Required env values include:

- `MONGO_URL`
- `DB_NAME`
- `JWT_SECRET`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `EMERGENT_LLM_KEY`
- `GOOGLE_OAUTH_CLIENT_IDS`

### Web frontend

```bash
cd frontend
npm install
npm start
```

### Mobile app

```bash
cd mobile
flutter pub get
flutter build apk --debug \
	--dart-define=TRAVEL_OS_API_URL=http://172.19.47.12:8001 \
	--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com \
	--dart-define=MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

## Current milestone status

- Auth and session flow are working.
- Flutter parity is mostly in place for auth, trip management, expenses, favorites, and itinerary refinement.
- Milestone 2 map integration is in progress: the mobile trip map now includes a native Google Maps foundation behind a safe fallback, while the placeholder UI remains when the API key is absent.
- Existing features remain intact and are not being replaced wholesale.

## Project documentation

- [PROJECT_STATE.md](PROJECT_STATE.md) tracks the reconstructed source-of-truth state.
- [AI_HANDOFF.md](AI_HANDOFF.md) records the current handoff and known risks.

## Notes

- Development auth cookies are HTTP-friendly for localhost testing.
- Production auth should use secure cookie settings and validated CORS configuration.
- Google Maps and backend keys must never be committed to source control.