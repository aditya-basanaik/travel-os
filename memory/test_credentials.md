# Test Credentials

## Admin / Owner
- Email: basanaikaditya2@gmail.com
- Password: TravelOS@2026
- Role: admin

## Test User
- Email: demo.traveler@travelos.app
- Password: DemoTrip@123
- Role: user (create via POST /api/auth/register if not present)

## Auth Endpoints
- POST /api/auth/register {name, email, password}
- POST /api/auth/login {email, password}
- GET /api/auth/me (httpOnly cookie auth)
- POST /api/auth/refresh
- POST /api/auth/logout
- POST /api/auth/forgot-password → returns `dev_reset_link` in response (no SMTP in MVP)
- POST /api/auth/reset-password {token, password}
- POST /api/auth/google/session {session_id} (Emergent-managed Google OAuth)

## Google OAuth
- Login button redirects to https://auth.emergentagent.com/?redirect=<origin>/auth/callback
- Callback page extracts #session_id from URL hash and exchanges it at /api/auth/google/session
