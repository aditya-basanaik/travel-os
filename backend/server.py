from dotenv import load_dotenv
from pathlib import Path

load_dotenv(dotenv_path=Path(__file__).with_name(".env"))

import os
import re
import json
import uuid
import asyncio
import secrets
import logging
from datetime import datetime, timezone, timedelta
from typing import Annotated, Optional, List

import bcrypt
import jwt
import requests
from bson import ObjectId
from fastapi import FastAPI, APIRouter, HTTPException, Request, Response, Depends, Query
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, Field, EmailStr, BeforeValidator, ConfigDict
from starlette.middleware.cors import CORSMiddleware

mongo_url = os.environ["MONGO_URL"]
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ["DB_NAME"]]

app = FastAPI()
api_router = APIRouter(prefix="/api")
logger = logging.getLogger("travelos")
logging.basicConfig(level=logging.INFO)

IS_PROD = os.environ.get("ENV", "development") == "production"
JWT_ALGORITHM = "HS256"
JWT_SECRET = os.environ["JWT_SECRET"]
CORS_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", os.environ.get("FRONTEND_URL", "")).split(",")
    if origin.strip()
]

PyObjectId = Annotated[str, BeforeValidator(lambda v: str(v) if isinstance(v, ObjectId) else str(v))]


def utcnow():
    return datetime.now(timezone.utc)


class BaseDocument(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    id: PyObjectId = Field(default_factory=lambda: str(uuid.uuid4()), alias="_id")

    def to_mongo(self):
        return self.model_dump(by_alias=True, exclude_none=True)

    @classmethod
    def from_mongo(cls, doc):
        if not doc:
            return None
        return cls(**doc)


# ---------- Models ----------

class User(BaseDocument):
    name: str
    email: str
    password_hash: Optional[str] = None
    auth_provider: str = "email"
    email_verified: bool = False
    picture: Optional[str] = None
    role: str = "user"
    created_at: datetime = Field(default_factory=utcnow)


class Profile(BaseDocument):
    user_id: str
    photo_url: Optional[str] = None
    age: Optional[int] = None
    budget_pref: Optional[str] = None
    food_pref: Optional[str] = None
    languages: List[str] = []
    favourite_destinations: List[str] = []
    updated_at: datetime = Field(default_factory=utcnow)


class Trip(BaseDocument):
    user_id: str
    title: str
    destination: str
    start_date: str
    end_date: str
    budget: float
    currency: str = "₹"
    people_count: int = 1
    interests: List[str] = []
    status: str = "planned"
    cover_image: Optional[str] = None
    itinerary: Optional[dict] = None
    share_token: Optional[str] = None
    deleted_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=utcnow)
    updated_at: datetime = Field(default_factory=utcnow)


class Expense(BaseDocument):
    trip_id: str
    user_id: str
    category: str
    amount: float
    note: Optional[str] = None
    client_id: Optional[str] = None
    created_at: datetime = Field(default_factory=utcnow)


class Favorite(BaseDocument):
    user_id: str
    trip_id: Optional[str] = None
    type: str
    external_id: Optional[str] = None
    name: str
    meta: dict = {}
    created_at: datetime = Field(default_factory=utcnow)


# ---------- Request schemas ----------

class RegisterIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class GoogleSessionIn(BaseModel):
    session_id: str


class GoogleTokenIn(BaseModel):
    id_token: str = Field(min_length=20)


class ForgotIn(BaseModel):
    email: EmailStr


class ResetIn(BaseModel):
    token: str
    password: str = Field(min_length=8, max_length=128)


class ProfileIn(BaseModel):
    photo_url: Optional[str] = None
    age: Optional[int] = Field(default=None, gt=0, le=120)
    budget_pref: Optional[str] = None
    food_pref: Optional[str] = None
    languages: List[str] = []
    favourite_destinations: List[str] = []
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)


class PlanRequest(BaseModel):
    destination: str = Field(min_length=2, max_length=120)
    start_date: str
    end_date: str
    budget: float = Field(gt=0)
    currency: str = "₹"
    people_count: int = Field(default=1, ge=1, le=30)
    interests: List[str] = []


class TripUpdate(BaseModel):
    title: Optional[str] = None
    destination: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget: Optional[float] = Field(default=None, gt=0)
    currency: Optional[str] = None
    people_count: Optional[int] = Field(default=None, ge=1, le=30)
    interests: Optional[List[str]] = None
    status: Optional[str] = None


class ItineraryUpdate(BaseModel):
    itinerary: dict


class ExpenseIn(BaseModel):
    category: str
    amount: float = Field(gt=0)
    note: Optional[str] = Field(default=None, max_length=200)
    client_id: Optional[str] = Field(default=None, min_length=8, max_length=100)


class ExpenseUpdate(BaseModel):
    category: Optional[str] = None
    amount: Optional[float] = Field(default=None, gt=0)
    note: Optional[str] = Field(default=None, max_length=200)


class FavoriteIn(BaseModel):
    type: str
    name: str
    external_id: Optional[str] = None
    meta: dict = {}


class RAGQuestionIn(BaseModel):
    question: str = Field(min_length=3, max_length=500)


class RefineRequest(BaseModel):
    instruction: str = Field(min_length=3, max_length=500)


# ---------- Auth helpers ----------

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(user_id: str, email: str) -> str:
    payload = {"sub": user_id, "email": email, "exp": utcnow() + timedelta(minutes=15), "type": "access"}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    payload = {"sub": user_id, "exp": utcnow() + timedelta(days=7), "type": "refresh"}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def set_auth_cookies(response: Response, user_id: str, email: str):
    response.set_cookie("access_token", create_access_token(user_id, email), httponly=True, secure=IS_PROD, samesite="none" if IS_PROD else "lax", max_age=900, path="/")
    response.set_cookie("refresh_token", create_refresh_token(user_id), httponly=True, secure=IS_PROD, samesite="none" if IS_PROD else "lax", max_age=604800, path="/")


def public_user(doc: dict) -> dict:
    doc = dict(doc)
    doc["id"] = str(doc.pop("_id"))
    doc.pop("password_hash", None)
    return doc


async def get_current_user(request: Request) -> dict:
    token = request.cookies.get("access_token")
    if not token:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
    if not token:
        raise HTTPException(401, "Not authenticated")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(401, "Invalid token type")
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")
    user = await db.users.find_one({"_id": payload["sub"]})
    if not user:
        raise HTTPException(401, "User not found")
    return user


# ---------- Auth endpoints ----------

@api_router.post("/auth/register")
async def register(body: RegisterIn, response: Response):
    email = body.email.lower()
    if await db.users.find_one({"email": email}):
        raise HTTPException(409, "An account with this email already exists")
    user = User(name=body.name.strip(), email=email, password_hash=hash_password(body.password))
    await db.users.insert_one(user.to_mongo())
    await db.profiles.insert_one(Profile(user_id=user.id).to_mongo())
    access_token = create_access_token(user.id, email)
    refresh_token = create_refresh_token(user.id)
    set_auth_cookies(response, user.id, email)
    res_data = public_user(user.to_mongo())
    res_data["access_token"] = access_token
    res_data["refresh_token"] = refresh_token
    return res_data


@api_router.post("/auth/login")
async def login(body: LoginIn, request: Request, response: Response):
    email = body.email.lower()
    identifier = f"{request.client.host}:{email}"
    attempts = await db.login_attempts.find_one({"identifier": identifier})
    if attempts and attempts.get("count", 0) >= 5:
        locked_until = attempts.get("locked_until")
        if locked_until and locked_until > utcnow().isoformat():
            raise HTTPException(429, "Too many failed attempts. Try again in 15 minutes.")
    user = await db.users.find_one({"email": email})
    if not user or not user.get("password_hash") or not verify_password(body.password, user["password_hash"]):
        await db.login_attempts.update_one(
            {"identifier": identifier},
            {"$inc": {"count": 1}, "$set": {"locked_until": (utcnow() + timedelta(minutes=15)).isoformat()}},
            upsert=True,
        )
        raise HTTPException(401, "Invalid email or password")
    await db.login_attempts.delete_one({"identifier": identifier})
    access_token = create_access_token(user["_id"], email)
    refresh_token = create_refresh_token(user["_id"])
    set_auth_cookies(response, user["_id"], email)
    res_data = public_user(user)
    res_data["access_token"] = access_token
    res_data["refresh_token"] = refresh_token
    return res_data


@api_router.post("/auth/google/session")
async def google_session(body: GoogleSessionIn, response: Response):
    try:
        r = requests.get(
            "https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data",
            headers={"X-Session-ID": body.session_id},
            timeout=10,
        )
    except requests.RequestException:
        raise HTTPException(502, "Google sign-in is temporarily unavailable")
    if r.status_code != 200:
        raise HTTPException(401, "Invalid or expired Google session")
    data = r.json()
    email = data["email"].lower()
    user = await db.users.find_one({"email": email})
    if not user:
        new_user = User(name=data.get("name", email.split("@")[0]), email=email, auth_provider="google", email_verified=True, picture=data.get("picture"))
        await db.users.insert_one(new_user.to_mongo())
        await db.profiles.insert_one(Profile(user_id=new_user.id, photo_url=data.get("picture")).to_mongo())
        user = new_user.to_mongo()
    access_token = create_access_token(user["_id"], email)
    refresh_token = create_refresh_token(user["_id"])
    set_auth_cookies(response, user["_id"], email)
    res_data = public_user(user)
    res_data["access_token"] = access_token
    res_data["refresh_token"] = refresh_token
    return res_data


@api_router.post("/auth/google/token")
async def google_token(body: GoogleTokenIn, response: Response):
    try:
        r = requests.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": body.id_token},
            timeout=10,
        )
    except requests.RequestException:
        raise HTTPException(502, "Google sign-in is temporarily unavailable")
    if r.status_code != 200:
        raise HTTPException(401, "Invalid or expired Google token")

    data = r.json()
    configured_audiences = {
        value.strip()
        for value in os.environ.get("GOOGLE_OAUTH_CLIENT_IDS", "").split(",")
        if value.strip()
    }
    if not configured_audiences or data.get("aud") not in configured_audiences:
        raise HTTPException(401, "Google token audience is not configured")
    if data.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise HTTPException(401, "Invalid Google token issuer")
    if str(data.get("email_verified", "false")).lower() != "true":
        raise HTTPException(401, "Google email is not verified")

    email = data["email"].lower()
    user = await db.users.find_one({"email": email})
    if not user:
        new_user = User(
            name=data.get("name", email.split("@")[0]),
            email=email,
            auth_provider="google",
            email_verified=True,
            picture=data.get("picture"),
        )
        await db.users.insert_one(new_user.to_mongo())
        await db.profiles.insert_one(Profile(user_id=new_user.id, photo_url=data.get("picture")).to_mongo())
        user = new_user.to_mongo()
    access_token = create_access_token(user["_id"], email)
    refresh_token = create_refresh_token(user["_id"])
    set_auth_cookies(response, user["_id"], email)
    res_data = public_user(user)
    res_data["access_token"] = access_token
    res_data["refresh_token"] = refresh_token
    return res_data


@api_router.post("/auth/logout")
async def logout(response: Response):
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/")
    return {"message": "Logged out"}


@api_router.get("/auth/me")
async def me(user: dict = Depends(get_current_user)):
    return public_user(user)


@api_router.post("/auth/refresh")
async def refresh(request: Request, response: Response):
    token = request.cookies.get("refresh_token")
    if not token:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
    if not token:
        raise HTTPException(401, "No refresh token")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(401, "Invalid token type")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid refresh token")
    user = await db.users.find_one({"_id": payload["sub"]})
    if not user:
        raise HTTPException(401, "User not found")
    new_access = create_access_token(user["_id"], user["email"])
    response.set_cookie("access_token", new_access, httponly=True, secure=IS_PROD, samesite="none" if IS_PROD else "lax", max_age=900, path="/")
    return {
        "message": "refreshed",
        "access_token": new_access,
        "refresh_token": token
    }


@api_router.post("/auth/forgot-password")
async def forgot_password(body: ForgotIn):
    email = body.email.lower()
    user = await db.users.find_one({"email": email})
    result = {"message": "If this email exists, a reset link has been generated."}
    if user:
        token = secrets.token_urlsafe(32)
        await db.password_reset_tokens.insert_one({
            "token": token, "email": email, "used": False,
            "expires_at": utcnow() + timedelta(hours=1), "created_at": utcnow(),
        })
        link = f"{os.environ.get('FRONTEND_URL', '')}/reset-password?token={token}"
        logger.info(f"Password reset link for {email}: {link}")
        result["dev_reset_link"] = link
    return result


@api_router.post("/auth/reset-password")
async def reset_password(body: ResetIn):
    doc = await db.password_reset_tokens.find_one({"token": body.token, "used": False})
    if not doc or doc["expires_at"] < utcnow():
        raise HTTPException(400, "Reset link is invalid or expired")
    await db.users.update_one({"email": doc["email"]}, {"$set": {"password_hash": hash_password(body.password), "auth_provider": "email"}})
    await db.password_reset_tokens.update_one({"_id": doc["_id"]}, {"$set": {"used": True}})
    return {"message": "Password updated. You can now log in."}


# ---------- Profile ----------

def load_rag_documents() -> list[dict]:
    with Path(__file__).with_name("knowledge_base.json").open(encoding="utf-8") as file:
        documents = json.load(file)
    for document in documents:
        document["keywords"] = set(document.get("keywords", []))
    return documents


RAG_DOCUMENTS = load_rag_documents()


def rag_tokens(text: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9-]+", text.lower()) if len(token) > 2}


def retrieve_rag_documents(question: str, limit: int = 3) -> list[dict]:
    tokens = rag_tokens(question)
    ranked = []
    for document in RAG_DOCUMENTS:
        score = len(tokens & document["keywords"])
        if score:
            ranked.append((score, document))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return [document for _, document in ranked[:limit]]


def grounded_rag_fallback(documents: list[dict]) -> str:
    return " ".join(document["content"] for document in documents)


async def call_rag_llm(question: str, documents: list[dict]) -> str:
    from emergentintegrations.llm.chat import LlmChat, UserMessage, TextDelta, StreamDone  # pyright: ignore[reportMissingImports]
    context = "\n\n".join(f"[{document['title']}]\n{document['content']}" for document in documents)
    chat = LlmChat(
        api_key=os.environ["EMERGENT_LLM_KEY"],
        session_id=f"rag-{uuid.uuid4()}",
        system_message=(
            "You are the Travel OS product help assistant. Answer only from the supplied Travel OS documents. "
            "Do not invent policies, capabilities, prices, live availability, or guarantees. If the documents do not answer the question, "
            "say that you do not have enough information. Keep the answer concise and practical."
        ),
    ).with_model("anthropic", "claude-sonnet-4-6")
    chunks = []
    prompt = f"Travel OS documents:\n{context}\n\nUser question: {question}"
    async for event in chat.stream_message(UserMessage(text=prompt)):
        if isinstance(event, TextDelta):
            chunks.append(event.content)
        elif isinstance(event, StreamDone):
            break
    return "".join(chunks).strip()


@api_router.post("/rag/ask")
async def ask_rag(body: RAGQuestionIn, user: dict = Depends(get_current_user)):
    documents = retrieve_rag_documents(body.question)
    if not documents:
        return {
            "answer": "I do not have enough information in the Travel OS help documents to answer that.",
            "sources": [],
        }

    answer = None
    if os.environ.get("EMERGENT_LLM_KEY"):
        try:
            answer = await asyncio.wait_for(call_rag_llm(body.question, documents), timeout=60)
        except Exception as error:
            logger.warning(f"RAG response failed; using grounded fallback: {error}")
    answer = answer or grounded_rag_fallback(documents)
    return {
        "answer": answer,
        "sources": [{"id": document["id"], "title": document["title"]} for document in documents],
    }

@api_router.get("/profile")
async def get_profile(user: dict = Depends(get_current_user)):
    profile = await db.profiles.find_one({"user_id": user["_id"]})
    if not profile:
        p = Profile(user_id=user["_id"])
        await db.profiles.insert_one(p.to_mongo())
        profile = p.to_mongo()
    past_trips = await db.trips.count_documents({"user_id": user["_id"], "deleted_at": None})
    profile = dict(profile)
    profile["id"] = str(profile.pop("_id"))
    profile["past_trips"] = past_trips
    profile["name"] = user["name"]
    profile["email"] = user["email"]
    return profile


@api_router.put("/profile")
async def update_profile(body: ProfileIn, user: dict = Depends(get_current_user)):
    data = body.model_dump(exclude_none=True)
    name = data.pop("name", None)
    if name:
        await db.users.update_one({"_id": user["_id"]}, {"$set": {"name": name}})
    data["updated_at"] = utcnow()
    await db.profiles.update_one({"user_id": user["_id"]}, {"$set": data}, upsert=True)
    return await get_profile(user)


# ---------- AI itinerary ----------

COVERS = {
    "tokyo": "https://images.unsplash.com/photo-1513407030348-c983a97b98d8?crop=entropy&cs=srgb&fm=jpg&ixid=M3w3NDk1Nzd8MHwxfHNlYXJjaHwxfHx0b2t5byUyMGNpdHklMjBuaWdodHxlbnwwfHx8fDE3ODYwMjU1OTJ8MA&ixlib=rb-4.1.0&q=85",
    "paris": "https://images.unsplash.com/photo-1585944285854-d06c019aaca3?crop=entropy&cs=srgb&fm=jpg&ixid=M3w3NTY2OTF8MHwxfHNlYXJjaHwxfHxwYXJpcyUyMGNhZmUlMjBkYXl8ZW58MHx8fHwxNzg2MDI1NTkyfDA&ixlib=rb-4.1.0&q=85",
    "beach": "https://images.unsplash.com/photo-1539367628448-4bc5c9d171c8?crop=entropy&cs=srgb&fm=jpg&ixid=M3w4NjAzOTB8MHwxfHNlYXJjaHwxfHxiZWF1dGlmdWwlMjBiZWFjaCUyMGJhbGl8ZW58MHx8fHwxNzg2MDI1NTkyfDA&ixlib=rb-4.1.0&q=85",
}


def pick_cover(destination: str) -> str:
    d = destination.lower()
    if any(k in d for k in ["tokyo", "japan", "osaka", "kyoto"]):
        return COVERS["tokyo"]
    if any(k in d for k in ["paris", "france", "europe", "london", "rome", "cafe"]):
        return COVERS["paris"]
    return COVERS["beach"]


def build_activity_image_candidates(title: str, location: str, destination: str, activity_type: str | None) -> list[str]:
    destination = (destination or "").strip()
    location = (location or "").strip()
    title = (title or "").strip()
    activity_type = (activity_type or "activity").lower()
    generic_titles = {"breakfast and check-in", "lunch break", "dinner and evening stroll", "main attraction visit", "market or neighborhood walk", "sunrise or early city walk"}

    parts = [p.strip() for p in re.split(r"[,;/]", location or destination) if p.strip()]
    if not parts and destination:
        parts = [destination]

    type_map = {
        "food": ["restaurant", "local food", "cafe", "street food"],
        "stay": ["hotel", "resort", "stay"],
        "transport": ["train station", "airport", "local transit"],
        "nature": ["scenic viewpoint", "nature landscape", "waterfall", "beach"],
        "nightlife": ["night market", "city nightlife", "bar street"],
        "culture": ["museum", "heritage site", "temple", "landmark"],
        "relaxation": ["beach", "park", "spa", "viewpoint"],
        "adventure": ["hiking trail", "adventure activity", "kayaking", "outdoor view"],
    }

    candidates: list[str] = []
    if title and title.lower() not in generic_titles:
        if location:
            candidates.extend([f"{title} in {location}", f"{location} {title}", f"{title} {location}"]) 
        if destination:
            candidates.extend([f"{title} in {destination}", f"{destination} {title}", f"{title} {destination}"])
    else:
        keywords = type_map.get(activity_type, ["attraction", "landmark", "city view"])
        for place in parts or [destination]:
            for kw in keywords:
                candidates.extend([
                    f"{kw} in {place}",
                    f"{place} {kw}",
                    f"{place} {kw} view",
                    f"{place} skyline",
                ])

    if destination and activity_type:
        candidates.append(f"{destination} {activity_type} destination")
        candidates.append(f"{destination} skyline")

    deduped: list[str] = []
    seen: set[str] = set()
    for item in candidates:
        clean = " ".join(item.split())
        key = clean.lower()
        if key and key not in seen:
            seen.add(key)
            deduped.append(clean)
    return deduped[:14]


def get_activity_image(query: str, cache: dict | None = None, used: set | None = None) -> str:
    """Return an image URL for a given activity/location query using Unsplash.
    - Requests multiple results and prefers images not present in `used` to avoid duplicates.
    - Uses a simple per-request cache mapping query->url to reduce API calls.
    - Falls back to `pick_cover` when no key or no suitable image found.
    """
    try:
        key = os.environ.get("UNSPLASH_ACCESS_KEY")
        q = (query or "").strip()
        if not q:
            return pick_cover(q)
        cache = cache or {}
        used = used or set()
        k = q.lower()

        # If we have a cached url that's not yet used, return it
        if k in cache and cache[k] not in used:
            img = cache[k]
            used.add(img)
            return img

        if not key:
            # no key configured — fallback (cache since we won't call API)
            url = pick_cover(q)
            cache[k] = url
            used.add(url)
            return url

        url_base = "https://api.unsplash.com/search/photos"
        try:
            # ask for multiple results so we can pick one not already used
            r = requests.get(url_base, params={"query": q, "per_page": 6}, headers={"Authorization": f"Client-ID {key}"}, timeout=8)
            if r.status_code == 200:
                j = r.json()
                results = j.get("results", [])
                for res in results:
                    img = (res.get("urls", {}).get("small") or res.get("urls", {}).get("regular"))
                    if not img:
                        continue
                    if img in used:
                        continue
                    if img in COVERS.values():
                        # prefer non-generic images
                        continue
                    # accept this candidate
                    cache[k] = img
                    used.add(img)
                    return img
                # if we couldn't find a non-used/non-generic image, try again with the first available
                for res in results:
                    img = (res.get("urls", {}).get("small") or res.get("urls", {}).get("regular"))
                    if not img:
                        continue
                    if img in used:
                        continue
                    cache[k] = img
                    used.add(img)
                    return img
        except requests.RequestException:
            pass

        # fallback when API call happened but returned no suitable images — don't cache the generic cover
        url = pick_cover(q)
        used.add(url)
        return url
    except Exception:
        return pick_cover(query)


def generate_local_itinerary(destination: str, start_date: str, end_date: str, budget: float, currency: str, people_count: int, interests: List[str]) -> dict:
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    total_days = (end - start).days + 1
    day_topics = [
        "Arrival and local highlights",
        "Scenic exploration",
        "Food and culture",
        "Relaxed discovery",
        "Adventure and viewpoints",
    ]
    interest_focus = interests[0].lower() if interests else "sightseeing"
    summary = (
        f"A practical {total_days}-day trip to {destination} focused on {interest_focus} and a balanced local experience. "
        f"Designed for {people_count} travellers within a total budget of {currency}{budget:,.0f}."
    )

    daily_templates = [
        [("09:00", "Breakfast and check-in", "Start the trip with a relaxed breakfast and get oriented."), ("11:00", "Main attraction visit", "Visit a well-known local spot and spend time exploring."), ("14:00", "Lunch break", "Enjoy a local meal and recharge."), ("16:00", "Market or neighborhood walk", "Walk through a lively area to experience the city atmosphere."), ("19:00", "Dinner and evening stroll", "End the day with dinner and a calm evening walk.")],
        [("08:30", "Sunrise or early city walk", "Start early to make the most of the day."), ("10:30", "Museum or cultural stop", "Visit a museum, temple, fort, or cultural site."), ("13:00", "Lunch at a local favorite", "Try a regional dish at a popular restaurant."), ("15:30", "Scenic stop or viewpoint", "Take in a scenic view or leisure stop."), ("18:30", "Dinner and unwind", "Wrap up with a relaxed dinner." )],
        [("09:30", "Morning coffee and planning", "Ease into the day and review the route."), ("11:30", "Signature experience", "Do one standout activity that fits the destination."), ("14:00", "Lunch", "Take a midday break with a simple meal."), ("16:00", "Shopping or local crafts", "Browse local shops or crafts."), ("20:00", "Dinner or street food", "Finish with a casual meal and local flavors.")],
    ]

    days = []
    for index in range(total_days):
        day_date = (start + timedelta(days=index)).strftime("%Y-%m-%d")
        templates = daily_templates[index % len(daily_templates)]
        activities = []
        for time, title, description in templates:
            if "Food" in interest_focus or "food" in interest_focus:
                activity_type = "food"
            elif "adventure" in interest_focus:
                activity_type = "adventure"
            elif "culture" in interest_focus:
                activity_type = "culture"
            elif "relax" in interest_focus:
                activity_type = "relaxation"
            else:
                activity_type = "activity"
            activities.append({
                "time": time,
                "title": title,
                "description": description,
                "type": activity_type,
                "estimated_cost": round(max(budget / max(total_days * 4, 1) / 2, 150), 0),
                "location": f"{destination}",
            })
        days.append({
            "day_number": index + 1,
            "date": day_date,
            "title": day_topics[index % len(day_topics)],
            "activities": activities,
            "estimated_cost": round(max(budget / max(total_days, 1), 0), 0),
        })

    stay = round(budget * 0.35, 0)
    food = round(budget * 0.25, 0)
    transport = round(budget * 0.15, 0)
    activities_cost = round(budget * 0.20, 0)
    misc = round(max(budget - (stay + food + transport + activities_cost), 0), 0)

    hotels = [
        {
            "name": f"{destination} Grand Stay",
            "area": destination,
            "price_per_night": round(stay / max(total_days, 1), 0),
            "rating": 4.4,
            "amenities": ["Wi-Fi", "Breakfast", "Air conditioning"],
            "description": "Comfortable central stay with easy access to key attractions.",
        },
        {
            "name": f"{destination} Comfort Inn",
            "area": destination,
            "price_per_night": round(stay / max(total_days, 1) * 0.8, 0),
            "rating": 4.1,
            "amenities": ["Wi-Fi", "Parking", "Room service"],
            "description": "A practical option for travellers who want convenience and value.",
        },
    ]

    restaurants = [
        {
            "name": f"{destination} Local Kitchen",
            "cuisine": "Regional",
            "price_level": 2,
            "rating": 4.5,
            "veg_friendly": True,
            "description": "Popular for local dishes and dependable vegetarian choices.",
        },
        {
            "name": f"{destination} Street Bites",
            "cuisine": "Street food",
            "price_level": 1,
            "rating": 4.2,
            "veg_friendly": True,
            "description": "Casual meals and snacks that are easy on the budget.",
        },
    ]

    return {
        "title": f"{destination} getaway",
        "summary": summary,
        "days": days,
        "hotels": hotels,
        "restaurants": restaurants,
        "cost_breakdown": {
            "stay": stay,
            "food": food,
            "transport": transport,
            "activities": activities_cost,
            "misc": misc,
        },
        "tips": [
            "Keep some cash handy for local shops and small vendors.",
            "Start early to avoid the hottest part of the day.",
            "Leave a little buffer in the budget for spontaneous stops.",
        ],
    }


async def call_llm(prompt: str) -> str:
    from emergentintegrations.llm.chat import LlmChat, UserMessage, TextDelta, StreamDone  # pyright: ignore[reportMissingImports]
    chat = LlmChat(
        api_key=os.environ["EMERGENT_LLM_KEY"],
        session_id=f"plan-{uuid.uuid4()}",
        system_message="You are an expert travel planner. You respond ONLY with valid JSON — no markdown, no commentary.",
    ).with_model("anthropic", "claude-sonnet-4-6")
    chunks = []

    async def consume():
        async for ev in chat.stream_message(UserMessage(text=prompt)):
            if isinstance(ev, TextDelta):
                chunks.append(ev.content)
            elif isinstance(ev, StreamDone):
                break

    await asyncio.wait_for(consume(), timeout=180)
    return "".join(chunks)


def parse_itinerary_json(text: str) -> dict:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(json)?", "", cleaned).strip()
    cleaned = re.sub(r"```$", "", cleaned).strip()
    data = json.loads(cleaned)
    if not isinstance(data.get("days"), list) or not data["days"]:
        raise ValueError("Missing days in itinerary")
    return data


@api_router.post("/trips/plan")
async def plan_trip(body: PlanRequest, user: dict = Depends(get_current_user)):
    try:
        start = datetime.strptime(body.start_date, "%Y-%m-%d")
        end = datetime.strptime(body.end_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(400, "Dates must be in YYYY-MM-DD format")
    nights = (end - start).days
    if nights < 0:
        raise HTTPException(400, "End date must be after start date")
    if nights > 29:
        raise HTTPException(400, "Trips longer than 30 days are not supported yet")

    interests = ", ".join(body.interests) if body.interests else "general sightseeing"
    prompt = f"""Plan a {nights + 1}-day trip to {body.destination} for {body.people_count} people, from {body.start_date} to {body.end_date}.
Total budget: {body.currency}{body.budget:,.0f} for the whole group. Traveller interests: {interests}.

Return ONLY a JSON object with this exact schema:
{{
  "title": "short catchy trip title",
  "summary": "2-3 sentence overview",
  "days": [
    {{
      "day_number": 1,
      "date": "{body.start_date}",
      "title": "theme of the day",
      "activities": [
        {{"time": "09:00", "title": "...", "description": "1-2 sentences", "type": "food|stay|transport|activity|nature|nightlife|culture|relaxation|adventure", "estimated_cost": 0, "location": "place name, {body.destination}"}}
      ],
      "estimated_cost": 0
    }}
  ],
  "hotels": [{{"name": "...", "area": "...", "price_per_night": 0, "rating": 4.2, "amenities": ["..."], "description": "1 sentence"}}],
  "restaurants": [{{"name": "...", "cuisine": "...", "price_level": 1, "rating": 4.3, "veg_friendly": true, "description": "1 sentence"}}],
  "cost_breakdown": {{"stay": 0, "food": 0, "transport": 0, "activities": 0, "misc": 0}},
  "tips": ["practical tip 1", "tip 2", "tip 3"]
}}

Rules:
- Include one entry per day for ALL {nights + 1} days, each with 4-6 activities with realistic times.
- All costs are per group totals in {body.currency}, realistic for {body.destination}, and the sum of cost_breakdown must fit within the budget of {body.currency}{body.budget:,.0f}.
- Include 3-5 hotels across price ranges and 4-6 restaurants matching the interests (veg-friendly options if food is an interest).
- Use real, well-known places in {body.destination} wherever possible."""

    itinerary = None
    last_error = None
    for attempt in range(2):
        try:
            raw = await call_llm(prompt)
            itinerary = parse_itinerary_json(raw)
            break
        except Exception as e:
            last_error = e
            logger.warning(f"AI itinerary attempt {attempt + 1} failed: {e}")
    if itinerary is None:
        logger.warning(f"Using local itinerary fallback after LLM failure: {last_error}")
        itinerary = generate_local_itinerary(body.destination, body.start_date, body.end_date, body.budget, body.currency, body.people_count, body.interests)

    # Enrich activities with image URLs (per-request cache to avoid duplicate Unsplash calls)
    try:
        _img_cache = {}
        _used_imgs = set()
        GENERIC_TITLES = {"breakfast and check-in", "lunch break", "dinner and evening stroll", "main attraction visit", "market or neighborhood walk", "sunrise or early city walk"}
        for d in itinerary.get("days", []):
            for a in d.get("activities", []):
                title = (a.get("title") or "").strip()
                location = (a.get("location") or "").strip()
                dest = (body.destination or "").strip()
                low_title = title.lower()

                # Try a set of locality-focused queries first (increase chance of destination-relevant images)
                primary_q = location or dest
                img_url = None
                if primary_q:
                    # split comma/semicolon-separated place strings into tokens and try each token first
                    parts = [p.strip() for p in re.split('[,;/]', primary_q) if p.strip()]
                    variants = []
                    for p in parts:
                        variants.extend([f"{p} skyline", f"{p} landmark", f"{p} landscape", f"{p} city", p])
                    # finally try the full primary_q as-is
                    variants.append(primary_q)
                    for v in variants:
                        try:
                            candidate = get_activity_image(v, _img_cache, _used_imgs)
                            if candidate and candidate not in COVERS.values():
                                img_url = candidate
                                break
                            # if candidate is a cover, keep searching variants
                        except Exception:
                            continue

                # If no locality image found, try richer queries combining title, type and tokens
                if not img_url:
                    tried = set()
                    candidates = build_activity_image_candidates(title, location, dest, a.get("type"))

                    parts_full = [title, location, dest]
                    combined = " ".join([p for p in parts_full if p]).strip()
                    if combined:
                        candidates.append(combined)

                    # try candidates in order
                    for q in candidates:
                        qkey = q.lower()
                        if qkey in tried:
                            continue
                        tried.add(qkey)
                        try:
                            candidate = get_activity_image(q, _img_cache, _used_imgs)
                            if candidate and candidate not in COVERS.values():
                                img_url = candidate
                                break
                        except Exception:
                            continue

                chosen = img_url or pick_cover(body.destination)
                # Debug logs intentionally kept concise to aid troubleshooting without flooding the server logs.
                try:
                    print(f"DEBUG image selection: title={title!r} location={location!r} dest={dest!r} img_url={img_url!r} chosen={chosen!r}")
                except Exception:
                    pass
                if chosen in COVERS.values():
                    for alt in COVERS.values():
                        if alt not in _used_imgs:
                            chosen = alt
                            break
                a["image_url"] = chosen
                _used_imgs.add(a["image_url"])
    except Exception:
        # don't let image enrichment block itinerary creation
        pass

    # Prefer a destination-local cover: use first activity image if available
    cover_img = None
    try:
        first_day = itinerary.get("days", [])[0] if itinerary.get("days") else None
        if first_day:
            first_act = first_day.get("activities", [])[0] if first_day.get("activities") else None
            if first_act:
                cover_img = first_act.get("image_url")
    except Exception:
        cover_img = None

    trip = Trip(
        user_id=user["_id"],
        title=itinerary.get("title") or f"Trip to {body.destination}",
        destination=body.destination,
        start_date=body.start_date,
        end_date=body.end_date,
        budget=body.budget,
        currency=body.currency,
        people_count=body.people_count,
        interests=body.interests,
        status="planned",
        cover_image=cover_img or pick_cover(body.destination),
        itinerary=itinerary,
    )
    await db.trips.insert_one(trip.to_mongo())
    result = trip.model_dump()
    return result


def local_refine_itinerary(itinerary: dict, instruction: str) -> dict:
    refined = json.loads(json.dumps(itinerary))
    request = instruction.lower()
    if any(word in request for word in ("cheaper", "cheapest", "budget")):
        for day in refined.get("days", []):
            day["estimated_cost"] = round(float(day.get("estimated_cost", 0)) * 0.85, 2)
            for activity in day.get("activities", []):
                activity["estimated_cost"] = round(float(activity.get("estimated_cost", 0)) * 0.85, 2)
        breakdown = refined.get("cost_breakdown", {})
        refined["cost_breakdown"] = {key: round(float(value) * 0.85, 2) for key, value in breakdown.items()}
        refined.setdefault("tips", []).append("Choose local transport and flexible meal options to protect the budget.")
    if "adventure" in request:
        for day in refined.get("days", []):
            for activity in day.get("activities", []):
                if activity.get("type") in ("activity", "nature"):
                    activity["type"] = "adventure"
                    break
    if any(word in request for word in ("family", "family-friendly", "family friendly")):
        for day in refined.get("days", []):
            day["activities"] = [activity for activity in day.get("activities", []) if activity.get("type") != "nightlife"]
    if any(word in request for word in ("peaceful", "relaxing", "relaxation")):
        for day in refined.get("days", []):
            for activity in day.get("activities", []):
                if activity.get("type") in ("activity", "nightlife"):
                    activity["type"] = "relaxation"
    return refined


@api_router.post("/trips/{trip_id}/refine")
async def refine_trip(trip_id: str, body: RefineRequest, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    itinerary = trip.get("itinerary") or {}
    if not isinstance(itinerary.get("days"), list) or not itinerary["days"]:
        raise HTTPException(400, "Trip does not contain a refinable itinerary")

    prompt = f"""Refine this existing Travel OS itinerary according to the user's instruction.
User instruction: {body.instruction}
Return only valid JSON. Preserve the existing schema and day dates. Do not invent booking confirmations.
Existing itinerary:
{json.dumps(itinerary, ensure_ascii=False)}"""
    refined = None
    if os.environ.get("EMERGENT_LLM_KEY"):
        try:
            refined = parse_itinerary_json(await asyncio.wait_for(call_llm(prompt), timeout=180))
        except Exception as error:
            logger.warning(f"AI refinement failed; using local refinement: {error}")
    refined = refined or local_refine_itinerary(itinerary, body.instruction)
    await db.trips.update_one({"_id": trip_id}, {"$set": {"itinerary": refined, "updated_at": utcnow()}})
    return trip_out(await db.trips.find_one({"_id": trip_id}))


# ---------- Trips ----------

async def get_owned_trip(trip_id: str, user: dict) -> dict:
    trip = await db.trips.find_one({"_id": trip_id, "user_id": user["_id"], "deleted_at": None})
    if not trip:
        raise HTTPException(404, "Trip not found")
    return trip


def trip_out(doc: dict) -> dict:
    doc = dict(doc)
    doc["id"] = str(doc.pop("_id"))
    return doc


@api_router.get("/trips")
async def list_trips(user: dict = Depends(get_current_user), page: int = Query(1, ge=1), limit: int = Query(12, ge=1, le=50)):
    q = {"user_id": user["_id"], "deleted_at": None}
    total = await db.trips.count_documents(q)
    cursor = db.trips.find(q).sort("created_at", -1).skip((page - 1) * limit).limit(limit)
    items = [trip_out(t) async for t in cursor]
    return {"items": items, "total": total, "page": page, "limit": limit}


@api_router.get("/trips/deleted")
async def list_deleted_trips(user: dict = Depends(get_current_user)):
    cutoff = utcnow() - timedelta(days=30)
    cursor = db.trips.find({"user_id": user["_id"], "deleted_at": {"$ne": None, "$gte": cutoff}}).sort("deleted_at", -1)
    items = [trip_out(trip) async for trip in cursor]
    return {"items": items}


@api_router.get("/trips/shared/{token}")
async def get_shared_trip(token: str):
    trip = await db.trips.find_one({"share_token": token, "deleted_at": None})
    if not trip:
        raise HTTPException(404, "Shared trip not found or link expired")
    out = trip_out(trip)
    owner = await db.users.find_one({"_id": trip["user_id"]})
    out["shared_by"] = owner["name"] if owner else "A traveller"
    return out


@api_router.get("/trips/{trip_id}")
async def get_trip(trip_id: str, user: dict = Depends(get_current_user)):
    return trip_out(await get_owned_trip(trip_id, user))


@api_router.get("/trips/{trip_id}/weather")
async def trip_weather(trip_id: str, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    itinerary = trip.get("itinerary") or {}
    days = itinerary.get("days", [])
    dest = trip.get("destination", "")
    api_key = os.environ.get("OPENWEATHER_API_KEY")
    results = {}
    if not api_key:
        # No key configured — return nulls
        for d in days:
            results[d.get("date")] = None
        return results

    # Resolve destination to coordinates using OpenWeather geocoding where possible, then fetch 5-day forecast (3-hour steps)
    try:
        # Try geocoding first (handles comma-separated or ambiguous names)
        geo = None
        try:
            g = requests.get("http://api.openweathermap.org/geo/1.0/direct", params={"q": dest, "limit": 1, "appid": api_key}, timeout=8)
            if g.status_code == 200:
                gj = g.json()
                if isinstance(gj, list) and gj:
                    geo = gj[0]
        except requests.RequestException:
            geo = None

        forecast_params = {"appid": api_key, "units": "metric"}
        if geo and "lat" in geo and "lon" in geo:
            forecast_url = "https://api.openweathermap.org/data/2.5/forecast"
            forecast_params.update({"lat": geo["lat"], "lon": geo["lon"]})
            r = requests.get(forecast_url, params=forecast_params, timeout=10)
        else:
            # fallback to using the destination string as a city query
            r = requests.get("https://api.openweathermap.org/data/2.5/forecast", params={"q": dest, **forecast_params}, timeout=10)

        if r.status_code != 200:
            for d in days:
                results[d.get("date")] = None
            return results
        data = r.json()
        forecasts = data.get("list", [])
        now = datetime.now().date()
        for d in days:
            dstr = d.get("date")
            try:
                ddate = datetime.strptime(dstr, "%Y-%m-%d").date()
            except Exception:
                results[dstr] = None
                continue
            delta = (ddate - now).days
            if delta < 0 or delta > 5:
                results[dstr] = None
                continue
            matched = None
            for f in forecasts:
                fdt = datetime.fromtimestamp(f.get("dt"))
                if fdt.date() == ddate:
                    matched = f
                    break
            if not matched:
                results[dstr] = None
                continue
            weather = matched.get("weather", [{}])[0]
            main = matched.get("main", {})
            wmain = weather.get("main", "")
            # Map to emoji
            emoji = "🌤️"
            if wmain == "Clear":
                emoji = "☀️"
            elif wmain == "Clouds":
                emoji = "☁️"
            elif wmain in ("Rain", "Drizzle"):
                emoji = "🌧️"
            elif wmain == "Snow":
                emoji = "❄️"
            elif wmain == "Thunderstorm":
                emoji = "⛈️"
            temp = main.get("temp")
            results[dstr] = {"emoji": emoji, "temp": round(temp) if temp is not None else None, "desc": weather.get("description")}
        return results
    except requests.RequestException:
        for d in days:
            results[d.get("date")] = None
        return results


@api_router.put("/trips/{trip_id}")
async def update_trip(trip_id: str, body: TripUpdate, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    data = {k: v for k, v in body.model_dump().items() if v is not None}
    data["updated_at"] = utcnow()
    await db.trips.update_one({"_id": trip_id}, {"$set": data})
    return trip_out(await db.trips.find_one({"_id": trip_id}))


@api_router.put("/trips/{trip_id}/itinerary")
async def update_itinerary(trip_id: str, body: ItineraryUpdate, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    if not isinstance(body.itinerary.get("days"), list):
        raise HTTPException(400, "Itinerary must contain a days list")
    await db.trips.update_one({"_id": trip_id}, {"$set": {"itinerary": body.itinerary, "updated_at": utcnow()}})
    return trip_out(await db.trips.find_one({"_id": trip_id}))


@api_router.delete("/trips/{trip_id}")
async def delete_trip(trip_id: str, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    await db.trips.update_one({"_id": trip_id}, {"$set": {"deleted_at": utcnow()}})
    return {"message": "Trip deleted. It can be restored within 30 days."}


@api_router.post("/trips/{trip_id}/restore")
async def restore_trip(trip_id: str, user: dict = Depends(get_current_user)):
    trip = await db.trips.find_one({"_id": trip_id, "user_id": user["_id"]})
    if not trip or not trip.get("deleted_at"):
        raise HTTPException(404, "Deleted trip not found")
    deleted_at = trip["deleted_at"]
    if deleted_at.tzinfo is None:
        deleted_at = deleted_at.replace(tzinfo=timezone.utc)
    if utcnow() - deleted_at > timedelta(days=30):
        raise HTTPException(410, "Trip restore window has expired")
    await db.trips.update_one({"_id": trip_id, "user_id": user["_id"]}, {"$set": {"deleted_at": None, "updated_at": utcnow()}})
    return trip_out(await db.trips.find_one({"_id": trip_id, "user_id": user["_id"]}))


@api_router.post("/trips/{trip_id}/duplicate")
async def duplicate_trip(trip_id: str, user: dict = Depends(get_current_user)):
    src = await get_owned_trip(trip_id, user)
    src.pop("_id")
    src["title"] = f"{src['title']} (Copy)"
    src["share_token"] = None
    src["created_at"] = utcnow()
    src["updated_at"] = utcnow()
    copy = Trip(**src)
    await db.trips.insert_one(copy.to_mongo())
    return copy.model_dump()


@api_router.post("/trips/{trip_id}/share")
async def share_trip(trip_id: str, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    token = trip.get("share_token") or secrets.token_urlsafe(16)
    if not trip.get("share_token"):
        await db.trips.update_one({"_id": trip_id}, {"$set": {"share_token": token}})
    return {"share_token": token}


# ---------- Favorites ----------

@api_router.get("/trips/{trip_id}/favorites")
async def list_favorites(trip_id: str, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    favs = await db.favorites.find({"user_id": user["_id"], "trip_id": trip_id}).to_list(200)
    for f in favs:
        f["id"] = str(f.pop("_id"))
    return favs


@api_router.post("/trips/{trip_id}/favorites")
async def add_favorite(trip_id: str, body: FavoriteIn, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    if body.type not in ("hotel", "restaurant"):
        raise HTTPException(400, "Type must be hotel or restaurant")
    existing = await db.favorites.find_one({"user_id": user["_id"], "trip_id": trip_id, "type": body.type, "name": body.name})
    if existing:
        existing["id"] = str(existing.pop("_id"))
        return existing
    fav = Favorite(user_id=user["_id"], trip_id=trip_id, **body.model_dump())
    await db.favorites.insert_one(fav.to_mongo())
    return fav.model_dump()


@api_router.delete("/favorites/{fav_id}")
async def delete_favorite(fav_id: str, user: dict = Depends(get_current_user)):
    res = await db.favorites.delete_one({"_id": fav_id, "user_id": user["_id"]})
    if res.deleted_count == 0:
        raise HTTPException(404, "Favorite not found")
    return {"message": "Removed from favorites"}


# ---------- Expenses ----------

EXPENSE_CATEGORIES = ["food", "stay", "transport", "activities", "misc"]


@api_router.get("/trips/{trip_id}/expenses")
async def list_expenses(trip_id: str, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    items = await db.expenses.find({"trip_id": trip_id}).sort("created_at", -1).to_list(500)
    for e in items:
        e["id"] = str(e.pop("_id"))
    return items


@api_router.post("/trips/{trip_id}/expenses")
async def add_expense(trip_id: str, body: ExpenseIn, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    if body.category not in EXPENSE_CATEGORIES:
        raise HTTPException(400, f"Category must be one of {EXPENSE_CATEGORIES}")
    if body.client_id:
        existing = await db.expenses.find_one({"trip_id": trip_id, "user_id": user["_id"], "client_id": body.client_id})
        if existing:
            existing["id"] = str(existing.pop("_id"))
            return existing
    exp = Expense(trip_id=trip_id, user_id=user["_id"], **body.model_dump())
    await db.expenses.insert_one(exp.to_mongo())
    return exp.model_dump()


@api_router.delete("/expenses/{expense_id}")
async def delete_expense(expense_id: str, user: dict = Depends(get_current_user)):
    res = await db.expenses.delete_one({"_id": expense_id, "user_id": user["_id"]})
    if res.deleted_count == 0:
        raise HTTPException(404, "Expense not found")
    return {"message": "Expense deleted"}


@api_router.put("/expenses/{expense_id}")
async def update_expense(expense_id: str, body: ExpenseUpdate, user: dict = Depends(get_current_user)):
    data = {key: value for key, value in body.model_dump().items() if value is not None}
    if "category" in data and data["category"] not in EXPENSE_CATEGORIES:
        raise HTTPException(400, f"Category must be one of {EXPENSE_CATEGORIES}")
    if not data:
        raise HTTPException(400, "At least one expense field is required")
    result = await db.expenses.update_one({"_id": expense_id, "user_id": user["_id"]}, {"$set": data})
    if result.matched_count == 0:
        raise HTTPException(404, "Expense not found")
    updated = await db.expenses.find_one({"_id": expense_id, "user_id": user["_id"]})
    updated["id"] = str(updated.pop("_id"))
    return updated


@api_router.get("/trips/{trip_id}/expenses/summary")
async def expense_summary(trip_id: str, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    pipeline = [
        {"$match": {"trip_id": trip_id}},
        {"$group": {"_id": "$category", "total": {"$sum": "$amount"}}},
    ]
    by_category = {row["_id"]: row["total"] for row in await db.expenses.aggregate(pipeline).to_list(10)}
    spent = sum(by_category.values())
    return {
        "budget": trip["budget"],
        "currency": trip.get("currency", "₹"),
        "spent": spent,
        "remaining": trip["budget"] - spent,
        "by_category": by_category,
    }


@api_router.get("/")
async def root():
    return {"message": "Travel OS API"}


app.include_router(api_router)

if not IS_PROD:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=CORS_ORIGINS or ["http://localhost:3000", "http://127.0.0.1:3000"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_credentials=True,
        allow_origins=CORS_ORIGINS or ["http://localhost:3000"],
        allow_methods=["*"],
        allow_headers=["*"],
    )


async def seed_admin():
    admin_email = os.environ["ADMIN_EMAIL"].lower()
    admin_password = os.environ["ADMIN_PASSWORD"]
    existing = await db.users.find_one({"email": admin_email})
    if existing is None:
        user = User(name="Aditya", email=admin_email, password_hash=hash_password(admin_password), role="admin", email_verified=True)
        await db.users.insert_one(user.to_mongo())
        await db.profiles.insert_one(Profile(user_id=user.id).to_mongo())
    elif existing.get("password_hash") and not verify_password(admin_password, existing["password_hash"]):
        await db.users.update_one({"email": admin_email}, {"$set": {"password_hash": hash_password(admin_password)}})


@app.on_event("startup")
async def startup():
    try:
        await db.command("ping")
    except Exception:
        logger.error(f"Could not connect to MongoDB at {mongo_url} - is MongoDB running?")
        return

    await db.users.create_index("email", unique=True)
    await db.password_reset_tokens.create_index("expires_at", expireAfterSeconds=0)
    await db.login_attempts.create_index("identifier")
    await db.trips.create_index([("user_id", 1), ("deleted_at", 1)])
    await db.trips.create_index("share_token")
    await db.expenses.create_index("trip_id")
    await seed_admin()


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
