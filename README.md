# Travel OS Local Development

This repo has two local services:

- Backend: FastAPI in `backend/server.py`
- Frontend: React in `frontend/`

## Start the backend

From the `backend/` folder:

```bash
pip install -r requirements.txt
uvicorn server:app --reload --port 8001
```

The backend expects these environment variables before startup:

- `MONGO_URL`
- `DB_NAME`
- `JWT_SECRET`
- `EMERGENT_LLM_KEY`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`

## Start the frontend

From the `frontend/` folder:

```bash
npm install
npm start
```

## Notes

Auth cookies are environment-aware now. In development, cookies use `secure=false` and `SameSite=lax` so localhost login works over HTTP. In production, they switch back to `secure=true` and `SameSite=none`.