from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/trends")
async def get_safety_trends(days: int = 30):
    """Get safety trends for the past N days"""
    try:
        # Generate sample trend data
        data = []
        for i in range(days):
            date = datetime.now() - timedelta(days=days-i)
            data.append({
                "date": date.isoformat()[:10],
                "incidents": 10 + i % 5,
                "emergencies": 2 + i % 3,
                "safety_score": 65 + (i % 10)
            })
        
        return {
            "trends": data,
            "period": f"{days} days",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/hotspots")
async def get_safety_hotspots():
    """Get current safety hotspots"""
    try:
        return {
            "hotspots": [
                {
                    "location": "Andheri West",
                    "lat": 19.1179,
                    "lng": 72.8488,
                    "risk_level": "high",
                    "incidents": 12
                },
                {
                    "location": "Bandra",
                    "lat": 19.0544,
                    "lng": 72.8401,
                    "risk_level": "medium",
                    "incidents": 8
                }
            ],
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))