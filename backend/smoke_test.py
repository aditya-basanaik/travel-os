import os, requests, json

BASE = "http://127.0.0.1:8001/api"


def load_env(path=".env"):
    d = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    v = v.strip().strip('"').strip("'")
                    d[k] = v
    except FileNotFoundError:
        pass
    return d


env = load_env()
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL") or env.get("ADMIN_EMAIL")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD") or env.get("ADMIN_PASSWORD")

s = requests.Session()

print("Logging in...")
r = s.post(f"{BASE}/auth/login", json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}, timeout=15)
print("Login status:", r.status_code)
try:
    print(json.dumps(r.json(), indent=2))
except Exception:
    print(r.text)

print("\nFetching trips...")
r2 = s.get(f"{BASE}/trips", timeout=15)
print("Trips status:", r2.status_code)
try:
    print(json.dumps(r2.json(), indent=2))
except Exception:
    print(r2.text)

items = []
try:
    items = r2.json().get("items", [])
except Exception:
    items = []

if items:
    trip_id = items[0].get("id")
    print(f"\nGetting weather for trip {trip_id}...")
    r3 = s.get(f"{BASE}/trips/{trip_id}/weather", timeout=15)
    print("Weather status:", r3.status_code)
    try:
        print(json.dumps(r3.json(), indent=2))
    except Exception:
        print(r3.text)
else:
    print("\nNo trips found; creating a test plan (this will use the itinerary fallback if LLM is unavailable)...")
    body = {
        "destination": "Paris",
        "start_date": "2026-08-10",
        "end_date": "2026-08-12",
        "budget": 50000,
        "currency": "₹",
        "people_count": 2,
        "interests": ["food", "culture"],
    }
    rp = s.post(f"{BASE}/trips/plan", json=body, timeout=120)
    print("Plan status:", rp.status_code)
    try:
        out = rp.json()
        print(json.dumps(out, indent=2))
        trip_id = out.get("id")
        print(f"\nFetching weather for newly created trip {trip_id}...")
        r3 = s.get(f"{BASE}/trips/{trip_id}/weather", timeout=15)
        print("Weather status:", r3.status_code)
        try:
            print(json.dumps(r3.json(), indent=2))
        except Exception:
            print(r3.text)
    except Exception as e:
        print("Plan response error:", rp.text, str(e))
