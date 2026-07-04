from fastapi import APIRouter, HTTPException, File, UploadFile, Form, Depends
from typing import List, Optional
from app.models.schemas import IncidentReport, ReportIncident
from app.services.firebase_service import FirebaseService
from app.services.ai_service import AIService
from datetime import datetime
import logging
import base64

router = APIRouter()
logger = logging.getLogger(__name__)

firebase = FirebaseService()
ai_service = AIService()

@router.post("/incident")
async def report_incident(report: ReportIncident):
    """Submit anonymous incident report"""
    try:
        # Prepare report data
        report_data = {
            "incident_type": report.type,
            "description": report.description,
            "latitude": report.latitude,
            "longitude": report.longitude,
            "address": report.address,
            "is_anonymous": report.is_anonymous,
            "images": report.images or [],
            "severity": "medium",
            "timestamp": datetime.now().isoformat()
        }
        
        # Add to Firebase
        report_id = firebase.add_incident_report(report_data)
        
        # Analyze incident with AI
        analysis = ai_service.analyze_incident_report(report_data)
        
        # Get safety recommendations
        safety_recommendations = ai_service.analyze_safety({
            'lat': report.latitude,
            'lng': report.longitude,
            'time': datetime.now().isoformat()
        })
        
        return {
            "status": "success",
            "report_id": report_id,
            "analysis": analysis,
            "safety_recommendations": safety_recommendations,
            "message": "Incident reported successfully"
        }
    except Exception as e:
        logger.error(f"Error reporting incident: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-evidence")
async def upload_evidence(
    file: UploadFile = File(...),
    report_id: Optional[str] = Form(None)
):
    """Upload evidence image/video"""
    try:
        contents = await file.read()
        
        # Validate file type
        allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'video/mp4']
        if file.content_type not in allowed_types:
            raise HTTPException(status_code=400, detail="Invalid file type")
        
        # Validate file size (max 10MB)
        if len(contents) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large (max 10MB)")
        
        # Upload to Firebase Storage
        filename = f"evidence_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file.filename}"
        file_url = firebase.upload_file(contents, filename)
        
        # If report_id provided, update report with image
        if report_id:
            report = firebase.get_incident_report(report_id)
            if report:
                images = report.get('images', [])
                images.append(file_url)
                firebase.update_incident_report(report_id, {'images': images})
        
        return {
            "status": "success",
            "message": "Evidence uploaded successfully",
            "file_url": file_url,
            "filename": file.filename
        }
    except Exception as e:
        logger.error(f"Error uploading evidence: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/incidents")
async def get_incidents(
    lat: float,
    lng: float,
    radius: float = 5,
    limit: int = 50
):
    """Get incident reports near location"""
    try:
        incidents = firebase.get_incident_reports(lat, lng, radius)
        
        # Filter by severity
        high_risk = [i for i in incidents if i.get('severity') == 'high']
        
        # Sort by recency
        incidents.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        return {
            "incidents": incidents[:limit],
            "count": len(incidents),
            "high_risk_count": len(high_risk),
            "radius_km": radius,
            "location": {"lat": lat, "lng": lng}
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/heatmap-data")
async def get_heatmap_data(lat: float, lng: float, radius: float = 10):
    """Get heatmap data for unsafe areas"""
    try:
        incidents = firebase.get_incident_reports(lat, lng, radius)
        
        # Process data for heatmap
        heatmap_data = []
        for incident in incidents:
            heatmap_data.append({
                "latitude": incident.get('latitude'),
                "longitude": incident.get('longitude'),
                "weight": 1.0,  # Basic weight
                "severity": incident.get('severity', 'medium'),
                "type": incident.get('incident_type', 'Unknown')
            })
        
        # Additional analysis
        analysis = ai_service.analyze_safety({
            'lat': lat,
            'lng': lng,
            'time': datetime.now().isoformat()
        })
        
        return {
            "heatmap_data": heatmap_data,
            "analysis": analysis,
            "total_incidents": len(incidents),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/statistics")
async def get_incident_statistics():
    """Get incident statistics"""
    try:
        # This would normally query aggregate data
        # For demo, returning sample statistics
        return {
            "total_reports": 1250,
            "reported_today": 12,
            "reported_this_week": 87,
            "common_types": {
                "Harassment": 420,
                "Stalking": 280,
                "Theft": 185,
                "Assault": 165,
                "Other": 200
            },
            "safety_score": 67.5,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))