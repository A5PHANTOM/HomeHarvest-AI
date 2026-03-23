from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os
import csv
import re
from dotenv import load_dotenv
from sqlalchemy.orm import Session
import bcrypt
import google.generativeai as genai

import models
from database import engine, SessionLocal

models.Base.metadata.create_all(bind=engine)


def hash_password(password: str) -> str:
    password_bytes = password.encode("utf-8")
    return bcrypt.hashpw(password_bytes, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed_password.encode("utf-8"))
    except ValueError:
        return False

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
    return [
        {
            "title": "Monsoon Gardening Tips",
            "subtitle": "How to protect your balcony plants from heavy rain.",
        },
        {
            "title": "Top 5 Indoor Plants",
            "subtitle": "Best plants to purify air in your apartment.",
        },
    ]

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
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)

    return {
        "status": "success",
        "message": "Item successfully shared with the local community!",
        "id": new_item.id,
    }


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
