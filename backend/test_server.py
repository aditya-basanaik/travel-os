import os
import sys
import unittest
from datetime import timedelta
from unittest.mock import AsyncMock, patch

import httpx
from pydantic import ValidationError


os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "travel_os_test")
os.environ.setdefault("JWT_SECRET", "unit-test-secret-with-32-plus-bytes")
os.environ.setdefault("ADMIN_EMAIL", "admin@example.com")
os.environ.setdefault("ADMIN_PASSWORD", "password-for-tests")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key")

sys.path.insert(0, os.path.dirname(__file__))

import server


class FakeTripsCollection:
    def __init__(self, documents):
        self.documents = documents

    async def find_one(self, query):
        for document in self.documents:
            if all(document.get(key) == value for key, value in query.items()):
                return document
        return None


class InMemoryCollection:
    def __init__(self):
        self.documents = []

    async def find_one(self, query):
        for document in self.documents:
            if all(document.get(key) == value for key, value in query.items()):
                return document
        return None

    async def insert_one(self, document):
        self.documents.append(dict(document))

    async def update_one(self, query, update, upsert=False):
        document = await self.find_one(query)
        if document is None:
            if not upsert:
                return
            document = dict(query)
            self.documents.append(document)
        for key, value in update.get("$set", {}).items():
            document[key] = value
        for key, value in update.get("$inc", {}).items():
            document[key] = document.get(key, 0) + value

    async def delete_one(self, query):
        for index, document in enumerate(self.documents):
            if all(document.get(key) == value for key, value in query.items()):
                self.documents.pop(index)
                return

    async def count_documents(self, query):
        return sum(
            all(document.get(key) == value for key, value in query.items())
            for document in self.documents
        )


class ServerUnitTests(unittest.IsolatedAsyncioTestCase):
    def test_password_hash_round_trip(self):
        hashed = server.hash_password("correct horse battery staple")

        self.assertNotEqual(hashed, "correct horse battery staple")
        self.assertTrue(server.verify_password("correct horse battery staple", hashed))
        self.assertFalse(server.verify_password("wrong password", hashed))

    def test_access_token_contains_access_claims(self):
        token = server.create_access_token("user-123", "traveller@example.com")
        payload = server.jwt.decode(token, server.JWT_SECRET, algorithms=[server.JWT_ALGORITHM])

        self.assertEqual(payload["sub"], "user-123")
        self.assertEqual(payload["email"], "traveller@example.com")
        self.assertEqual(payload["type"], "access")
        self.assertGreater(payload["exp"], server.utcnow().timestamp())

    def test_refresh_token_has_refresh_type_and_longer_lifetime(self):
        token = server.create_refresh_token("user-123")
        payload = server.jwt.decode(token, server.JWT_SECRET, algorithms=[server.JWT_ALGORITHM])

        self.assertEqual(payload["sub"], "user-123")
        self.assertEqual(payload["type"], "refresh")
        self.assertGreater(payload["exp"], (server.utcnow() + timedelta(days=6)).timestamp())

    def test_public_user_removes_password_hash(self):
        result = server.public_user({"_id": "user-123", "email": "user@example.com", "password_hash": "secret"})

        self.assertEqual(result["id"], "user-123")
        self.assertEqual(result["email"], "user@example.com")
        self.assertNotIn("password_hash", result)

    def test_plan_request_rejects_non_positive_budget(self):
        with self.assertRaises(ValidationError):
            server.PlanRequest(
                destination="Goa",
                start_date="2026-09-01",
                end_date="2026-09-03",
                budget=0,
            )

    def test_activity_image_candidates_are_destination_specific(self):
        candidates = server.build_activity_image_candidates("Sunrise viewpoint", "Eiffel Tower, Paris", "Paris", "nature")

        self.assertTrue(any("Sunrise viewpoint" in c for c in candidates))
        self.assertTrue(any("Paris" in c for c in candidates))
        self.assertTrue(any("Eiffel Tower" in c for c in candidates))

    async def test_owned_trip_returns_only_active_trip_for_current_user(self):
        original_trips = server.db.trips
        server.db.trips = FakeTripsCollection([
            {"_id": "trip-1", "user_id": "user-1", "deleted_at": None},
            {"_id": "trip-2", "user_id": "user-2", "deleted_at": None},
        ])
        try:
            result = await server.get_owned_trip("trip-1", {"_id": "user-1"})
        finally:
            server.db.trips = original_trips

        self.assertEqual(result["_id"], "trip-1")

    async def test_owned_trip_rejects_foreign_and_deleted_trip(self):
        original_trips = server.db.trips
        server.db.trips = FakeTripsCollection([
            {"_id": "trip-foreign", "user_id": "other-user", "deleted_at": None},
            {"_id": "trip-deleted", "user_id": "user-1", "deleted_at": "deleted"},
        ])
        try:
            for trip_id in ("trip-foreign", "trip-deleted", "missing"):
                with self.subTest(trip_id=trip_id):
                    with self.assertRaises(server.HTTPException) as context:
                        await server.get_owned_trip(trip_id, {"_id": "user-1"})
                    self.assertEqual(context.exception.status_code, 404)
        finally:
            server.db.trips = original_trips


class AuthHttpTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.original_collections = {
            "users": server.db.users,
            "profiles": server.db.profiles,
            "login_attempts": server.db.login_attempts,
            "trips": server.db.trips,
        }
        server.db.users = InMemoryCollection()
        server.db.profiles = InMemoryCollection()
        server.db.login_attempts = InMemoryCollection()
        server.db.trips = InMemoryCollection()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=server.app),
            base_url="http://testserver",
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        for name, collection in self.original_collections.items():
            setattr(server.db, name, collection)

    async def test_register_me_refresh_and_bearer_auth(self):
        register = await self.client.post(
            "/api/auth/register",
            json={"name": "Test Traveller", "email": "TEST@example.com", "password": "password123"},
        )

        self.assertEqual(register.status_code, 200)
        registered = register.json()
        self.assertEqual(registered["email"], "test@example.com")
        self.assertNotIn("password_hash", registered)
        self.assertIn("access_token", registered)
        self.assertIn("refresh_token", registered)
        self.assertIn("access_token", self.client.cookies)
        self.assertIn("refresh_token", self.client.cookies)

        current = await self.client.get("/api/auth/me")
        self.assertEqual(current.status_code, 200)
        self.assertEqual(current.json()["id"], registered["id"])

        refresh_token = registered["refresh_token"]
        self.client.cookies.clear()
        self.client.cookies.set("refresh_token", refresh_token)
        refreshed = await self.client.post(
            "/api/auth/refresh",
        )

        self.assertEqual(refreshed.status_code, 200)
        new_access = refreshed.json()["access_token"]
        bearer_me = await self.client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {new_access}"},
        )
        self.assertEqual(bearer_me.status_code, 200)
        self.assertEqual(bearer_me.json()["email"], "test@example.com")

    async def test_invalid_login_is_rejected(self):
        await self.client.post(
            "/api/auth/register",
            json={"name": "Test Traveller", "email": "test@example.com", "password": "password123"},
        )

        login = await self.client.post(
            "/api/auth/login",
            json={"email": "test@example.com", "password": "wrong-password"},
        )

        self.assertEqual(login.status_code, 401)
        self.assertEqual(login.json()["detail"], "Invalid email or password")

    async def test_authenticated_profile_and_trip_ownership(self):
        register = await self.client.post(
            "/api/auth/register",
            json={"name": "Trip Owner", "email": "owner@example.com", "password": "password123"},
        )
        self.assertEqual(register.status_code, 200)
        owner_id = register.json()["id"]

        profile = await self.client.get("/api/profile")
        self.assertEqual(profile.status_code, 200)
        self.assertEqual(profile.json()["user_id"], owner_id)
        self.assertEqual(profile.json()["email"], "owner@example.com")

        trip = server.Trip(
            user_id=owner_id,
            title="Owner trip",
            destination="Goa",
            start_date="2026-09-01",
            end_date="2026-09-03",
            budget=25000,
        )
        await server.db.trips.insert_one(trip.to_mongo())

        owned = await self.client.get(f"/api/trips/{trip.id}")
        self.assertEqual(owned.status_code, 200)
        self.assertEqual(owned.json()["id"], trip.id)

        self.client.cookies.clear()
        other_register = await self.client.post(
            "/api/auth/register",
            json={"name": "Other Traveller", "email": "other@example.com", "password": "password123"},
        )
        self.assertEqual(other_register.status_code, 200)

        foreign = await self.client.get(f"/api/trips/{trip.id}")
        self.assertEqual(foreign.status_code, 404)
        self.assertEqual(foreign.json()["detail"], "Trip not found")

    async def test_rag_requires_auth_and_returns_grounded_sources(self):
        unauthenticated = await self.client.post(
            "/api/rag/ask",
            json={"question": "How do I save a trip?"},
        )
        self.assertEqual(unauthenticated.status_code, 401)

        await self.client.post(
            "/api/auth/register",
            json={"name": "Help Seeker", "email": "help@example.com", "password": "password123"},
        )
        with patch.object(server, "call_rag_llm", new=AsyncMock(return_value="Trips are saved automatically.")):
            response = await self.client.post(
                "/api/rag/ask",
                json={"question": "How do I save a trip?"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["answer"], "Trips are saved automatically.")
        self.assertEqual(response.json()["sources"][0]["id"], "trips-save-edit")

    async def test_rag_declines_unknown_policy_questions(self):
        await self.client.post(
            "/api/auth/register",
            json={"name": "Help Seeker", "email": "help@example.com", "password": "password123"},
        )

        response = await self.client.post(
            "/api/rag/ask",
            json={"question": "What is Travel OS refund policy?"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("do not have enough information", response.json()["answer"])
        self.assertEqual(response.json()["sources"], [])

    async def test_refine_trip_uses_local_budget_fallback(self):
        register = await self.client.post(
            "/api/auth/register",
            json={"name": "Planner", "email": "planner@example.com", "password": "password123"},
        )
        trip = server.Trip(
            user_id=register.json()["id"],
            title="Budget trip",
            destination="Goa",
            start_date="2026-09-01",
            end_date="2026-09-02",
            budget=10000,
            itinerary={
                "days": [{"day_number": 1, "activities": [{"title": "Beach", "type": "activity", "estimated_cost": 1000}], "estimated_cost": 1000}],
                "cost_breakdown": {"food": 2000},
            },
        )
        await server.db.trips.insert_one(trip.to_mongo())

        with patch.dict(os.environ, {"EMERGENT_LLM_KEY": ""}):
            response = await self.client.post(
                f"/api/trips/{trip.id}/refine",
                json={"instruction": "Make it cheaper"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["itinerary"]["days"][0]["activities"][0]["estimated_cost"], 850)

    async def test_expense_client_id_makes_retry_idempotent(self):
        register = await self.client.post(
            "/api/auth/register",
            json={"name": "Expense User", "email": "expense@example.com", "password": "password123"},
        )
        trip = server.Trip(
            user_id=register.json()["id"],
            title="Expense trip",
            destination="Goa",
            start_date="2026-09-01",
            end_date="2026-09-02",
            budget=10000,
        )
        await server.db.trips.insert_one(trip.to_mongo())
        payload = {"category": "food", "amount": 500, "client_id": "offline-client-123"}

        first = await self.client.post(f"/api/trips/{trip.id}/expenses", json=payload)
        second = await self.client.post(f"/api/trips/{trip.id}/expenses", json=payload)

        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["id"], second.json()["id"])


if __name__ == "__main__":
    unittest.main()