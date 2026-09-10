import argparse
import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv(dotenv_path=Path(__file__).with_name('.env'))

from server import Attraction


DEMO_ATTRACTIONS = [
    {"name": "Baga Beach", "description": "A lively North Goa beach known for sunsets and water sports.", "category": "beach", "city": "Goa", "country": "India", "address": "Baga, Goa", "latitude": 15.5557, "longitude": 73.7517, "rating": 4.3, "estimated_cost": 0, "images": [], "opening_hours": "Open 24 hours", "external_url": "https://www.goa-tourism.com/"},
    {"name": "Dudhsagar Falls", "description": "A dramatic four-tier waterfall surrounded by the Western Ghats.", "category": "nature", "city": "Goa", "country": "India", "address": "Mollem, Goa", "latitude": 15.3144, "longitude": 74.3144, "rating": 4.7, "estimated_cost": 600, "images": [], "opening_hours": "8:00 AM - 5:00 PM", "external_url": "https://www.goa-tourism.com/"},
    {"name": "Basilica of Bom Jesus", "description": "A UNESCO-listed baroque church in Old Goa.", "category": "culture", "city": "Goa", "country": "India", "address": "Old Goa, Goa", "latitude": 15.5009, "longitude": 73.9117, "rating": 4.5, "estimated_cost": 0, "images": [], "opening_hours": "9:00 AM - 6:30 PM", "external_url": "https://whc.unesco.org/en/list/234/"},
    {"name": "Shibuya Crossing", "description": "Tokyo's iconic pedestrian scramble surrounded by neon city life.", "category": "city", "city": "Tokyo", "country": "Japan", "address": "Shibuya, Tokyo", "latitude": 35.6595, "longitude": 139.7005, "rating": 4.6, "estimated_cost": 0, "images": [], "opening_hours": "Open 24 hours", "external_url": "https://www.gotokyo.org/"},
    {"name": "Senso-ji Temple", "description": "Tokyo's oldest temple, reached through the Kaminarimon gate.", "category": "culture", "city": "Tokyo", "country": "Japan", "address": "2-3-1 Asakusa, Taito City", "latitude": 35.7148, "longitude": 139.7967, "rating": 4.7, "estimated_cost": 0, "images": [], "opening_hours": "6:00 AM - 5:00 PM", "external_url": "https://www.senso-ji.jp/"},
    {"name": "teamLab Borderless", "description": "An immersive digital art museum with constantly changing rooms.", "category": "art", "city": "Tokyo", "country": "Japan", "address": "Azabudai Hills, Tokyo", "latitude": 35.6628, "longitude": 139.7394, "rating": 4.5, "estimated_cost": 3800, "images": [], "opening_hours": "9:00 AM - 9:00 PM", "external_url": "https://www.teamlab.art/e/borderless-azabudai/"},
    {"name": "Eiffel Tower", "description": "Paris's landmark iron tower with sweeping city views.", "category": "landmark", "city": "Paris", "country": "France", "address": "Champ de Mars, 5 Avenue Anatole France", "latitude": 48.8584, "longitude": 2.2945, "rating": 4.7, "estimated_cost": 29, "images": [], "opening_hours": "9:30 AM - 11:45 PM", "external_url": "https://www.toureiffel.paris/"},
    {"name": "Louvre Museum", "description": "A vast museum home to masterpieces from antiquity to modern art.", "category": "culture", "city": "Paris", "country": "France", "address": "Rue de Rivoli, Paris", "latitude": 48.8606, "longitude": 2.3376, "rating": 4.7, "estimated_cost": 22, "images": [], "opening_hours": "9:00 AM - 6:00 PM", "external_url": "https://www.louvre.fr/"},
    {"name": "Montmartre", "description": "A historic hilltop neighborhood known for art, cafes, and Sacre-Coeur.", "category": "neighborhood", "city": "Paris", "country": "France", "address": "Montmartre, Paris", "latitude": 48.8867, "longitude": 2.3431, "rating": 4.6, "estimated_cost": 0, "images": [], "opening_hours": "Open 24 hours", "external_url": "https://parisjetaime.com/"},
    {"name": "Lalbagh Botanical Garden", "description": "A historic Bengaluru garden with glasshouse displays and quiet paths.", "category": "nature", "city": "Bengaluru", "country": "India", "address": "Mavalli, Bengaluru", "latitude": 12.9507, "longitude": 77.5848, "rating": 4.4, "estimated_cost": 30, "images": [], "opening_hours": "6:00 AM - 7:00 PM", "external_url": "https://horticultur.karnataka.gov.in/"},
]


async def seed(replace=False):
    client = AsyncIOMotorClient(os.environ['MONGO_URL'])
    try:
        collection = client[os.environ['DB_NAME']].attractions
        if replace:
            await collection.delete_many({})
        inserted = 0
        for item in DEMO_ATTRACTIONS:
            if await collection.find_one({"name": item["name"], "city": item["city"]}):
                continue
            await collection.insert_one(Attraction(**item).to_mongo())
            inserted += 1
        await collection.create_index("city")
        print(f"Inserted {inserted} demo attractions ({len(DEMO_ATTRACTIONS)} defined).")
    finally:
        client.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Seed curated demo attractions.')
    parser.add_argument('--replace', action='store_true', help='Delete existing attractions before inserting demo data.')
    args = parser.parse_args()
    asyncio.run(seed(replace=args.replace))
