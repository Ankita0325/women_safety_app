import os
from dotenv import load_dotenv
from typing import List, Dict, Optional
from pydantic_settings import BaseSettings

load_dotenv()

class Settings(BaseSettings):
    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase/serviceAccountKey.json")
    
    # Twilio
    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_PHONE_NUMBER: str = os.getenv("TWILIO_PHONE_NUMBER", "")
    
    # Google APIs
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    GOOGLE_MAPS_API_KEY: str = os.getenv("GOOGLE_MAPS_API_KEY", "")
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-here-change-in-production")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./women_safety.db")
    
    # Application
    PORT: int = int(os.getenv("PORT", 8000))
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"
    
    # Emergency Keywords
    EMERGENCY_KEYWORDS: List[str] = [
        "help", "sos", "save me", "bachao", "emergency",
        "danger", "attack", "kidnap", "follow", "stalk",
        "help me", "save", "police", "fire", "accident",
        "assault", "harassment", "threat", "violent"
    ]
    
    # Police Stations (Sample - Replace with actual database)
    POLICE_STATIONS: List[Dict] = [
        {"name": "Mumbai Police HQ", "lat": 19.0760, "lng": 72.8777, "phone": "100"},
        {"name": "Andheri Police Station", "lat": 19.1179, "lng": 72.8488, "phone": "022-26221234"},
        {"name": "Bandra Police Station", "lat": 19.0544, "lng": 72.8401, "phone": "022-26421000"},
        {"name": "Colaba Police Station", "lat": 18.9086, "lng": 72.8134, "phone": "022-22151888"},
        {"name": "Malabar Hill Police", "lat": 18.9568, "lng": 72.8028, "phone": "022-23678901"},
    ]
    
    # Hospitals (Sample)
    HOSPITALS: List[Dict] = [
        {"name": "JJ Hospital", "lat": 18.9604, "lng": 72.8350, "phone": "022-23735555"},
        {"name": "Lilavati Hospital", "lat": 19.0330, "lng": 72.8343, "phone": "022-26751000"},
        {"name": "Breach Candy Hospital", "lat": 18.9568, "lng": 72.8042, "phone": "022-23667888"},
        {"name": "Kokilaben Hospital", "lat": 19.1279, "lng": 72.8440, "phone": "022-42696969"},
        {"name": "Nanavati Hospital", "lat": 19.0966, "lng": 72.8366, "phone": "022-26267500"},
    ]
    
    # Safe Zones (Sample)
    SAFE_ZONES: List[Dict] = [
        {"name": "Marine Drive", "lat": 18.9433, "lng": 72.8214, "rating": 4.5},
        {"name": "Bandra Bandstand", "lat": 19.0498, "lng": 72.8114, "rating": 4.2},
        {"name": "Juhu Beach", "lat": 19.0987, "lng": 72.8220, "rating": 4.0},
        {"name": "Gateway of India", "lat": 18.9220, "lng": 72.8347, "rating": 4.3},
    ]
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"

settings = Settings()