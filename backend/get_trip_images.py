import os, requests
from pathlib import Path

def load_env(path='.env'):
    d={}
    try:
        for line in Path(path).read_text().splitlines():
            line=line.strip()
            if not line or line.startswith('#'): continue
            if '=' in line:
                k,v=line.split('=',1)
                d[k.strip()]=v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return d

env=load_env()
BASE='http://127.0.0.1:8001/api'
ADMIN_EMAIL=os.environ.get('ADMIN_EMAIL') or env.get('ADMIN_EMAIL')
ADMIN_PASSWORD=os.environ.get('ADMIN_PASSWORD') or env.get('ADMIN_PASSWORD')

s=requests.Session()
print('Logging in...')
r=s.post(f"{BASE}/auth/login", json={'email':ADMIN_EMAIL,'password':ADMIN_PASSWORD}, timeout=15)
print('login', r.status_code)
print(r.json())

r2=s.get(f"{BASE}/trips", timeout=15)
print('list trips', r2.status_code)
trips=r2.json().get('items', [])
print('found', len(trips))
if not trips:
    print('no trips')
else:
    for t in trips:
        print('\nTrip:', t.get('id'), t.get('title'))
        itin=t.get('itinerary',{})
        for d in itin.get('days',[]):
            print(' Day', d.get('date'))
            for a in d.get('activities',[]):
                img=a.get('image_url')
                print('  -', a.get('title'), '=>', img)
                if img:
                    try:
                        rr=requests.get(img, timeout=10)
                        print('    img status', rr.status_code, rr.headers.get('content-type'))
                    except Exception as e:
                        print('    img fetch error', e)
