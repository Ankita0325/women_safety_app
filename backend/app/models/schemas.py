from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List, Dict
from datetime import datetime
from enum import Enum

class UserRole(str, Enum):
    USER = "user"
    ADMIN = "admin"
    MODERATOR = "moderator"

class EmergencyStatus(str, Enum):
    ACTIVE = "active"
    RESOLVED = "resolved"
    CANCELLED = "cancelled"

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    name: str = Field(..., min_length=2, max_length=50)
    phone: str = Field(..., pattern=r'^\+?[1-9]\d{1,14}$')
    
    @validator('password')
    def validate_password(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    uid: str
    email: str
    name: str
    phone: str
    role: UserRole
    emergency_contacts: List[Dict] = []
    created_at: datetime
    updated_at: datetime
    is_verified: bool = False

class EmergencyContact(BaseModel):
    name: str = Field(..., min_length=2)
    phone: str = Field(..., pattern=r'^\+?[1-9]\d{1,14}$')
    relation: str = Field(..., min_length=2)
    is_primary: bool = False

class IncidentReport(BaseModel):
    incident_type: str
    description: str = Field(..., min_length=10)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: str
    timestamp: datetime = Field(default_factory=datetime.now)
    is_anonymous: bool = True
    images: List[str] = []
    severity: str = Field(default="medium", regex="^(low|medium|high)$")

class EmergencyRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    timestamp: datetime = Field(default_factory=datetime.now)
    user_id: str
    incident_type: Optional[str] = "general"
    description: Optional[str] = None

class RouteRequest(BaseModel):
    start_lat: float = Field(..., ge=-90, le=90)
    start_lng: float = Field(..., ge=-180, le=180)
    end_lat: float = Field(..., ge=-90, le=90)
    end_lng: float = Field(..., ge=-180, le=180)
    avoid_unsafe_areas: bool = True
    prefer_well_lit: bool = True

class RouteResponse(BaseModel):
    route_polyline: str
    distance: float
    duration: int
    safe_score: int = Field(..., ge=0, le=100)
    steps: List[Dict]
    waypoints: List[Dict]
    warnings: List[str] = []
    police_stations_nearby: List[Dict] = []
    hospitals_nearby: List[Dict] = []

class SafetyAlert(BaseModel):
    title: str
    description: str
    severity: str
    latitude: float
    longitude: float
    timestamp: datetime
    source: str
    expires_at: Optional[datetime] = None

class ReportIncident(BaseModel):
    type: str
    description: str
    latitude: float
    longitude: float
    address: str
    is_anonymous: bool = True
    images: Optional[List[str]] = None