from fastapi import FastAPI, HTTPException, Depends, File, UploadFile, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional, Any
import os
import csv
import re
import json
from datetime import datetime
from uuid import uuid4
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from sqlalchemy import text
import bcrypt
import google.generativeai as genai
from urllib.parse import urlencode
from urllib.request import Request as UrlRequest, urlopen

import models
from database import engine, SessionLocal

models.Base.metadata.create_all(bind=engine)


def ensure_marketplace_schema() -> None:
    """Lightweight migration for SQLite-backed MVP tables."""
    with engine.begin() as conn:
        columns = {
            row[1]
            for row in conn.execute(text("PRAGMA table_info(marketplace_items)"))
        }

        if "image_url" not in columns:
            conn.execute(text("ALTER TABLE marketplace_items ADD COLUMN image_url TEXT"))
        if "description" not in columns:
            conn.execute(text("ALTER TABLE marketplace_items ADD COLUMN description TEXT"))
        if "is_out_of_stock" not in columns:
            conn.execute(
                text("ALTER TABLE marketplace_items ADD COLUMN is_out_of_stock INTEGER NOT NULL DEFAULT 0")
            )


ensure_marketplace_schema()


def hash_password(password: str) -> str:
    password_bytes = password.encode("utf-8")
    return bcrypt.hashpw(password_bytes, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed_password.encode("utf-8"))
    except ValueError:
        return False

def verify_admin_password(provided_password: str) -> bool:
    """Verify admin password. Use environment variable or default for MVP."""
    admin_password = os.getenv("ADMIN_PASSWORD", "admin123")
    return provided_password == admin_password

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Load environment variables
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_PATH = os.path.join(BASE_DIR, "..", ".env")
load_dotenv(dotenv_path=ENV_PATH)

app = FastAPI(
    title="HomeHarvest AI Backend",
    description="Backend API for the HomeHarvest AI Hackathon MVP",
    version="1.0.0"
)

UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Pydantic Models ---
class UserSpaceInfo(BaseModel):
    space_type: str
    sunlight_level: str
    location: Optional[str] = "Unknown"
    custom_query: Optional[str] = None

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class ChatMessage(BaseModel):
    message: str

class MarketplaceItem(BaseModel):
    id: Optional[int] = None
    title: str
    price: str
    distance: str
    seller: str
    time_posted: str
    image_url: Optional[str] = None
    description: Optional[str] = None
    is_out_of_stock: int = 0


class BuyNowRequest(BaseModel):
    item_id: int
    buyer_email: str
    buyer_message: Optional[str] = None


class BuyNowMessageItem(BaseModel):
    id: int
    item_id: int
    item_title: str
    buyer_email: str
    buyer_message: str
    created_at: str


class ReminderItem(BaseModel):
    id: Optional[int] = None
    title: str
    time: str
    icon: str
    color: str


class CalendarProgressItem(BaseModel):
    id: Optional[int] = None
    plant: str
    action: str
    days: str
    progress: float
    color: str


class CalendarPlantInput(BaseModel):
    name: str
    status: Optional[str] = None
    color: Optional[str] = None


class CalendarPlanRequest(BaseModel):
    plants: List[CalendarPlantInput]


class NewsItem(BaseModel):
    title: str
    subtitle: str

#RAG
DATASET_PATH = os.path.join(BASE_DIR, "Datasets", "kerala.csv")
_crop_dataset_cache: Optional[List[dict]] = None


def load_crop_dataset() -> List[dict]:
    global _crop_dataset_cache

    if _crop_dataset_cache is not None:
        return _crop_dataset_cache

    rows: List[dict] = []
    try:
        with open(DATASET_PATH, newline="", encoding="utf-8") as csv_file:
            reader = csv.DictReader(csv_file)
            rows = [
                {k: (v or "").strip() for k, v in row.items()}
                for row in reader
            ]
    except FileNotFoundError:
        rows = []

    _crop_dataset_cache = rows
    return rows


def _tokenize(text: str) -> set:
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def retrieve_relevant_crops(query: str, top_k: int = 4) -> List[dict]:
    dataset = load_crop_dataset()
    if not dataset:
        return []

    query_tokens = _tokenize(query)
    if not query_tokens:
        return dataset[:top_k]

    scored = []
    for row in dataset:
        row_text = " ".join(
            [
                row.get("Crop", ""),
                row.get("Type", ""),
                row.get("Season", ""),
                row.get("Water_Level", ""),
                row.get("Soil_Type", ""),
                row.get("Temp_C", ""),
                row.get("Balcony_Suitable", ""),
            ]
        )
        row_tokens = _tokenize(row_text)
        overlap = len(query_tokens.intersection(row_tokens))
        crop_name = row.get("Crop", "").lower()
        crop_bonus = 2 if crop_name and crop_name in query.lower() else 0
        score = overlap + crop_bonus
        if score > 0:
            scored.append((score, row))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [row for _, row in scored[:top_k]]


def _crop_to_status(row: dict) -> str:
    growth = row.get("Growth_Days", "unknown")
    water = row.get("Water_Level", "medium")
    soil = row.get("Soil_Type", "mixed")
    return f"Growth: {growth} | Water: {water} | Soil: {soil}"


def _crop_to_color(row: dict) -> str:
    water = row.get("Water_Level", "").lower()
    profit = row.get("Profit_Level", "").lower()
    if water == "high":
        return "blue"
    if profit == "high":
        return "orange"
    if water == "low":
        return "lightGreen"
    return "teal"


def _format_crop_context(rows: List[dict]) -> str:
    if not rows:
        return ""

    lines = []
    for row in rows:
        lines.append(
            "- "
            f"{row.get('Crop', 'Unknown')} "
            f"(Type: {row.get('Type', 'N/A')}, Season: {row.get('Season', 'N/A')}, "
            f"Temp: {row.get('Temp_C', 'N/A')}°C, Water: {row.get('Water_Level', 'N/A')}, "
            f"Soil: {row.get('Soil_Type', 'N/A')}, Balcony: {row.get('Balcony_Suitable', 'N/A')}, "
            f"Growth: {row.get('Growth_Days', 'N/A')}, Profit: {row.get('Profit_Level', 'N/A')})"
        )
    return "\n".join(lines)


def _build_fallback_calendar_plan(plants: List[CalendarPlantInput]) -> dict:
    reminders = []
    calendar_items = []

    for i, plant in enumerate(plants):
        plant_name = plant.name.strip() or f"Plant {i + 1}"
        row_matches = retrieve_relevant_crops(plant_name, top_k=1)
        row = row_matches[0] if row_matches else {}

        water_level = (row.get("Water_Level", "Medium") or "Medium").lower()
        growth_days = row.get("Growth_Days", "30-60") or "30-60"
        soil = row.get("Soil_Type", "Loamy") or "Loamy"

        if water_level == "high":
            water_time = "Every day, 7:00 AM"
            progress = 0.20
            color = "blue"
        elif water_level == "low":
            water_time = "Every 2 days, 7:00 AM"
            progress = 0.55
            color = "lightGreen"
        else:
            water_time = "Alternate days, 7:00 AM"
            progress = 0.35
            color = "green"

        reminders.append(
            {
                "id": i * 2 + 1,
                "title": f"Water {plant_name}",
                "time": water_time,
                "icon": "water_drop",
                "color": color,
            }
        )
        reminders.append(
            {
                "id": i * 2 + 2,
                "title": f"Check soil health for {plant_name}",
                "time": "Every Sunday, 9:00 AM",
                "icon": "eco",
                "color": "brown",
            }
        )

        calendar_items.append(
            {
                "id": i + 1,
                "plant": plant_name,
                "action": f"Growth cycle in {growth_days} • Soil: {soil}",
                "days": growth_days,
                "progress": progress,
                "color": color,
            }
        )

    return {"reminders": reminders, "calendar": calendar_items}


def seed_marketplace_if_empty(db: Session):
    if db.query(models.MarketplaceItem).count() > 0:
        return

    db.add_all(
        [
            models.MarketplaceItem(
                title="Fresh Spinach - Grown Locally",
                price="₹20 or Trade",
                distance="0.5 km away",
                seller="Rahul M.",
                time_posted="Posted 2 hrs ago",
            ),
            models.MarketplaceItem(
                title="Organic Tomato Seeds (10 pcs)",
                price="Free",
                distance="1.2 km away",
                seller="Priya S.",
                time_posted="Posted 5 hrs ago",
            ),
            models.MarketplaceItem(
                title="Used Terracotta Pots (Medium)",
                price="₹50 each",
                distance="2.0 km away",
                seller="Amit K.",
                time_posted="Posted 1 day ago",
            ),
        ]
    )
    db.commit()


def seed_calendar_if_empty(db: Session):
    if db.query(models.Reminder).count() == 0:
        db.add_all(
            [
                models.Reminder(
                    title="Water Tomatoes 💧",
                    time="Today, 5:00 PM",
                    icon="water_drop",
                    color="blue",
                ),
                models.Reminder(
                    title="Add Organic Compost 🧴",
                    time="Tomorrow, 9:00 AM",
                    icon="eco",
                    color="brown",
                ),
            ]
        )

    if db.query(models.GardenCalendarItem).count() == 0:
        db.add_all(
            [
                models.GardenCalendarItem(
                    plant="Mint",
                    action="Harvest in",
                    days="10 Days",
                    progress=0.7,
                    color="green",
                ),
                models.GardenCalendarItem(
                    plant="Tomatoes",
                    action="Harvest in",
                    days="25 Days",
                    progress=0.4,
                    color="orange",
                ),
                models.GardenCalendarItem(
                    plant="Spinach",
                    action="Seeds Sown",
                    days="Today",
                    progress=0.05,
                    color="lightGreen",
                ),
            ]
        )

    db.commit()

# --- Endpoints ---

@app.get("/")
def read_root():
    return {"message": "HomeHarvest AI API is running!"}

@app.post("/api/login", response_model=Token)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    return {"access_token": "fake-jwt-token-for-hackathon", "token_type": "bearer"}

@app.post("/api/register", response_model=Token)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.email == req.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    try:
        hashed_pwd = hash_password(req.password)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Password is too long for bcrypt (max 72 bytes).",
        )

    new_user = models.User(name=req.name, email=req.email, hashed_password=hashed_pwd)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {"access_token": "fake-jwt-token-for-hackathon", "token_type": "bearer"}

@app.post("/api/recommend")
def get_plant_recommendations(info: UserSpaceInfo):
    dataset = load_crop_dataset()
    text = (
        f"{info.space_type} {info.sunlight_level} {info.location or ''} {info.custom_query or ''}"
    ).lower()

    if dataset:
        prefers_balcony = "balcony" in text or "indoor" in text
        rows = dataset
        if prefers_balcony:
            rows = [
                row
                for row in rows
                if row.get("Balcony_Suitable", "").strip().lower() == "yes"
            ]

        if "winter" in text:
            rows = [row for row in rows if row.get("Season", "").lower() in {"winter", "all"}]
        elif "summer" in text:
            rows = [row for row in rows if row.get("Season", "").lower() in {"summer", "all"}]

        ranked = retrieve_relevant_crops(text, top_k=5)
        if ranked:
            ranked_names = {row.get("Crop", "") for row in ranked}
            rows = sorted(
                rows,
                key=lambda row: 0 if row.get("Crop", "") in ranked_names else 1,
            )

        picked = rows[:3] if rows else dataset[:3]
        return {
            "recommendations": [
                {
                    "name": row.get("Crop", "Plant"),
                    "status": _crop_to_status(row),
                    "color": _crop_to_color(row),
                }
                for row in picked
            ]
        }

    if "indoor" in text or "low" in text:
        recommendations = [
            {"name": "Mint", "status": "Water lightly every day", "color": "teal"},
            {"name": "Coriander", "status": "Sprouts in 7-10 days", "color": "green"},
            {"name": "Spinach", "status": "Partial sunlight works", "color": "lightGreen"},
        ]
    elif "terrace" in text or "full" in text:
        recommendations = [
            {"name": "Tomatoes", "status": "Harvest in 45-60 days", "color": "orange"},
            {"name": "Chili", "status": "Needs 5-6 hrs sun", "color": "red"},
            {"name": "Brinjal", "status": "Keep soil moist", "color": "deepPurple"},
        ]
    else:
        recommendations = [
            {"name": "Mint", "status": "2 days to harvest", "color": "teal"},
            {"name": "Tomatoes", "status": "Growing well", "color": "orange"},
            {"name": "Spinach", "status": "Needs water", "color": "lightGreen"},
        ]

    return {"recommendations": recommendations}


@app.get("/api/home/news", response_model=List[NewsItem])
def get_news():
    fallback_news = [
        {
            "title": "Monsoon Gardening Tips",
            "subtitle": "How to protect your balcony plants from heavy rain.",
        },
        {
            "title": "Top 5 Indoor Plants",
            "subtitle": "Best plants to purify air in your apartment.",
        },
    ]

    api_key = os.getenv("GNEWS_API_KEY", "").strip()
    if not api_key:
        return fallback_news

    query = os.getenv("GNEWS_QUERY", "gardening OR urban farming OR kitchen garden").strip()
    language = os.getenv("GNEWS_LANG", "en").strip()
    country = os.getenv("GNEWS_COUNTRY", "in").strip()
    max_items = os.getenv("GNEWS_MAX", "6").strip()

    try:
        max_count = max(1, min(int(max_items), 10))
    except ValueError:
        max_count = 6

    def fetch_news(q: str, c: Optional[str]) -> List[dict]:
        payload_params = {
            "q": q,
            "lang": language,
            "max": max_count,
            "apikey": api_key,
        }
        if c:
            payload_params["country"] = c

        params = urlencode(payload_params)
        url = f"https://gnews.io/api/v4/search?{params}"

        req = UrlRequest(url, headers={"User-Agent": "HomeHarvestAI/1.0"})
        with urlopen(req, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))

        articles = payload.get("articles", []) if isinstance(payload, dict) else []
        news_items = []
        for article in articles:
            if not isinstance(article, dict):
                continue
            title = (article.get("title") or "").strip()
            description = (article.get("description") or "").strip()
            source = (
                (article.get("source") or {}).get("name", "")
                if isinstance(article.get("source"), dict)
                else ""
            ).strip()
            if not title:
                continue

            subtitle_parts = [part for part in [description, source] if part]
            subtitle = " • ".join(subtitle_parts) if subtitle_parts else "Latest gardening update"
            news_items.append({"title": title, "subtitle": subtitle})

        return news_items

    queries_to_try = [
        query,
        "gardening OR urban farming OR kitchen garden",
        "agriculture OR farming OR crops",
    ]
    countries_to_try = [country, None]

    try:
        for q in queries_to_try:
            for c in countries_to_try:
                news_items = fetch_news(q, c)
                if news_items:
                    return news_items
    except Exception:
        pass

    return fallback_news

@app.post("/api/chat")
def ai_gardening_chat(chat: ChatMessage):
    prompt = chat.message.lower()
    rag_rows = retrieve_relevant_crops(chat.message, top_k=4)
    rag_context = _format_crop_context(rag_rows)

    def fallback_response() -> str:
        if rag_rows:
            top = rag_rows[0]
            return (
                f"Based on our Kerala crop dataset, {top.get('Crop', 'this crop')} is suitable for "
                f"{top.get('Season', 'multiple seasons')} season with {top.get('Water_Level', 'medium')} water, "
                f"best in {top.get('Soil_Type', 'suitable')} soil, and typical growth in "
                f"{top.get('Growth_Days', 'N/A')}."
            )
        if "balcony" in prompt:
            return "That sounds great! For a small balcony with good sunlight, I highly recommend growing Mint and Tomatoes. They are perfect for beginners."
        if "yellow" in prompt:
            return "Yellow leaves typically mean overwatering or nutrient deficiency. Try reducing water and adding some organic compost."
        if "water" in prompt:
            return "A simple rule: water early morning, and only when top soil feels dry. Overwatering is more common than underwatering."
        return "I'm your AI gardening assistant! Tell me about your space and I'll suggest what to grow."

    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    preferred_model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash").strip()

    if not api_key:
        return {"response": fallback_response()}

    try:
        genai.configure(api_key=api_key)
        candidate_models = [
            preferred_model,
            "gemini-2.0-flash",
            "gemini-2.0-flash-exp",
            "gemini-1.5-flash",
        ]

        seen = set()
        for model_name in candidate_models:
            if not model_name or model_name in seen:
                continue
            seen.add(model_name)

            try:
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(
                    "You are a friendly urban gardening assistant. "
                    "Use the provided crop dataset context first when relevant. "
                    "If context is missing, still answer generally. "
                    "Give concise, practical, beginner-friendly advice in 3-6 lines.\n\n"
                    f"Dataset context:\n{rag_context or 'No matching crop rows found.'}\n\n"
                    f"User question: {chat.message}"
                )

                text = (getattr(response, "text", "") or "").strip()
                if text:
                    return {"response": text}
            except Exception:
                continue
    except Exception:
        pass

    return {"response": fallback_response()}


@app.post("/api/calendar/optimize")
def optimize_calendar_plan(req: CalendarPlanRequest):
    plants = [p for p in req.plants if p.name.strip()]
    if not plants:
        return {
            "reminders": [],
            "calendar": [],
            "note": "No plants provided.",
        }

    fallback = _build_fallback_calendar_plan(plants)

    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    preferred_model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash").strip()
    if not api_key:
        return fallback

    try:
        genai.configure(api_key=api_key)

        context_lines = []
        for plant in plants:
            match = retrieve_relevant_crops(plant.name, top_k=1)
            if match:
                row = match[0]
                context_lines.append(
                    f"{plant.name}: water={row.get('Water_Level','Medium')}, growth={row.get('Growth_Days','30-60')}, soil={row.get('Soil_Type','Loamy')}"
                )
            else:
                context_lines.append(f"{plant.name}: no dataset match")

        prompt = (
            "Create a practical home gardening schedule in JSON only. "
            "Output strictly in this format: "
            "{\"reminders\":[{\"id\":1,\"title\":\"...\",\"time\":\"...\",\"icon\":\"water_drop|eco|schedule\",\"color\":\"blue|green|brown|orange|lightGreen\"}],"
            "\"calendar\":[{\"id\":1,\"plant\":\"...\",\"action\":\"...\",\"days\":\"...\",\"progress\":0.4,\"color\":\"blue|green|brown|orange|lightGreen\"}]}. "
            "Keep progress between 0 and 1.\n\n"
            f"Plants: {[p.name for p in plants]}\n"
            f"Dataset context:\n" + "\n".join(context_lines)
        )

        candidate_models = [preferred_model, "gemini-2.0-flash", "gemini-2.5-flash", "gemini-1.5-flash"]
        seen = set()
        for model_name in candidate_models:
            if not model_name or model_name in seen:
                continue
            seen.add(model_name)
            try:
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(prompt)
                text = (getattr(response, "text", "") or "").strip()
                if not text:
                    continue

                start = text.find("{")
                end = text.rfind("}")
                if start == -1 or end == -1 or end <= start:
                    continue

                payload = json.loads(text[start : end + 1])
                reminders = payload.get("reminders", []) if isinstance(payload, dict) else []
                calendar = payload.get("calendar", []) if isinstance(payload, dict) else []
                if isinstance(reminders, list) and isinstance(calendar, list):
                    return {"reminders": reminders, "calendar": calendar}
            except Exception:
                continue
    except Exception:
        pass

    return fallback

@app.get("/api/marketplace/items", response_model=List[MarketplaceItem])
def get_marketplace_items(db: Session = Depends(get_db)):
    seed_marketplace_if_empty(db)
    items = db.query(models.MarketplaceItem).order_by(models.MarketplaceItem.id.desc()).all()
    return [
        {
            "id": item.id,
            "title": item.title,
            "price": item.price,
            "distance": item.distance,
            "seller": item.seller,
            "time_posted": item.time_posted,
            "image_url": item.image_url,
            "description": item.description,
            "is_out_of_stock": item.is_out_of_stock,
        }
        for item in items
    ]

@app.post("/api/marketplace/share")
def share_produce(item: MarketplaceItem, db: Session = Depends(get_db)):
    new_item = models.MarketplaceItem(
        title=item.title,
        price=item.price,
        distance=item.distance,
        seller=item.seller,
        time_posted=item.time_posted,
        image_url=item.image_url,
        description=item.description,
        is_out_of_stock=item.is_out_of_stock,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)

    return {
        "status": "success",
        "message": "Item successfully shared with the local community!",
        "id": new_item.id,
    }


@app.post("/api/marketplace/buy")
def buy_marketplace_item(req: BuyNowRequest, db: Session = Depends(get_db)):
    buyer_email = req.buyer_email.strip().lower()
    if not buyer_email.endswith("@gmail.com"):
        raise HTTPException(status_code=400, detail="Please enter a valid Gmail ID")

    item = db.query(models.MarketplaceItem).filter(models.MarketplaceItem.id == req.item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if int(item.is_out_of_stock or 0) == 1:
        raise HTTPException(status_code=400, detail="Item is out of stock")

    inquiry = models.MarketplaceInquiry(
        item_id=item.id,
        item_title=item.title,
        buyer_email=buyer_email,
        buyer_message=(req.buyer_message or "").strip(),
        created_at=datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC"),
    )
    db.add(inquiry)
    db.commit()
    db.refresh(inquiry)

    return {
        "status": "success",
        "message": "Your request was sent to the admin.",
        "inquiry_id": inquiry.id,
    }


# --- Admin Marketplace Endpoints ---
class AdminAuthRequest(BaseModel):
    password: str

class AdminItemRequest(BaseModel):
    title: str
    price: str
    distance: str = "Local"
    seller: str = "Admin"
    time_posted: str = "Now"
    image_url: Optional[str] = None
    description: Optional[str] = None
    is_out_of_stock: int = 0

@app.post("/api/marketplace/admin/items")
def create_marketplace_item_admin(item: AdminItemRequest, auth: AdminAuthRequest, db: Session = Depends(get_db)):
    """Create marketplace item (admin only)"""
    if not verify_admin_password(auth.password):
        raise HTTPException(status_code=401, detail="Invalid admin password")
    
    new_item = models.MarketplaceItem(
        title=item.title,
        price=item.price,
        distance=item.distance,
        seller=item.seller,
        time_posted=item.time_posted,
        image_url=item.image_url,
        description=item.description,
        is_out_of_stock=item.is_out_of_stock,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return {"status": "success", "id": new_item.id, "message": "Item created"}

@app.patch("/api/marketplace/items/{item_id}/stock")
def toggle_marketplace_item_stock(item_id: int, auth: AdminAuthRequest, db: Session = Depends(get_db)):
    """Toggle out-of-stock status (admin only)"""
    if not verify_admin_password(auth.password):
        raise HTTPException(status_code=401, detail="Invalid admin password")
    
    item = db.query(models.MarketplaceItem).filter(models.MarketplaceItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    item.is_out_of_stock = 1 - item.is_out_of_stock
    db.commit()
    return {"status": "success", "is_out_of_stock": item.is_out_of_stock}

@app.delete("/api/marketplace/items/{item_id}")
def delete_marketplace_item(item_id: int, auth: AdminAuthRequest, db: Session = Depends(get_db)):
    """Delete marketplace item (admin only)"""
    if not verify_admin_password(auth.password):
        raise HTTPException(status_code=401, detail="Invalid admin password")
    
    item = db.query(models.MarketplaceItem).filter(models.MarketplaceItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    db.delete(item)
    db.commit()
    return {"status": "success", "message": "Item deleted"}


@app.post("/api/marketplace/admin/messages", response_model=List[BuyNowMessageItem])
def get_buy_now_messages(auth: AdminAuthRequest, db: Session = Depends(get_db)):
    if not verify_admin_password(auth.password):
        raise HTTPException(status_code=401, detail="Invalid admin password")

    messages = (
        db.query(models.MarketplaceInquiry)
        .order_by(models.MarketplaceInquiry.id.desc())
        .all()
    )

    return [
        {
            "id": msg.id,
            "item_id": msg.item_id,
            "item_title": msg.item_title,
            "buyer_email": msg.buyer_email,
            "buyer_message": msg.buyer_message or "",
            "created_at": msg.created_at,
        }
        for msg in messages
    ]


@app.post("/api/marketplace/admin/upload-image")
def upload_marketplace_image(
    request: Request,
    password: str = Form(...),
    image: UploadFile = File(...),
):
    if not verify_admin_password(password):
        raise HTTPException(status_code=401, detail="Invalid admin password")

    filename = image.filename or "upload.jpg"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Only .jpg, .jpeg, .png, .webp are allowed")

    safe_name = f"{uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, safe_name)
    with open(file_path, "wb") as out_file:
        out_file.write(image.file.read())

    image_url = str(request.base_url).rstrip("/") + f"/uploads/{safe_name}"
    return {"status": "success", "image_url": image_url}

@app.get("/api/calendar/reminders", response_model=List[ReminderItem])
def get_reminders(db: Session = Depends(get_db)):
    seed_calendar_if_empty(db)
    reminders = db.query(models.Reminder).order_by(models.Reminder.id.desc()).all()
    return [
        {
            "id": item.id,
            "title": item.title,
            "time": item.time,
            "icon": item.icon,
            "color": item.color,
        }
        for item in reminders
    ]


@app.post("/api/calendar/reminders")
def add_reminder(reminder: ReminderItem, db: Session = Depends(get_db)):
    new_reminder = models.Reminder(
        title=reminder.title,
        time=reminder.time,
        icon=reminder.icon,
        color=reminder.color,
    )
    db.add(new_reminder)
    db.commit()
    db.refresh(new_reminder)
    return {"status": "success", "id": new_reminder.id}


@app.get("/api/calendar/progress", response_model=List[CalendarProgressItem])
def get_calendar_progress(db: Session = Depends(get_db)):
    seed_calendar_if_empty(db)
    calendar_items = db.query(models.GardenCalendarItem).order_by(models.GardenCalendarItem.id.asc()).all()
    return [
        {
            "id": item.id,
            "plant": item.plant,
            "action": item.action,
            "days": item.days,
            "progress": item.progress,
            "color": item.color,
        }
        for item in calendar_items
    ]

# Instructions to run: 
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
