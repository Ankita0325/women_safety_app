# backend/app/routes/routes_ai.py

from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Optional
from app.models.schemas import RouteRequest, RouteResponse
from app.services.firebase_service import FirebaseService
from app.services.route_service import RouteService
from app.services.ai_service import AIService
from app.utils.config import settings
from datetime import datetime
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

firebase = FirebaseService()
route_service = RouteService()
ai_service = AIService()

@router.post("/safe-route", response_model=RouteResponse)
async def generate_safe_route(request: RouteRequest):
    """Calculate safest route avoiding unsafe crime/harassment zones"""
    try:
        start_coords = (request.start_lat, request.start_lng)
        end_coords = (request.end_lat, request.end_lng)
        
        # 1. Fetch unsafe zones (incidents) from database
        unsafe_incidents = firebase.get_incident_reports(
            lat=request.start_lat, 
            lng=request.start_lng, 
            radius_km=10.0
        )
        
        # Format unsafe areas for pathfinding
        unsafe_areas = []
        for incident in unsafe_incidents:
            unsafe_areas.append({
                "lat": incident.get("latitude"),
                "lng": incident.get("longitude"),
                "severity": incident.get("severity", "medium")
            })
            
        # 2. Fetch nearby police and hospital services
        police = firebase.get_nearby_police_stations(request.start_lat, request.start_lng, limit=10)
        hospitals = firebase.get_nearby_hospitals(request.start_lat, request.start_lng, limit=10)
        
        # 3. Calculate safe route using A* pathfinder
        route_info = route_service.find_safe_route(
            start=start_coords,
            end=end_coords,
            unsafe_areas=unsafe_areas,
            police_stations=police,
            hospitals=hospitals
        )
        
        # 4. Format waypoints from Tuple[(lat, lng)] to Dict[latitude, longitude] for Flutter model compatibility
        formatted_waypoints = []
        for wp in route_info.get("waypoints", []):
            # Check if wp is already a dict, otherwise it's a tuple
            if isinstance(wp, dict):
                formatted_waypoints.append({
                    "latitude": wp.get("latitude") or wp.get("lat"),
                    "longitude": wp.get("longitude") or wp.get("lng"),
                    "safety_score": wp.get("safety_score", 100),
                    "risk_level": wp.get("risk_level", "Safe"),
                    "color": wp.get("color", "green")
                })
            elif isinstance(wp, (tuple, list)) and len(wp) >= 2:
                formatted_waypoints.append({
                    "latitude": wp[0],
                    "longitude": wp[1],
                    "safety_score": 90,
                    "risk_level": "Safe",
                    "color": "green"
                })
                
        # 5. Format nearby services to match expected structure
        police_stations_nearby = []
        for p in route_info.get("police_stations_nearby", []):
            police_stations_nearby.append({
                "name": p.get("name"),
                "lat": p.get("lat"),
                "lng": p.get("lng"),
                "phone": p.get("phone", "100"),
                "distance": p.get("distance", 0.0),
                "type": "police"
            })
            
        hospitals_nearby = []
        for h in route_info.get("hospitals_nearby", []):
            hospitals_nearby.append({
                "name": h.get("name"),
                "lat": h.get("lat"),
                "lng": h.get("lng"),
                "phone": h.get("phone", "112"),
                "distance": h.get("distance", 0.0),
                "type": "hospital"
            })

        # Calculate dummy polyline for compatibility
        # In a real environment, this is the encoded path polyline
        polyline = f"polyline_enc_{len(formatted_waypoints)}"

        # Generate sample steps for navigation instruction
        steps = [
            {"instruction": "Depart from current location", "distance": 0, "duration": 0},
            {"instruction": "Walk towards main transit hub via safe zone", "distance": int(route_info.get("distance", 1.0) * 400), "duration": int(route_info.get("estimated_time", 10) * 0.4)},
            {"instruction": "Arrive safely at destination", "distance": int(route_info.get("distance", 1.0) * 600), "duration": int(route_info.get("estimated_time", 10) * 0.6)}
        ]
        
        return RouteResponse(
            route_polyline=polyline,
            distance=route_info.get("distance", 1.0),
            duration=int(route_info.get("estimated_time", 15)),
            safe_score=int(route_info.get("safety_score", 75)),
            steps=steps,
            waypoints=formatted_waypoints,
            warnings=route_info.get("warnings", []),
            police_stations_nearby=police_stations_nearby,
            hospitals_nearby=hospitals_nearby
        )
    except Exception as e:
        logger.error(f"Error generating safe route: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/nearby-safe-zones")
async def get_nearby_safe_zones(lat: float, lng: float, radius: float = 5):
    """Retrieve verified safe zones nearby"""
    try:
        zones = firebase.get_safe_zones(lat, lng, limit=5)
        return {
            "status": "success",
            "safe_zones": zones,
            "count": len(zones)
        }
    except Exception as e:
        logger.error(f"Error fetching safe zones: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/route-safety-score")
async def get_route_safety_score(lat: float, lng: float):
    """Fetch location safety score calculated by AI engine"""
    try:
        # Use AI service to analyze location safety
        analysis = ai_service.analyze_safety({
            "lat": lat,
            "lng": lng,
            "time": datetime.now().isoformat()
        })
        return {
            "status": "success",
            "safety_score": analysis.get("safety_score", 75),
            "risk_level": analysis.get("risk_level", "medium"),
            "factors": analysis.get("factors_affecting_safety", []),
            "recommendations": analysis.get("recommendations", [])
        }
    except Exception as e:
        logger.error(f"Error calculating safety score: {str(e)}")
        # Safe fallback
        return {
            "status": "fallback",
            "safety_score": 75,
            "risk_level": "medium",
            "factors": ["Data connection issue. SafeSphere safe fallback applied."],
            "recommendations": ["Stay near well-lit public streets."]
        }