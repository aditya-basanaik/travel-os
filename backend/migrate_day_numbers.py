import argparse
import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv(dotenv_path=Path(__file__).with_name('.env'))


def convert_day_numbers(itinerary):
    days = itinerary.get('days') if isinstance(itinerary, dict) else None
    if not isinstance(days, list):
        return False, False

    changed = False
    invalid = False
    for day in days:
        if not isinstance(day, dict) or 'day_number' not in day:
            continue
        value = day['day_number']
        if isinstance(value, str):
            try:
                day['day_number'] = int(value)
                changed = True
            except ValueError:
                invalid = True
    return changed, invalid


async def migrate(dry_run=False):
    mongo_url = os.environ['MONGO_URL']
    database_name = os.environ['DB_NAME']
    client = AsyncIOMotorClient(mongo_url)
    try:
        trips = client[database_name].trips
        scanned = 0
        fixed = 0
        skipped_invalid = 0

        async for trip in trips.find({'itinerary.days': {'$exists': True}}):
            scanned += 1
            itinerary = trip.get('itinerary')
            changed, invalid = convert_day_numbers(itinerary)
            if invalid:
                skipped_invalid += 1
                print(f"Skipped trip {trip['_id']}: non-numeric day_number present")
                continue
            if not changed:
                continue
            fixed += 1
            if not dry_run:
                await trips.update_one(
                    {'_id': trip['_id']},
                    {'$set': {'itinerary': itinerary}},
                )

        mode = 'would fix' if dry_run else 'fixed'
        print(f"Scanned {scanned} trips; {mode} {fixed} trips; skipped {skipped_invalid} invalid trips.")
    finally:
        client.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Normalize itinerary day_number strings to integers.')
    parser.add_argument('--dry-run', action='store_true', help='Read and report changes without writing any documents.')
    args = parser.parse_args()
    asyncio.run(migrate(dry_run=args.dry_run))
