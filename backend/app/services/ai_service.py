import google.generativeai as genai
from app.utils.config import settings
import json
from typing import Dict, List, Any, Optional
import logging

logger = logging.getLogger(__name__)

class AIService:
    """AI service using Google Gemini API"""
    
    def __init__(self):
        try:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            self.model = genai.GenerativeModel('gemini-pro')
            logger.info("AI Service initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize AI Service: {str(e)}")
            raise
    
    def analyze_safety(self, location_data: Dict) -> Dict:
        """Analyze safety of a location using AI"""
        try:
            prompt = f"""
            Analyze the safety of this location:
            Latitude: {location_data.get('lat')}
            Longitude: {location_data.get('lng')}
            Time: {location_data.get('time', 'unknown')}
            Day: {location_data.get('day', 'unknown')}
            
            Consider these factors:
            1. Crime rate in the area
            2. Lighting conditions (street lights)
            3. Crowd presence and foot traffic
            4. Nearby emergency services
            5. Recent incident reports
            
            Return a JSON with:
            - safety_score (0-100)
            - risk_level (low/medium/high)
            - factors_affecting_safety (list of strings)
            - recommendations (list of strings)
            - nearby_police (number)
            - nearby_hospitals (number)
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in analyze_safety: {str(e)}")
            return {
                "error": str(e),
                "safety_score": 50,
                "risk_level": "medium"
            }
    
    def generate_safe_route(self, start: Dict, end: Dict, unsafe_areas: List[Dict] = None) -> Dict:
        """Generate safe route using AI"""
        try:
            unsafe_areas_str = json.dumps(unsafe_areas) if unsafe_areas else "None reported"
            
            prompt = f"""
            Generate a safe route from:
            Start: {json.dumps(start)}
            End: {json.dumps(end)}
            
            Avoid these unsafe areas: {unsafe_areas_str}
            
            Consider:
            1. Well-lit streets
            2. High foot traffic areas
            3. Nearby police stations
            4. Public transportation availability
            5. Street safety ratings
            
            Return JSON with:
            - route_points (list of [lat, lng] coordinates)
            - safety_score (0-100)
            - estimated_time (minutes)
            - warnings (list of strings)
            - alternative_routes (list of route objects)
            - landmarks_nearby (list of landmarks)
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in generate_safe_route: {str(e)}")
            return {
                "error": str(e),
                "route_points": [[start.get('lat'), start.get('lng')], [end.get('lat'), end.get('lng')]],
                "safety_score": 50,
                "estimated_time": 30
            }
    
    def detect_distress_in_audio(self, audio_text: str) -> Dict:
        """Detect distress in transcribed audio"""
        try:
            prompt = f"""
            Analyze this transcribed audio for signs of distress:
            "{audio_text}"
            
            Check for:
            1. Fear indicators in voice or words
            2. Emergency keywords
            3. Distress tone indicators
            4. Call for help
            5. Panic indicators
            
            Return JSON with:
            - distress_detected (boolean)
            - confidence_score (0-100)
            - detected_keywords (list of strings)
            - urgency_level (low/medium/high)
            - suggested_action (string)
            - emotion_analysis (string)
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in detect_distress_in_audio: {str(e)}")
            return {
                "error": str(e),
                "distress_detected": False,
                "confidence_score": 0
            }
    
    def get_domestic_violence_support(self, query: str) -> Dict:
        """Get support information for domestic violence"""
        try:
            prompt = f"""
            Provide information about domestic violence support:
            Query: {query}
            
            Include structured information about:
            1. Legal rights and laws
            2. Protection orders process
            3. Helpline numbers (country-specific)
            4. Nearby support organizations
            5. Steps to take in emergency
            6. Safety planning guide
            7. Counseling resources
            
            Return JSON with structured information.
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in get_domestic_violence_support: {str(e)}")
            return {
                "error": str(e),
                "helpline": "Please call 100 (Police) or 1091 (Women's Helpline)"
            }
    
    def generate_emergency_response_plan(self, user_data: Dict, location: Dict) -> Dict:
        """Generate personalized emergency response plan"""
        try:
            prompt = f"""
            Generate a personalized emergency response plan for:
            User: {json.dumps(user_data)}
            Location: {json.dumps(location)}
            
            Include:
            1. Immediate actions to take
            2. Self-defense tips
            3. Communication script for emergency services
            4. Safe places nearby
            5. What to do if separated from phone
            6. How to get help without alarming the attacker
            
            Return JSON with structured response plan.
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in generate_emergency_response_plan: {str(e)}")
            return {"error": str(e)}
    
    def analyze_incident_report(self, report: Dict) -> Dict:
        """Analyze incident report for patterns and insights"""
        try:
            prompt = f"""
            Analyze this incident report:
            {json.dumps(report)}
            
            Provide insights on:
            1. Pattern analysis
            2. Severity assessment
            3. Risk factors
            4. Recommendations
            5. Similar incidents
            
            Return JSON with analysis.
            """
            
            response = self.model.generate_content(prompt)
            result = json.loads(response.text)
            return result
        except Exception as e:
            logger.error(f"Error in analyze_incident_report: {str(e)}")
            return {"error": str(e)}