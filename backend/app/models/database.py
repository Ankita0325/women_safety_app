from sqlalchemy import create_engine, Column, String, Float, DateTime, Boolean, Integer, JSON, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
from app.utils.config import settings

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'
    
    id = Column(String(50), primary_key=True)
    email = Column(String(100), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False)
    role = Column(String(20), default='user')
    emergency_contacts = Column(JSON, default=[])
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    is_verified = Column(Boolean, default=False)
    firebase_uid = Column(String(100), unique=True)

class EmergencyLog(Base):
    __tablename__ = 'emergency_logs'
    
    id = Column(String(50), primary_key=True)
    user_id = Column(String(50), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    status = Column(String(20), default='active')
    incident_type = Column(String(50))
    description = Column(Text)
    timestamp = Column(DateTime, default=datetime.now)
    resolved_at = Column(DateTime)
    contacts_notified = Column(Integer, default=0)
    police_notified = Column(Boolean, default=False)

class IncidentReportDB(Base):
    __tablename__ = 'incident_reports'
    
    id = Column(String(50), primary_key=True)
    incident_type = Column(String(50), nullable=False)
    description = Column(Text, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(200))
    is_anonymous = Column(Boolean, default=True)
    severity = Column(String(20), default='medium')
    images = Column(JSON, default=[])
    timestamp = Column(DateTime, default=datetime.now)
    user_id = Column(String(50))

class SafetyRoute(Base):
    __tablename__ = 'safety_routes'
    
    id = Column(String(50), primary_key=True)
    start_lat = Column(Float, nullable=False)
    start_lng = Column(Float, nullable=False)
    end_lat = Column(Float, nullable=False)
    end_lng = Column(Float, nullable=False)
    route_polyline = Column(Text, nullable=False)
    distance = Column(Float)
    duration = Column(Integer)
    safe_score = Column(Integer)
    created_at = Column(DateTime, default=datetime.now)

class UserLocation(Base):
    __tablename__ = 'user_locations'
    
    id = Column(String(50), primary_key=True)
    user_id = Column(String(50), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float)
    timestamp = Column(DateTime, default=datetime.now)

class EmergencyContactDB(Base):
    __tablename__ = 'emergency_contacts'
    
    id = Column(String(50), primary_key=True)
    user_id = Column(String(50), nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False)
    relation = Column(String(50))
    is_primary = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.now)

# Database engine
engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

def create_tables():
    Base.metadata.create_all(engine)