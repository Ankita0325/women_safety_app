import math
from datetime import datetime
from typing import List, Dict, Tuple
import logging

logger = logging.getLogger(__name__)

class SafetyScoreCalculator:
    """Calculates Safety Score (0-100) for coordinates based on multiple factors"""

    def __init__(self, police_stations: List[Dict] = None, hospitals: List[Dict] = None, help_centers: List[Dict] = None):
        # Fallbacks for emergency services if not passed
        self.police_stations = police_stations or []
        self.hospitals = hospitals or []
        self.help_centers = help_centers or [
            {"name": "Women Help Center Bandra", "lat": 19.0544, "lng": 72.8401, "phone": "1091"},
            {"name": "Sneh Women Support Centre", "lat": 19.1179, "lng": 72.8488, "phone": "1091"},
            {"name": "St. Catherine Home Support", "lat": 18.9604, "lng": 72.8350, "phone": "1091"},
        ]

    def _calculate_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate distance in km using Haversine formula"""
        R = 6371.0  # Earth radius
        lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = math.sin(dlat / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    def calculate_score(self, lat: float, lng: float, reports: List[Dict], current_time: datetime = None) -> Dict:
        """
        Calculate Safety Score between 0 and 100
        - Base: 90 points
        - Subtracts for incidents depending on severity, recency, and verification status.
        - Adds bonuses for nearby safety infrastructure.
        - Captures activity level & rating impacts.
        """
        if current_time is None:
            current_time = datetime.now()

        # Start with a pristine base score
        score = 90.0
        
        # Tracking factors
        incident_penalty = 0.0
        sos_penalty = 0.0
        police_bonus = 0.0
        hospital_bonus = 0.0
        help_center_bonus = 0.0
        
        num_complaints = 0
        num_verified_reports = 0
        num_sos = 0

        # 1. Process Incident Reports
        for report in reports:
            rep_lat = float(report.get('latitude', 0))
            rep_lng = float(report.get('longitude', 0))
            
            # Distance from target location
            dist = self._calculate_distance(lat, lng, rep_lat, rep_lng)
            if dist > 3.0: # Only count within 3km radius
                continue
                
            num_complaints += 1

            # Severity multiplier
            severity = report.get('severity', 'medium').lower()
            if severity == 'high':
                base_penalty = 15.0
            elif severity == 'low':
                base_penalty = 3.0
            else: # medium
                base_penalty = 7.0
                
            # If it's a verified harassment or assault report, increase penalty
            inc_type = report.get('incident_type', '').lower()
            if any(term in inc_type for term in ['harassment', 'assault', 'stalking']):
                base_penalty *= 1.25

            # Verification multiplier
            status = report.get('status', 'pending').lower()
            if status == 'verified':
                verify_factor = 1.0
                num_verified_reports += 1
            elif status == 'rejected':
                verify_factor = 0.0
            else: # pending
                verify_factor = 0.5

            # Time Decay (expires after 30 days)
            # weight = e^(-t/T) where T = 15 days for quick recovery
            rep_time_str = report.get('timestamp', '')
            try:
                if isinstance(rep_time_str, datetime):
                    rep_time = rep_time_str
                else:
                    rep_time = datetime.fromisoformat(rep_time_str.replace('Z', ''))
                days_old = (current_time - rep_time).days
                days_old = max(0, days_old)
                decay = math.exp(-days_old / 15.0)
            except Exception:
                decay = 0.5 # Default half decay if time parsing fails

            # Night Penalty: incidents that happen at night (6 PM to 6 AM) have a slightly higher weight
            night_factor = 1.0
            try:
                if 18 <= rep_time.hour or rep_time.hour <= 6:
                    night_factor = 1.2
            except Exception:
                pass

            # Distance decay: closer incidents have a much higher impact
            # penalty is divided by (1 + distance_in_km)
            dist_factor = 1.0 / (1.0 + dist)

            # Accumulate penalty
            incident_penalty += base_penalty * verify_factor * decay * night_factor * dist_factor

        # 2. Process SOS Activations (High penalty, only look for very recent ones within 1.5km)
        for report in reports:
            if report.get('incident_type', '').lower() == 'sos':
                rep_lat = float(report.get('latitude', 0))
                rep_lng = float(report.get('longitude', 0))
                dist = self._calculate_distance(lat, lng, rep_lat, rep_lng)
                if dist <= 1.5:
                    num_sos += 1
                    sos_penalty += 25.0 / (1.0 + dist)

        # Apply incident & SOS penalties
        score -= (incident_penalty + sos_penalty)

        # 3. Add Infrastructure Bonuses
        # Police Stations (within 1.5km, up to +5 points each, max +15)
        for station in self.police_stations:
            dist = self._calculate_distance(lat, lng, station.get('lat', 0), station.get('lng', 0))
            if dist <= 1.5:
                police_bonus += 5.0 * (1.0 - dist / 1.5)
        score += min(15.0, police_bonus)

        # Hospitals (within 2km, up to +3 points each, max +10)
        for hospital in self.hospitals:
            dist = self._calculate_distance(lat, lng, hospital.get('lat', 0), hospital.get('lng', 0))
            if dist <= 2.0:
                hospital_bonus += 3.0 * (1.0 - dist / 2.0)
        score += min(10.0, hospital_bonus)

        # Women Help Centers (within 2km, up to +5 points each, max +15)
        for center in self.help_centers:
            dist = self._calculate_distance(lat, lng, center.get('lat', 0), center.get('lng', 0))
            if dist <= 2.0:
                help_center_bonus += 5.0 * (1.0 - center.get('distance', dist) / 2.0)
        score += min(15.0, help_center_bonus)

        # 4. Activity levels & community safety ratings adjust
        is_night = False
        try:
            hour = current_time.hour
            if hour >= 18 or hour <= 6:
                is_night = True
        except Exception:
            pass

        if is_night:
            # Drop score by up to 10 points depending on how far the nearest police station is
            min_police_dist = 999.0
            for station in self.police_stations:
                dist = self._calculate_distance(lat, lng, station.get('lat', 0), station.get('lng', 0))
                if dist < min_police_dist:
                    min_police_dist = dist
            
            if min_police_dist > 1.0:
                score -= min(10.0, 5.0 * (min_police_dist - 1.0))

        # Clamp score between 0 and 100
        score = max(0.0, min(100.0, score))
        final_score = int(round(score))

        # Determine Safety Level Status
        if final_score >= 80:
            status_level = "Safe"
            color_code = "green"
        elif final_score >= 60:
            status_level = "Low Risk"
            color_code = "yellow"
        elif final_score >= 40:
            status_level = "Medium Risk"
            color_code = "orange"
        else:
            status_level = "High Risk"
            color_code = "red"

        # AI confidence score (simulated representation based on data density)
        ai_confidence = 100 - min(40, num_complaints * 5)

        return {
            "safety_score": final_score,
            "status": status_level,
            "color_code": color_code,
            "complaints_count": num_complaints,
            "verified_reports_count": num_verified_reports,
            "sos_count": num_sos,
            "factors": {
                "incident_penalty": round(incident_penalty, 2),
                "sos_penalty": round(sos_penalty, 2),
                "police_bonus": round(police_bonus, 2),
                "hospital_bonus": round(hospital_bonus, 2),
                "help_center_bonus": round(help_center_bonus, 2),
                "is_night": is_night
            },
            "ai_confidence_score": ai_confidence
        }
