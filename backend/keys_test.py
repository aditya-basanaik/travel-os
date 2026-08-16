import os, requests
from pathlib import Path

# load .env (simple)
env = {}
for line in Path('.env').read_text().splitlines():
    line=line.strip()
    if not line or line.startswith('#'): continue
    if '=' in line:
        k,v=line.split('=',1)
        env[k.strip()] = v.strip().strip('"').strip("'")

UNSPLASH_KEY = os.environ.get('UNSPLASH_ACCESS_KEY') or env.get('UNSPLASH_ACCESS_KEY')
OW_KEY = os.environ.get('OPENWEATHER_API_KEY') or env.get('OPENWEATHER_API_KEY')
print('Unsplash key present:', bool(UNSPLASH_KEY))
print('OpenWeather key present:', bool(OW_KEY))

# Test Unsplash
if UNSPLASH_KEY:
    try:
        r = requests.get('https://api.unsplash.com/search/photos', params={'query':'Eiffel Tower','per_page':1}, headers={'Authorization':f'Client-ID {UNSPLASH_KEY}'}, timeout=10)
        print('\nUnsplash status:', r.status_code)
        try:
            j=r.json()
            print('Unsplash total:', j.get('total'))
            print('Sample urls:', j.get('results',[{}])[0].get('urls'))
        except Exception as e:
            print('Unsplash json parse error', e, r.text[:200])
    except Exception as e:
        print('Unsplash request failed:', e)
else:
    print('\nNo Unsplash key to test')

# Test OpenWeather (forecast) for Paris
if OW_KEY:
    try:
        r = requests.get('https://api.openweathermap.org/data/2.5/forecast', params={'q':'Paris','appid':OW_KEY,'units':'metric'}, timeout=10)
        print('\nOpenWeather status:', r.status_code)
        try:
            j=r.json()
            print('OpenWeather city:', j.get('city'))
            print('Sample list len:', len(j.get('list',[])))
        except Exception as e:
            print('OpenWeather json parse error', e, r.text[:200])
    except Exception as e:
        print('OpenWeather request failed:', e)
else:
    print('\nNo OpenWeather key to test')
