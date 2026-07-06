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

    def detect_spam_and_duplicate(self, new_report: Dict, nearby_reports: List[Dict]) -> Dict:
        """Run AI duplicate and spam detection for safety reports"""
        try:
            # Basic local text preprocessing & checking for simple rule fallback
            desc = new_report.get('description', '').strip().lower()
            
            # Local Spam Rules Check
            spam_keywords = ['buy', 'click here', 'promo', 'discount', 'free money', 'test report', 'asdf', 'qwerty', 'testing 123']
            is_local_spam = len(desc) < 10 or any(kw in desc for kw in spam_keywords)
            
            # Local Duplicate Check (within 200m and same category, last 24 hours)
            is_local_duplicate = False
            duplicate_id = None
            for rep in nearby_reports:
                # Same category/type
                if rep.get('incident_type', '').lower() == new_report.get('incident_type', '').lower():
                    # Proximity check
                    lat_diff = abs(float(rep.get('latitude', 0)) - float(new_report.get('latitude', 0)))
                    lng_diff = abs(float(rep.get('longitude', 0)) - float(new_report.get('longitude', 0)))
                    if lat_diff < 0.002 and lng_diff < 0.002: # roughly 200m
                        # Word overlap or exact match
                        old_desc = rep.get('description', '').lower()
                        if desc == old_desc or (len(desc) > 20 and old_desc in desc) or (len(old_desc) > 20 and desc in old_desc):
                            is_local_duplicate = True
                            duplicate_id = rep.get('id')
                            break

            # AI API Analysis
            nearby_list = [{"id": r.get("id"), "description": r.get("description"), "lat": r.get("latitude"), "lng": r.get("longitude")} for r in nearby_reports[:5]]
            
            prompt = f"""
            Analyze the following new incident report for spam, vulgarity, or if it is a duplicate of any recent nearby reports.
            
            New Report:
            - Category: {new_report.get('incident_type')}
            - Description: "{new_report.get('description')}"
            - Coordinates: ({new_report.get('latitude')}, {new_report.get('longitude')})
            
            Recent Nearby Reports:
            {json.dumps(nearby_list)}
            
            Determine:
            1. If the new report is SPAM (meaningless, gibberish, promotional, testing, or irrelevant text).
            2. If the new report is a DUPLICATE of an already reported nearby incident (describes the exact same specific event at the exact same location).
            
            Return a JSON object ONLY, with fields:
            - is_spam (boolean)
            - is_duplicate (boolean)
            - duplicate_report_id (string or null, matching the nearby report id if it's a duplicate)
            - confidence_score (number between 0 and 100)
            - reason (string explaining the decision)
            """
            
            response = self.model.generate_content(prompt)
            # Remove markdown wraps if any
            clean_text = response.text.replace('```json', '').replace('```', '').strip()
            result = json.loads(clean_text)
            return result
        except Exception as e:
            logger.error(f"Error in detect_spam_and_duplicate: {str(e)}")
            # Fallback to local rule-based results if AI fails or key not config
            return {
                "is_spam": is_local_spam,
                "is_duplicate": is_local_duplicate,
                "duplicate_report_id": duplicate_id,
                "confidence_score": 90 if (is_local_spam or is_local_duplicate) else 50,
                "reason": "AI engine offline. SafeSphere rule-based safety screening applied."
            }