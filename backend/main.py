from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path="../.env")

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
    title: str
    price: str
    distance: str
    seller: str
    time_posted: str

# --- Endpoints ---

@app.get("/")
def read_root():
    return {"message": "HomeHarvest AI API is running!"}

@app.post("/api/login", response_model=Token)
def login(req: LoginRequest):
    # MVP Dummy Authentication
    if req.email and req.password:
        return {"access_token": "fake-jwt-token-for-hackathon", "token_type": "bearer"}
    raise HTTPException(status_code=400, detail="Invalid credentials")

@app.post("/api/register", response_model=Token)
def register(req: RegisterRequest):
    # MVP Dummy Registration
    if req.name and req.email and req.password:
        return {"access_token": "fake-jwt-token-for-hackathon", "token_type": "bearer"}
    raise HTTPException(status_code=400, detail="Invalid registration data")

@app.post("/api/recommend")
def get_plant_recommendations(info: UserSpaceInfo):
    # TODO: Connect to Gemini API for real recommendations
    return {
        "recommendations": [
            {"name": "Mint", "status": "2 days to harvest", "color": "teal"},
            {"name": "Tomatoes", "status": "Growing well", "color": "orange"},
            {"name": "Spinach", "status": "Needs water", "color": "lightGreen"}
        ]
    }

@app.post("/api/chat")
def ai_gardening_chat(chat: ChatMessage):
    # TODO: Connect to Gemini API for the true brain
    # Simulated basic responses matching the MVP golden flow
    prompt = chat.message.lower()
    if "balcony" in prompt:
        return {"response": "That sounds great! For a small balcony with good sunlight, I highly recommend growing Mint and Tomatoes. They are perfect for beginners."}
    elif "yellow" in prompt:
        return {"response": "Yellow leaves typically mean overwatering or nutrient deficiency. Try reducing water and adding some organic compost."}
    
    return {"response": "I'm your AI gardening assistant! Tell me about your space and I'll suggest what to grow."}

@app.get("/api/marketplace/items", response_model=List[MarketplaceItem])
def get_marketplace_items():
    # Placeholder data designed to feed perfectly into the Flutter marketplace screen
    return [
        {
            "title": "Fresh Spinach - Grown Locally",
            "price": "₹20 or Trade",
            "distance": "0.5 km away",
            "seller": "Rahul M.",
            "time_posted": "Posted 2 hrs ago"
        },
        {
            "title": "Organic Tomato Seeds (10 pcs)",
            "price": "Free",
            "distance": "1.2 km away",
            "seller": "Priya S.",
            "time_posted": "Posted 5 hrs ago"
        },
        {
            "title": "Used Terracotta Pots (Medium)",
            "price": "₹50 each",
            "distance": "2.0 km away",
            "seller": "Amit K.",
            "time_posted": "Posted 1 day ago"
        }
    ]

@app.post("/api/marketplace/share")
def share_produce(item: MarketplaceItem):
    # TODO: Save to SQLite/PostgreSQL Database
    return {"status": "success", "message": "Item successfully shared with the local community!"}

# Instructions to run: 
# uvicorn main:app --reload --host 0.0.0.0 --port 8000
