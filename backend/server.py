from dotenv import load_dotenv
from pathlib import Path

load_dotenv(dotenv_path=Path(__file__).with_name(".env"))

import os
import re
import json
import uuid
import asyncio
import secrets
import hashlib
import logging
import math
import smtplib
from email.message import EmailMessage
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
MAX_TRIP_DAYS = 30

IS_PROD = os.environ.get("ENV", "development") == "production"
JWT_ALGORITHM = "HS256"
JWT_SECRET = os.environ["JWT_SECRET"]
CORS_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("CORS_ORIGINS", os.environ.get("FRONTEND_URL", "")).split(",")
    if origin.strip()
]


class PasswordResetDeliveryError(RuntimeError):
    pass


class SmtpPasswordResetProvider:
    def __init__(self):
        self.host = os.environ.get("SMTP_HOST", "").strip()
        try:
            self.port = int(os.environ.get("SMTP_PORT", "587"))
        except ValueError as error:
            raise PasswordResetDeliveryError("SMTP_PORT must be a valid integer") from error
        self.username = os.environ.get("SMTP_USERNAME", "").strip()
        self.password = os.environ.get("SMTP_PASSWORD", "")
        self.sender = os.environ.get("RESET_EMAIL_FROM", "").strip()
        if not all((self.host, self.username, self.password, self.sender)):
            raise PasswordResetDeliveryError("SMTP password reset delivery is not configured")

    async def send(self, recipient: str, link: str):
        message = EmailMessage()
        message["Subject"] = "Reset your Travel OS password"
        message["From"] = self.sender
        message["To"] = recipient
        message.set_content(
            "Use the following link to reset your Travel OS password. "
            "This link expires in one hour and can only be used once:\n\n"
            f"{link}"
        )

        def deliver():
            with smtplib.SMTP(self.host, self.port, timeout=10) as smtp:
                smtp.starttls()
                smtp.login(self.username, self.password)
                smtp.send_message(message)

        try:
            await asyncio.to_thread(deliver)
        except (OSError, smtplib.SMTPException) as error:
            raise PasswordResetDeliveryError("Unable to send password reset email") from error


def get_password_reset_provider():
    return SmtpPasswordResetProvider()

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


class NaturalPlanRequest(BaseModel):
    request: str = Field(min_length=10, max_length=1000)


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
    payload = {"sub": user_id, "jti": str(uuid.uuid4()), "exp": utcnow() + timedelta(days=7), "type": "refresh"}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


COOKIE_SAMESITE = "none" if IS_PROD else "lax"
COOKIE_SECURE = IS_PROD


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def issue_refresh_token(user_id: str) -> str:
    token = create_refresh_token(user_id)
    payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    await db.refresh_tokens.insert_one({
        "_id": payload["jti"],
        "token_hash": hash_refresh_token(token),
        "user_id": user_id,
        "expires_at": datetime.fromtimestamp(payload["exp"], timezone.utc),
        "revoked_at": None,
        "created_at": utcnow(),
    })
    return token


def set_auth_cookies(response: Response, access_token: str, refresh_token: str):
    response.set_cookie("access_token", access_token, httponly=True, secure=COOKIE_SECURE, samesite=COOKIE_SAMESITE, max_age=900, path="/")
    response.set_cookie("refresh_token", refresh_token, httponly=True, secure=COOKIE_SECURE, samesite=COOKIE_SAMESITE, max_age=604800, path="/")


def is_mobile_client(request: Request) -> bool:
    return request.headers.get("X-Client-Platform", "").lower() == "mobile"


def auth_response(user: dict, request: Request, access_token: str, refresh_token: str) -> dict:
    result = public_user(user)
    if is_mobile_client(request):
        result.update({"access_token": access_token, "refresh_token": refresh_token})
    return result


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
async def register(body: RegisterIn, request: Request, response: Response):
    email = body.email.lower()
    if await db.users.find_one({"email": email}):
        raise HTTPException(409, "An account with this email already exists")
    user = User(name=body.name.strip(), email=email, password_hash=hash_password(body.password))
    await db.users.insert_one(user.to_mongo())
    await db.profiles.insert_one(Profile(user_id=user.id).to_mongo())
    access_token = create_access_token(user.id, email)
    refresh_token = await issue_refresh_token(user.id)
    set_auth_cookies(response, access_token, refresh_token)
    return auth_response(user.to_mongo(), request, access_token, refresh_token)


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
    refresh_token = await issue_refresh_token(user["_id"])
    set_auth_cookies(response, access_token, refresh_token)
    return auth_response(user, request, access_token, refresh_token)


@api_router.post("/auth/google/session")
async def google_session(body: GoogleSessionIn, request: Request, response: Response):
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
    refresh_token = await issue_refresh_token(user["_id"])
    set_auth_cookies(response, access_token, refresh_token)
    return auth_response(user, request, access_token, refresh_token)


@api_router.post("/auth/google/token")
async def google_token(body: GoogleTokenIn, request: Request, response: Response):
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
    refresh_token = await issue_refresh_token(user["_id"])
    set_auth_cookies(response, access_token, refresh_token)
    return auth_response(user, request, access_token, refresh_token)


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
    stored = await db.refresh_tokens.find_one({"token_hash": hash_refresh_token(token), "user_id": user["_id"], "revoked_at": None})
    if not stored:
        raise HTTPException(401, "Refresh token has been revoked")
    await db.refresh_tokens.update_one({"_id": stored["_id"]}, {"$set": {"revoked_at": utcnow()}})
    new_access = create_access_token(user["_id"], user["email"])
    new_refresh = await issue_refresh_token(user["_id"])
    set_auth_cookies(response, new_access, new_refresh)
    result = {"message": "refreshed"}
    if request.headers.get("Authorization", "").startswith("Bearer ") or is_mobile_client(request):
        result.update({"access_token": new_access, "refresh_token": new_refresh})
    return result


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
        if IS_PROD:
            try:
                await get_password_reset_provider().send(email, link)
            except PasswordResetDeliveryError:
                await db.password_reset_tokens.delete_one({"token": token})
                logger.exception("Password reset delivery failed")
        else:
            logger.info("Development password reset link generated for %s", email)
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
            r = requests.get(url_base, params={"query": q, "per_page": 6}, headers={"Authorization": f"Client-ID {key}"}, timeout=3)
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

    attractions = [
        {
            "name": f"{destination} Heritage Walk",
            "description": "A flexible introduction to the destination's history and local character.",
            "category": "culture",
            "estimated_cost": round(activities_cost * 0.18, 0),
            "recommended_duration": "2-3 hours",
            "location": {"latitude": None, "longitude": None},
        },
        {
            "name": f"{destination} Scenic Viewpoint",
            "description": "A relaxed scenic stop suited to photography and an unhurried afternoon.",
            "category": "nature",
            "estimated_cost": round(activities_cost * 0.12, 0),
            "recommended_duration": "1-2 hours",
            "location": {"latitude": None, "longitude": None},
        },
    ]

    return {
        "title": f"{destination} getaway",
        "summary": summary,
        "days": days,
        "hotels": hotels,
        "restaurants": restaurants,
        "attractions": attractions,
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
    api_key = os.environ.get("EMERGENT_LLM_KEY", "").strip()
    if not api_key:
        raise RuntimeError("EMERGENT_LLM_KEY is not configured")

    from emergentintegrations.llm.chat import LlmChat, UserMessage, TextDelta, StreamDone  # pyright: ignore[reportMissingImports]
    chat = LlmChat(
        api_key=api_key,
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
    normalize_itinerary_days(data)
    return data


def safe_day_number(day: dict) -> Optional[int]:
    try:
        value = day.get("day_number")
        if value is None or isinstance(value, bool):
            return None
        return int(value)
    except (AttributeError, TypeError, ValueError):
        return None


def normalize_itinerary_days(itinerary: dict) -> dict:
    days = itinerary.get("days")
    if not isinstance(days, list):
        return itinerary
    for day in days:
        if not isinstance(day, dict):
            raise ValueError("Each itinerary day must be an object")
        day_number = safe_day_number(day)
        if day_number is None:
            raise ValueError("Each itinerary day must have a numeric day_number")
        day["day_number"] = day_number
    return itinerary


def validate_planned_itinerary(data: dict, expected_days: int, start_date: str, budget: float) -> dict:
    if not isinstance(data, dict):
        raise ValueError("Itinerary must be an object")
    for field in ("title", "summary", "days", "hotels", "restaurants", "attractions", "cost_breakdown", "tips"):
        if field not in data:
            raise ValueError(f"Itinerary is missing {field}")
    if not isinstance(data["title"], str) or not data["title"].strip():
        raise ValueError("Itinerary title is required")
    if not isinstance(data["summary"], str) or not data["summary"].strip():
        raise ValueError("Itinerary summary is required")
    if not isinstance(data["days"], list) or len(data["days"]) != expected_days:
        raise ValueError("Itinerary has an invalid number of days")

    start = datetime.strptime(start_date, "%Y-%m-%d")
    for index, day in enumerate(data["days"], start=1):
        if not isinstance(day, dict) or day.get("day_number") != index:
            raise ValueError("Itinerary day numbers must be sequential")
        expected_date = (start + timedelta(days=index - 1)).strftime("%Y-%m-%d")
        if day.get("date") != expected_date:
            raise ValueError("Itinerary dates do not match the requested trip")
        activities = day.get("activities")
        if not isinstance(activities, list) or not 1 <= len(activities) <= 8:
            raise ValueError("Each itinerary day must contain activities")
        titles = set()
        for activity in activities:
            if not isinstance(activity, dict) or not isinstance(activity.get("title"), str) or not activity["title"].strip():
                raise ValueError("Every activity needs a title")
            title = activity["title"].strip().lower()
            if title in titles:
                raise ValueError("Duplicate activities are not allowed on a day")
            titles.add(title)
            if not isinstance(activity.get("description"), str) or not activity["description"].strip():
                raise ValueError("Every activity needs a description")
            cost = activity.get("estimated_cost", 0)
            if isinstance(cost, bool) or not isinstance(cost, (int, float)) or not math.isfinite(float(cost)) or cost < 0:
                raise ValueError("Activity costs must be nonnegative numbers")

    for section in ("hotels", "restaurants", "attractions"):
        if not isinstance(data[section], list):
            raise ValueError(f"{section} must be a list")
        for item in data[section]:
            if not isinstance(item, dict) or not isinstance(item.get("name"), str) or not item["name"].strip():
                raise ValueError(f"Every {section[:-1]} needs a name")
            if "description" in item and item["description"] is not None and not isinstance(item["description"], str):
                raise ValueError(f"{section[:-1]} descriptions must be text")
            for number_field in ("price_per_night", "estimated_cost", "rating"):
                if number_field not in item or item[number_field] is None:
                    continue
                value = item[number_field]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)) or value < 0:
                    raise ValueError(f"{section[:-1]} {number_field} must be nonnegative")
            if item.get("rating") is not None and item["rating"] > 5:
                raise ValueError(f"{section[:-1]} rating cannot exceed 5")

    for attraction in data["attractions"]:
        location = attraction.setdefault("location", {})
        if not isinstance(location, dict):
            raise ValueError("Attraction location must be an object")
        for field in ("latitude", "longitude", "place_id", "address", "city", "country"):
            location.setdefault(field, None)

    breakdown = data["cost_breakdown"]
    if not isinstance(breakdown, dict):
        raise ValueError("Cost breakdown must be an object")
    total = 0.0
    for category, value in breakdown.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)) or value < 0:
            raise ValueError(f"Cost breakdown value for {category} must be nonnegative")
        total += float(value)
    if total > budget * 1.05:
        raise ValueError("Itinerary cost exceeds the requested budget")
    if not isinstance(data["tips"], list) or not all(isinstance(tip, str) and tip.strip() for tip in data["tips"]):
        raise ValueError("Itinerary tips must be text")
    return data


NUMBER_WORDS = {
    "one": 1, "a": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
}


def parse_natural_plan_request(text: str) -> PlanRequest:
    request = " ".join(text.strip().split())
    lowered = request.lower()
    duration_match = re.search(r"\b(\d{1,2})\s*[- ]?days?\b", lowered)
    if duration_match:
        duration = int(duration_match.group(1))
    elif re.search(r"\bweekend\b", lowered):
        duration = 2
    else:
        duration = None

    budget_match = re.search(
        r"(?:under|below|within|budget(?:\s+of)?|₹|rs\.?|inr|\$|usd|€|eur|£|gbp)\s*([0-9][0-9,]*(?:\.[0-9]+)?)",
        lowered,
    )
    budget = float(budget_match.group(1).replace(",", "")) if budget_match else None
    if "₹" in request or re.search(r"\b(?:rs\.?|inr)\b", lowered):
        currency = "₹"
    elif "$" in request or re.search(r"\busd\b", lowered):
        currency = "$"
    elif "€" in request or re.search(r"\beur\b", lowered):
        currency = "€"
    elif "£" in request or re.search(r"\bgbp\b", lowered):
        currency = "£"
    else:
        currency = "₹"

    people_match = re.search(r"\bfor\s+(\d{1,2})(?:\s+(?:people|persons|travellers|travelers))?\b", lowered)
    people_count = int(people_match.group(1)) if people_match else None
    if people_count is None:
        for word, value in NUMBER_WORDS.items():
            if re.search(rf"\bfor\s+{word}(?:\s+(?:people|persons|travellers|travelers))?\b", lowered):
                people_count = value
                break
    people_count = people_count or 1

    destination = None
    destination_match = re.search(
        r"\b(?:near|around|to|in)\s+([A-Za-z][A-Za-z .'-]{1,79}?)(?=\s+(?:under|below|within|for\s+\d|for\s+(?:one|two|three|four|five|six|seven|eight|nine|ten)|with|that|and\s+(?:i|we)|i\s+(?:like|love)|from)\b|[,.!?]|$)",
        request,
        re.IGNORECASE,
    )
    if destination_match:
        destination = destination_match.group(1).strip()

    if not destination:
        raise ValueError("Please include a destination, such as Goa or near Bangalore")
    if duration is None or not 1 <= duration <= MAX_TRIP_DAYS:
        raise ValueError("Please include a trip duration from 1 to 30 days")
    if budget is None or budget <= 0:
        raise ValueError("Please include a positive budget, such as under ₹12,000")
    if people_count > 30:
        raise ValueError("Travel groups can include at most 30 people")

    interest_terms = (
        "nature", "waterfalls", "adventure", "beach", "beaches", "mountains", "culture", "history",
        "food", "vegetarian", "vegan", "jain", "shopping", "nightlife", "relaxing", "peaceful", "photography",
    )
    interests = []
    for term in interest_terms:
        if re.search(rf"\b{re.escape(term)}\b", lowered) and term not in interests:
            interests.append(term)
    if any(term in interests for term in ("vegetarian", "vegan", "jain")) and "food" not in interests:
        interests.append("food")

    start_date = utcnow().date()
    explicit_start = re.search(r"\b(?:starting|from)\s+(\d{4}-\d{2}-\d{2})\b", lowered)
    if explicit_start:
        try:
            start_date = datetime.strptime(explicit_start.group(1), "%Y-%m-%d").date()
        except ValueError as error:
            raise ValueError("The start date must use YYYY-MM-DD format") from error
    end_date = start_date + timedelta(days=duration - 1)

    return PlanRequest(
        destination=destination,
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        budget=budget,
        currency=currency,
        people_count=people_count,
        interests=interests,
    )


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
        raise HTTPException(400, f"Trips longer than {MAX_TRIP_DAYS} days are not supported yet")

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
    "attractions": [{{"name": "...", "description": "1 sentence", "destination": "{body.destination}", "category": "nature|culture|adventure|shopping|wellness", "estimated_cost": 0, "recommended_duration": "2 hours", "image": null, "location": {{"latitude": null, "longitude": null}}}}],
  "cost_breakdown": {{"stay": 0, "food": 0, "transport": 0, "activities": 0, "misc": 0}},
  "tips": ["practical tip 1", "tip 2", "tip 3"]
}}

Rules:
- Include one entry per day for ALL {nights + 1} days, each with 4-6 activities with realistic times.
- All costs are per group totals in {body.currency}, realistic for {body.destination}, and the sum of cost_breakdown must fit within the budget of {body.currency}{body.budget:,.0f}.
- Include 3-5 hotels across price ranges and 4-6 restaurants matching the interests (veg-friendly options if food is an interest).
- Use real, well-known places in {body.destination} wherever possible."""

    llm_ready = bool(os.environ.get("EMERGENT_LLM_KEY", "").strip())
    itinerary = None
    last_error = None
    if llm_ready:
        for attempt in range(2):
            try:
                raw = await call_llm(prompt)
                itinerary = validate_planned_itinerary(parse_itinerary_json(raw), nights + 1, body.start_date, body.budget)
                break
            except Exception as e:
                last_error = e
                logger.warning(f"AI itinerary attempt {attempt + 1} failed: {e}")
    else:
        logger.info("EMERGENT_LLM_KEY missing; skipping remote AI generation and using local itinerary fallback")
    if itinerary is None:
        logger.warning(f"Using local itinerary fallback after LLM failure: {last_error}")
        itinerary = validate_planned_itinerary(
            generate_local_itinerary(body.destination, body.start_date, body.end_date, body.budget, body.currency, body.people_count, body.interests),
            nights + 1,
            body.start_date,
            body.budget,
        )

    itinerary.setdefault("attractions", [])

    # Enrich activities with image URLs (per-request cache to avoid duplicate Unsplash calls)
    try:
        _img_cache = {}
        _used_imgs = set()
        image_lookup_budget = 4
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
                        if image_lookup_budget <= 0:
                            break
                        try:
                            candidate = get_activity_image(v, _img_cache, _used_imgs)
                            image_lookup_budget -= 1
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
                        if image_lookup_budget <= 0:
                            break
                        qkey = q.lower()
                        if qkey in tried:
                            continue
                        tried.add(qkey)
                        try:
                            candidate = get_activity_image(q, _img_cache, _used_imgs)
                            image_lookup_budget -= 1
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


@api_router.post("/trips/plan/natural")
async def plan_trip_naturally(body: NaturalPlanRequest, user: dict = Depends(get_current_user)):
    try:
        structured = parse_natural_plan_request(body.request)
    except ValueError as error:
        raise HTTPException(422, str(error))
    return await plan_trip(structured, user)


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
async def list_trips(
    user: dict = Depends(get_current_user),
    page: int = Query(1, ge=1),
    limit: int = Query(12, ge=1, le=50),
    search: Optional[str] = Query(default=None, min_length=1, max_length=120),
):
    q = {"user_id": user["_id"], "deleted_at": None}
    if search and search.strip():
        pattern = re.escape(search.strip())
        q["$or"] = [
            {"title": {"$regex": pattern, "$options": "i"}},
            {"destination": {"$regex": pattern, "$options": "i"}},
        ]
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
    try:
        normalized_itinerary = normalize_itinerary_days(body.itinerary)
    except ValueError as error:
        raise HTTPException(400, str(error)) from error
    await db.trips.update_one({"_id": trip_id}, {"$set": {"itinerary": normalized_itinerary, "updated_at": utcnow()}})
    return trip_out(await db.trips.find_one({"_id": trip_id}))


def recalculate_itinerary_costs(itinerary: dict, removed_day: Optional[dict] = None) -> dict:
    updated = json.loads(json.dumps(itinerary))
    breakdown = {
        key: float(value)
        for key, value in (updated.get("cost_breakdown") or {}).items()
        if isinstance(value, (int, float)) and not isinstance(value, bool)
    }
    for day in updated.get("days", []):
        activities = day.get("activities") or []
        day["estimated_cost"] = round(sum(float(activity.get("estimated_cost", 0) or 0) for activity in activities), 2)

    if removed_day is not None:
        removed_categories = {"stay": 0.0, "food": 0.0, "transport": 0.0, "activities": 0.0}
        for activity in removed_day.get("activities") or []:
            category = activity.get("type")
            bucket = category if category in ("stay", "food", "transport") else "activities"
            removed_categories[bucket] += float(activity.get("estimated_cost", 0) or 0)
        for category, amount in removed_categories.items():
            if category in breakdown:
                breakdown[category] = round(max(0, breakdown[category] - amount), 2)

    updated["cost_breakdown"] = {key: round(value, 2) for key, value in breakdown.items()}
    updated["estimated_cost"] = round(sum(updated["cost_breakdown"].values()), 2)
    return updated


def itinerary_day_date(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y-%m-%d")
    except (TypeError, ValueError) as error:
        raise HTTPException(400, "Itinerary days must use YYYY-MM-DD dates") from error


@api_router.post("/trips/{trip_id}/itinerary/days")
async def add_itinerary_day(trip_id: str, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    itinerary = trip.get("itinerary") or {}
    days = itinerary.get("days")
    if not isinstance(days, list) or not days:
        raise HTTPException(400, "Trip does not contain an itinerary with at least one day")
    if len(days) >= MAX_TRIP_DAYS:
        raise HTTPException(400, f"Trips cannot contain more than {MAX_TRIP_DAYS} days")
    try:
        normalize_itinerary_days(itinerary)
    except ValueError as error:
        raise HTTPException(400, str(error)) from error

    last_date = itinerary_day_date(days[-1].get("date"))
    new_days = days + [{
        "day_number": len(days) + 1,
        "date": (last_date + timedelta(days=1)).strftime("%Y-%m-%d"),
        "title": f"Day {len(days) + 1}",
        "activities": [],
        "estimated_cost": 0,
    }]
    updated_itinerary = recalculate_itinerary_costs({**itinerary, "days": new_days})
    await db.trips.update_one({"_id": trip_id}, {"$set": {"itinerary": updated_itinerary, "updated_at": utcnow()}})
    return trip_out(await db.trips.find_one({"_id": trip_id}))


@api_router.delete("/trips/{trip_id}/itinerary/days/{day_number}")
async def remove_itinerary_day(trip_id: str, day_number: int, user: dict = Depends(get_current_user)):
    trip = await get_owned_trip(trip_id, user)
    itinerary = trip.get("itinerary") or {}
    days = itinerary.get("days")
    if not isinstance(days, list) or not days:
        raise HTTPException(400, "Trip does not contain an itinerary with at least one day")
    if len(days) == 1:
        raise HTTPException(400, "An itinerary must contain at least one day")
    try:
        normalize_itinerary_days(itinerary)
    except ValueError as error:
        raise HTTPException(400, str(error)) from error

    target_index = next((index for index, day in enumerate(days) if safe_day_number(day) == day_number), None)
    if target_index is None:
        raise HTTPException(404, "Itinerary day not found")
    removed_day = days[target_index]
    base_date = itinerary_day_date(days[0].get("date"))
    remaining_days = []
    for index, day in enumerate(days[:target_index] + days[target_index + 1:], start=1):
        updated_day = dict(day)
        updated_day["day_number"] = index
        updated_day["date"] = (base_date + timedelta(days=index - 1)).strftime("%Y-%m-%d")
        remaining_days.append(updated_day)

    updated_itinerary = recalculate_itinerary_costs({**itinerary, "days": remaining_days}, removed_day=removed_day)
    await db.trips.update_one({"_id": trip_id}, {"$set": {"itinerary": updated_itinerary, "updated_at": utcnow()}})
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


@api_router.get("/favorites")
async def list_all_favorites(
    favorite_type: Optional[str] = Query(default=None, alias="type"),
    user: dict = Depends(get_current_user),
):
    if favorite_type is not None and favorite_type not in ("hotel", "restaurant", "attraction"):
        raise HTTPException(400, "Type must be hotel, restaurant, or attraction")

    query = {"user_id": user["_id"]}
    if favorite_type:
        query["type"] = favorite_type
    favorites = await db.favorites.find(query).sort("created_at", -1).to_list(500)
    trip_ids = {favorite.get("trip_id") for favorite in favorites if favorite.get("trip_id")}
    trips = {}
    for trip_id in trip_ids:
        trip = await db.trips.find_one({"_id": trip_id, "user_id": user["_id"]})
        if trip:
            trips[trip_id] = trip

    result = []
    for favorite in favorites:
        trip = trips.get(favorite.get("trip_id"))
        favorite["id"] = str(favorite.pop("_id"))
        if trip:
            favorite["trip_title"] = trip.get("title")
            favorite["trip_destination"] = trip.get("destination")
        result.append(favorite)
    return result


@api_router.post("/trips/{trip_id}/favorites")
async def add_favorite(trip_id: str, body: FavoriteIn, user: dict = Depends(get_current_user)):
    await get_owned_trip(trip_id, user)
    if body.type not in ("hotel", "restaurant", "attraction"):
        raise HTTPException(400, "Type must be hotel, restaurant, or attraction")
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
    await db.refresh_tokens.create_index("token_hash", unique=True)
    await db.refresh_tokens.create_index("expires_at", expireAfterSeconds=0)
    await db.login_attempts.create_index("identifier")
    await db.trips.create_index([("user_id", 1), ("deleted_at", 1)])
    await db.trips.create_index("share_token")
    await db.expenses.create_index("trip_id")
    await seed_admin()


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
