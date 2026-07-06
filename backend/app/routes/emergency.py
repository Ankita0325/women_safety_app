from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from typing import List, Dict
from app.models.schemas import EmergencyRequest, EmergencyContact, EmergencyStatus
from app.services.firebase_service import FirebaseService
from app.services.sms_service import SMSService
from app.services.route_service import RouteService
from app.services.ai_service import AIService
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

firebase = FirebaseService()
sms_service = SMSService()
route_service = RouteService()
ai_service = AIService()

@router.post("/trigger")
async def trigger_emergency(
    emergency_data: EmergencyRequest,
    background_tasks: BackgroundTasks
):
    """Trigger emergency response"""
    try:
        # Log emergency
        emergency_id = firebase.log_emergency(emergency_data.dict())
        
        # Get user data
        user = firebase.get_user(emergency_data.user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get emergency contacts
        contacts = user.get('emergency_contacts', [])
        
        # Prepare location data
        location = {
            'lat': emergency_data.latitude,
            'lng': emergency_data.longitude,
            'timestamp': emergency_data.timestamp.isoformat()
        }
        
        # Send SMS to contacts in background
        if contacts:
            phone_numbers = [c.get('phone') for c in contacts if c.get('phone')]
            if phone_numbers:
                background_tasks.add_task(
                    sms_service.send_emergency_alert,
                    phone_numbers,
                    user,
                    location
                )
        
        # Get nearby police stations
        police_stations = firebase.get_nearby_police_stations(
            emergency_data.latitude,
            emergency_data.longitude
        )
        
        # Notify police
        for station in police_stations:
            background_tasks.add_task(
                sms_service.send_police_notification,
                station,
                {
                    'user_name': user.get('name', 'Anonymous'),
                    'location': f"{emergency_data.latitude}, {emergency_data.longitude}",
                    'lat': emergency_data.latitude,
                    'lng': emergency_data.longitude,
                    'incident_type': emergency_data.incident_type or 'Emergency',
                    'description': emergency_data.description or 'SOS alert triggered'
                }
            )
        
        # AI analysis for additional assistance
        ai_analysis = ai_service.generate_emergency_response_plan(
            user, location
        )
        
        return {
            "status": "success",
            "emergency_id": emergency_id,
            "message": "Emergency triggered successfully",
            "police_notified": len(police_stations) > 0,
            "contacts_notified": len(contacts),
            "ai_recommendations": ai_analysis.get('recommendations', [])
        }
    
    except Exception as e:
        logger.error(f"Error triggering emergency: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/add-contact/{user_id}")
async def add_emergency_contact(user_id: str, contact: EmergencyContact):
    """Add emergency contact for user"""
    try:
        firebase.add_emergency_contact(user_id, contact.dict())
        return {"status": "success", "message": "Contact added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/remove-contact/{user_id}/{phone}")
async def remove_emergency_contact(user_id: str, phone: str):
    """Remove emergency contact by phone"""
    try:
        firebase.remove_emergency_contact(user_id, phone)
        return {"status": "success", "message": "Contact removed successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/contacts/{user_id}")
async def get_emergency_contacts(user_id: str):
    """Get all emergency contacts for user"""
    try:
        contacts = firebase.get_emergency_contacts(user_id)
        return {"contacts": contacts}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/nearby-services/{user_id}")
async def get_nearby_services(user_id: str):
    """Get nearby emergency services"""
    try:
        user = firebase.get_user(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get user's last known location from emergency logs
        logs = firebase.get_emergency_logs(user_id, 1)
        if logs and logs[0]:
            lat = logs[0].get('latitude', 19.0760)
            lng = logs[0].get('longitude', 72.8777)
        else:
            # Default location (Mumbai)
            lat = 19.0760
            lng = 72.8777
        
        police = firebase.get_nearby_police_stations(lat, lng)
        hospitals = firebase.get_nearby_hospitals(lat, lng)
        safe_zones = firebase.get_safe_zones(lat, lng)
        
        return {
            "police_stations": police,
            "hospitals": hospitals,
            "safe_zones": safe_zones,
            "current_location": {"lat": lat, "lng": lng}
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/history/{user_id}")
async def get_emergency_history(user_id: str, limit: int = 10):
    """Get emergency history for user"""
    try:
        logs = firebase.get_emergency_logs(user_id, limit)
        return {"history": logs, "count": len(logs)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/update-status/{emergency_id}")
async def update_emergency_status(emergency_id: str, status: EmergencyStatus):
    """Update emergency status"""
    try:
        firebase.update_emergency_status(emergency_id, status.value)
        return {"status": "success", "message": f"Status updated to {status.value}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from pydantic import BaseModel

class VoiceDetectionRequest(BaseModel):
    audio_text: str

@router.post("/voice-detection")
async def detect_emergency_voice(payload: VoiceDetectionRequest):
    """Detect emergency keywords in audio"""
    try:
        audio_text = payload.audio_text
        # Check for emergency keywords
        from app.utils.config import settings
        keywords = settings.EMERGENCY_KEYWORDS
        detected = [kw for kw in keywords if kw in audio_text.lower()]
        
        # Use AI for advanced detection
        ai_analysis = ai_service.detect_distress_in_audio(audio_text)
        
        return {
            "keywords_detected": detected,
            "ai_analysis": ai_analysis,
            "emergency_detected": len(detected) > 0 or ai_analysis.get('distress_detected', False),
            "urgency_level": ai_analysis.get('urgency_level', 'low')
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))