import requests
url = "http://127.0.0.1:8001/api/auth/login"
headers = {
    "Origin": "http://localhost:3002",
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "content-type",
}

r = requests.options(url, headers=headers, timeout=10)
print("Status:", r.status_code)
print('\nResponse headers:')
for k, v in r.headers.items():
    print(f"{k}: {v}")
print("\nBody:\n", r.text)
