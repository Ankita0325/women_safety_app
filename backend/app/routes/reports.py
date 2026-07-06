import os
from fastapi import APIRouter, HTTPException, File, UploadFile, Form, Depends
from typing import List, Optional, Dict
from app.models.schemas import IncidentReport, ReportIncident, VoteRequest
from app.services.firebase_service import FirebaseService
from app.services.ai_service import AIService
from app.services.safety_score_calculator import SafetyScoreCalculator
from datetime import datetime, timedelta
import logging
import json

router = APIRouter()
logger = logging.getLogger(__name__)

firebase = FirebaseService()
ai_service = AIService()
calculator = SafetyScoreCalculator()

@router.post("/incident")
async def report_incident(report: ReportIncident):
    """Submit anonymous incident report with AI screening and score updates"""
    try:
        # 1. Fetch nearby reports to run AI duplicate check (within 3km)
        nearby = firebase.get_incident_reports(report.latitude, report.longitude, radius_km=3.0)
        
        # Prepare basic report dict
        report_data = {
            "incident_type": report.type,
            "description": report.description,
            "latitude": report.latitude,
            "longitude": report.longitude,
            "address": report.address,
            "is_anonymous": report.is_anonymous,
            "images": report.images or [],
            "severity": "medium",
            "timestamp": datetime.now().isoformat(),
            "status": "pending",
            "upvotes": 0,
            "downvotes": 0,
            "category": report.category or report.type,
            "expires_at": (datetime.now() + timedelta(days=30)).isoformat()
        }

        # 2. Run AI duplicate & spam screening
        ai_check = ai_service.detect_spam_and_duplicate(report_data, nearby)
        report_data["ai_analysis"] = ai_check
        
        if ai_check.get("is_spam", False):
            # Mark spam report as rejected immediately
            report_data["status"] = "rejected"
            report_data["severity"] = "low"
        elif ai_check.get("is_duplicate", False):
            # Duplicate reports start in pending but have low severity
            report_data["status"] = "pending"
            report_data["severity"] = "low"
        
        # 3. Calculate initial safety score for this location
        score_res = calculator.calculate_score(report.latitude, report.longitude, nearby)
        report_data["safety_score"] = score_res["safety_score"]

        # 4. Add to database
        report_id = firebase.add_incident_report(report_data)
        
        # Analyze incident details with AI
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
            "screening": ai_check,
            "safety_recommendations": safety_recommendations,
            "safety_score": score_res["safety_score"],
            "message": "Incident reported successfully"
        }
    except Exception as e:
        logger.error(f"Error reporting incident: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{report_id}/vote")
async def vote_incident_report(report_id: str, vote: VoteRequest):
    """Cast a community upvote or downvote to verify/reject an incident"""
    try:
        report = firebase.get_incident_report(report_id)
        if not report:
            raise HTTPException(status_code=404, detail="Incident report not found")
        
        upvotes = report.get('upvotes', 0)
        downvotes = report.get('downvotes', 0)
        status = report.get('status', 'pending')
        
        if vote.vote_type == 'upvote':
            upvotes += 1
            if upvotes >= 3:
                status = 'verified'
        else:
            downvotes += 1
            if downvotes >= 3:
                status = 'rejected'
                
        firebase.update_incident_report(report_id, {
            'upvotes': upvotes,
            'downvotes': downvotes,
            'status': status
        })
        
        # Recalculate safety score in the area
        nearby = firebase.get_incident_reports(report['latitude'], report['longitude'], radius_km=3.0)
        
        # Update calculator with nearby safety resources
        police = firebase.get_nearby_police_stations(report['latitude'], report['longitude'])
        hospitals = firebase.get_nearby_hospitals(report['latitude'], report['longitude'])
        calc = SafetyScoreCalculator(police_stations=police, hospitals=hospitals)
        
        score_res = calc.calculate_score(report['latitude'], report['longitude'], nearby)
        firebase.update_incident_report(report_id, {'safety_score': score_res['safety_score']})
        
        return {
            "status": "success",
            "upvotes": upvotes,
            "downvotes": downvotes,
            "report_status": status,
            "safety_score": score_res['safety_score'],
            "message": f"Vote recorded. Incident report is now {status}."
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error voting on report: {str(e)}")
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
        allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'video/mp4', 'audio/mp3', 'audio/wav', 'audio/m4a']
        if file.content_type not in allowed_types:
            raise HTTPException(status_code=400, detail="Invalid file type")
        
        # Validate file size (max 10MB)
        if len(contents) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large (max 10MB)")
        
        # Upload to Storage
        filename = f"evidence_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file.filename}"
        file_url = firebase.upload_file(contents, filename)
        
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
    limit: int = 50,
    days: Optional[int] = None,
    category: Optional[str] = None
):
    """Get incident reports near location with timeline and category filters"""
    try:
        incidents = firebase.get_incident_reports(lat, lng, radius)
        
        # Filter by timeline (recency)
        if days:
            cutoff = datetime.now() - timedelta(days=days)
            filtered = []
            for inc in incidents:
                inc_time_str = inc.get('timestamp', '')
                try:
                    if isinstance(inc_time_str, datetime):
                        inc_time = inc_time_str
                    else:
                        inc_time = datetime.fromisoformat(inc_time_str.replace('Z', ''))
                    if inc_time >= cutoff:
                        filtered.append(inc)
                except Exception:
                    filtered.append(inc)
            incidents = filtered

        # Filter by category
        if category:
            incidents = [
                i for i in incidents 
                if (i.get('category') or i.get('incident_type', '')).lower() == category.lower()
            ]

        # Filter out rejected reports from public view
        incidents = [i for i in incidents if i.get('status') != 'rejected']
        
        high_risk = [i for i in incidents if i.get('severity') == 'high']
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
async def get_heatmap_data(
    lat: float, 
    lng: float, 
    radius: float = 10,
    days: Optional[int] = None,
    category: Optional[str] = None
):
    """Get heatmap data for unsafe areas, applying weight decay and filters"""
    try:
        incidents = firebase.get_incident_reports(lat, lng, radius)
        
        # Filter by timeline (recency)
        if days:
            cutoff = datetime.now() - timedelta(days=days)
            filtered = []
            for inc in incidents:
                inc_time_str = inc.get('timestamp', '')
                try:
                    if isinstance(inc_time_str, datetime):
                        inc_time = inc_time_str
                    else:
                        inc_time = datetime.fromisoformat(inc_time_str.replace('Z', ''))
                    if inc_time >= cutoff:
                        filtered.append(inc)
                except Exception:
                    filtered.append(inc)
            incidents = filtered

        # Filter by category
        if category:
            incidents = [
                i for i in incidents 
                if (i.get('category') or i.get('incident_type', '')).lower() == category.lower()
            ]

        # Process data for heatmap
        heatmap_data = []
        for incident in incidents:
            if incident.get('status') == 'rejected':
                continue
                
            # Calculate dynamic weight based on recency and verification status
            status = incident.get('status', 'pending').lower()
            verify_weight = 1.0 if status == 'verified' else 0.5
            
            # Recency decay weight: weight = e^(-t/15)
            recency_weight = 1.0
            try:
                rep_time_str = incident.get('timestamp', '')
                if isinstance(rep_time_str, datetime):
                    rep_time = rep_time_str
                else:
                    rep_time = datetime.fromisoformat(rep_time_str.replace('Z', ''))
                days_old = (datetime.now() - rep_time).days
                recency_weight = math.exp(-max(0, days_old) / 15.0)
            except Exception:
                pass
                
            final_weight = verify_weight * recency_weight
            if final_weight > 0.05: # ignore expired/negligible weight reports
                # Local safety score details
                police = firebase.get_nearby_police_stations(lat, lng)
                hospitals = firebase.get_nearby_hospitals(lat, lng)
                calc = SafetyScoreCalculator(police_stations=police, hospitals=hospitals)
                score_res = calc.calculate_score(incident.get('latitude'), incident.get('longitude'), incidents)

                heatmap_data.append({
                    "id": incident.get('id'),
                    "latitude": incident.get('latitude'),
                    "longitude": incident.get('longitude'),
                    "weight": round(final_weight, 2),
                    "severity": incident.get('severity', 'medium'),
                    "type": incident.get('incident_type', 'Unknown'),
                    "category": incident.get('category', 'Harassment'),
                    "status": incident.get('status', 'pending'),
                    "safety_score": score_res["safety_score"],
                    "risk_level": score_res["status"],
                    "color": score_res["color_code"],
                    "upvotes": incident.get('upvotes', 0),
                    "downvotes": incident.get('downvotes', 0),
                    "description": incident.get('description', '')
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
        logger.error(f"Error generating heatmap data: {str(e)}")
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