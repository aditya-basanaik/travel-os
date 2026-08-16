# Auth Testing Playbook (Travel OS)

## Step 1: MongoDB Verification
```
mongosh
use test_database
db.users.find({role: "admin"}).pretty()
db.users.findOne({role: "admin"}, {password_hash: 1})
```
Verify: bcrypt hash starts with `$2b$`, indexes exist on users.email (unique), login_attempts.identifier, password_reset_tokens.expires_at (TTL).

## Step 2: API Testing
```
curl -c cookies.txt -X POST http://localhost:8001/api/auth/login -H "Content-Type: application/json" -d '{"email":"basanaikaditya2@gmail.com","password":"TravelOS@2026"}'
cat cookies.txt
curl -b cookies.txt http://localhost:8001/api/auth/me
```
Login should return the user object and set `access_token` + `refresh_token` cookies. `/me` should return the same user with those cookies.

## Other endpoints
- POST /api/auth/register {name, email, password}
- POST /api/auth/refresh (uses refresh_token cookie)
- POST /api/auth/logout
- POST /api/auth/forgot-password {email} → response includes `dev_reset_link` (no email provider in MVP; link is also logged server-side)
- POST /api/auth/reset-password {token, password}
- POST /api/auth/google/session {session_id} — Emergent-managed Google OAuth exchange
