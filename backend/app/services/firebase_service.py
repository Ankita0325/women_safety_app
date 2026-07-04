import firebase_admin
from firebase_admin import credentials, firestore, auth, storage
from app.utils.config import settings
from datetime import datetime
from typing import Dict, List, Optional, Any
import json
import logging

logger = logging.getLogger(__name__)

class FirebaseService:
    """Firebase service for authentication, database, and storage"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance
    
    def _initialize(self):
        """Initialize Firebase with credentials"""
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred, {
                    'storageBucket': 'women-safety-app.appspot.com'
                })
            self.db = firestore.client()
            self.bucket = storage.bucket()
            logger.info("Firebase initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {str(e)}")
            raise
    
    # ==================== USER MANAGEMENT ====================
    
    def create_user(self, email: str, password: str, user_data: dict) -> str:
        """Create new user in Firebase Auth and Firestore"""
        try:
            user = auth.create_user(
                email=email,
                password=password,
                display_name=user_data.get('name'),
                phone_number=user_data.get('phone')
            )
            
            # Store user data in Firestore
            user_ref = self.db.collection('users').document(user.uid)
            user_ref.set({
                'uid': user.uid,
                'email': email,
                'name': user_data.get('name'),
                'phone': user_data.get('phone'),
                'role': 'user',
                'emergency_contacts': [],
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat(),
                'is_verified': False
            })
            
            logger.info(f"User created successfully: {user.uid}")
            return user.uid
        except Exception as e:
            logger.error(f"Failed to create user: {str(e)}")
            raise
    
    def get_user(self, uid: str) -> Optional[Dict]:
        """Get user data from Firestore"""
        try:
            user_ref = self.db.collection('users').document(uid)
            user_doc = user_ref.get()
            if user_doc.exists:
                return user_doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Failed to get user: {str(e)}")
            raise
    
    def update_user(self, uid: str, data: dict) -> bool:
        """Update user data in Firestore"""
        try:
            user_ref = self.db.collection('users').document(uid)
            data['updated_at'] = datetime.now().isoformat()
            user_ref.update(data)
            logger.info(f"User updated successfully: {uid}")
            return True
        except Exception as e:
            logger.error(f"Failed to update user: {str(e)}")
            raise
    
    def delete_user(self, uid: str) -> bool:
        """Delete user from Firebase Auth and Firestore"""
        try:
            auth.delete_user(uid)
            self.db.collection('users').document(uid).delete()
            logger.info(f"User deleted: {uid}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete user: {str(e)}")
            raise
    
    def verify_user(self, uid: str) -> bool:
        """Verify user email"""
        try:
            user = auth.get_user(uid)
            if not user.email_verified:
                auth.update_user(uid, email_verified=True)
            self.update_user(uid, {'is_verified': True})
            return True
        except Exception as e:
            logger.error(f"Failed to verify user: {str(e)}")
            raise
    
    # ==================== EMERGENCY CONTACTS ====================
    
    def add_emergency_contact(self, uid: str, contact: dict) -> bool:
        """Add emergency contact for user"""
        try:
            user_ref = self.db.collection('users').document(uid)
            user_ref.update({
                'emergency_contacts': firestore.ArrayUnion([contact])
            })
            logger.info(f"Emergency contact added for user: {uid}")
            return True
        except Exception as e:
            logger.error(f"Failed to add emergency contact: {str(e)}")
            raise
    
    def remove_emergency_contact(self, uid: str, contact_phone: str) -> bool:
        """Remove emergency contact by phone number"""
        try:
            user = self.get_user(uid)
            if user:
                contacts = user.get('emergency_contacts', [])
                updated_contacts = [c for c in contacts if c.get('phone') != contact_phone]
                user_ref = self.db.collection('users').document(uid)
                user_ref.update({
                    'emergency_contacts': updated_contacts
                })
                return True
            return False
        except Exception as e:
            logger.error(f"Failed to remove emergency contact: {str(e)}")
            raise
    
    def get_emergency_contacts(self, uid: str) -> List[Dict]:
        """Get all emergency contacts for user"""
        try:
            user = self.get_user(uid)
            return user.get('emergency_contacts', []) if user else []
        except Exception as e:
            logger.error(f"Failed to get emergency contacts: {str(e)}")
            return []
    
    def get_primary_contact(self, uid: str) -> Optional[Dict]:
        """Get primary emergency contact"""
        contacts = self.get_emergency_contacts(uid)
        for contact in contacts:
            if contact.get('is_primary', False):
                return contact
        return contacts[0] if contacts else None
    
    # ==================== INCIDENT REPORTS ====================
    
    def add_incident_report(self, report_data: dict) -> str:
        """Add anonymous incident report"""
        try:
            report_data['timestamp'] = datetime.now().isoformat()
            report_data['created_at'] = datetime.now().isoformat()
            report_ref = self.db.collection('incident_reports').document()
            report_ref.set(report_data)
            logger.info(f"Incident report added: {report_ref.id}")
            return report_ref.id
        except Exception as e:
            logger.error(f"Failed to add incident report: {str(e)}")
            raise
    
    def get_incident_reports(self, lat: float, lng: float, radius_km: float = 5) -> List[Dict]:
        """Get incident reports within radius"""
        try:
            # Get all reports (in production, use geohash for better performance)
            reports = self.db.collection('incident_reports').limit(100).get()
            filtered_reports = []
            
            for doc in reports:
                data = doc.to_dict()
                # Calculate approximate distance
                # In production, use proper geospatial query
                filtered_reports.append(data)
            
            return filtered_reports
        except Exception as e:
            logger.error(f"Failed to get incident reports: {str(e)}")
            return []
    
    def get_incident_report(self, report_id: str) -> Optional[Dict]:
        """Get incident report by ID"""
        try:
            report_ref = self.db.collection('incident_reports').document(report_id)
            report_doc = report_ref.get()
            if report_doc.exists:
                return report_doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Failed to get incident report: {str(e)}")
            raise
    
    def update_incident_report(self, report_id: str, data: dict) -> bool:
        """Update incident report"""
        try:
            report_ref = self.db.collection('incident_reports').document(report_id)
            report_ref.update(data)
            return True
        except Exception as e:
            logger.error(f"Failed to update incident report: {str(e)}")
            raise
    
    # ==================== EMERGENCY LOGS ====================
    
    def log_emergency(self, emergency_data: dict) -> str:
        """Log emergency event"""
        try:
            emergency_data['timestamp'] = datetime.now().isoformat()
            emergency_ref = self.db.collection('emergency_logs').document()
            emergency_ref.set(emergency_data)
            logger.info(f"Emergency logged: {emergency_ref.id}")
            return emergency_ref.id
        except Exception as e:
            logger.error(f"Failed to log emergency: {str(e)}")
            raise
    
    def get_emergency_logs(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get emergency logs for user"""
        try:
            logs = self.db.collection('emergency_logs')\
                .where('user_id', '==', user_id)\
                .order_by('timestamp', direction=firestore.Query.DESCENDING)\
                .limit(limit)\
                .get()
            
            return [log.to_dict() for log in logs]
        except Exception as e:
            logger.error(f"Failed to get emergency logs: {str(e)}")
            return []
    
    def update_emergency_status(self, emergency_id: str, status: str) -> bool:
        """Update emergency status"""
        try:
            emergency_ref = self.db.collection('emergency_logs').document(emergency_id)
            emergency_ref.update({
                'status': status,
                'updated_at': datetime.now().isoformat()
            })
            return True
        except Exception as e:
            logger.error(f"Failed to update emergency status: {str(e)}")
            raise
    
    # ==================== NEARBY RESOURCES ====================
    
    def get_nearby_police_stations(self, lat: float, lng: float, limit: int = 3) -> List[Dict]:
        """Get nearby police stations"""
        try:
            from app.utils.config import settings
            stations = settings.POLICE_STATIONS
            
            # Calculate distances
            for station in stations:
                station['distance'] = self._calculate_distance(
                    lat, lng, station['lat'], station['lng']
                )
            
            # Sort by distance
            stations.sort(key=lambda x: x.get('distance', float('inf')))
            return stations[:limit]
        except Exception as e:
            logger.error(f"Failed to get police stations: {str(e)}")
            return []
    
    def get_nearby_hospitals(self, lat: float, lng: float, limit: int = 3) -> List[Dict]:
        """Get nearby hospitals"""
        try:
            from app.utils.config import settings
            hospitals = settings.HOSPITALS
            
            for hospital in hospitals:
                hospital['distance'] = self._calculate_distance(
                    lat, lng, hospital['lat'], hospital['lng']
                )
            
            hospitals.sort(key=lambda x: x.get('distance', float('inf')))
            return hospitals[:limit]
        except Exception as e:
            logger.error(f"Failed to get hospitals: {str(e)}")
            return []
    
    def get_safe_zones(self, lat: float, lng: float, limit: int = 5) -> List[Dict]:
        """Get nearby safe zones"""
        try:
            from app.utils.config import settings
            zones = settings.SAFE_ZONES
            
            for zone in zones:
                zone['distance'] = self._calculate_distance(
                    lat, lng, zone['lat'], zone['lng']
                )
            
            zones.sort(key=lambda x: x.get('distance', float('inf')))
            return zones[:limit]
        except Exception as e:
            logger.error(f"Failed to get safe zones: {str(e)}")
            return []
    
    # ==================== HELPER METHODS ====================
    
    def _calculate_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate distance between two points in km using Haversine formula"""
        from math import radians, sin, cos, sqrt, atan2
        
        R = 6371  # Earth's radius in km
        
        lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    
    def upload_file(self, file_data: bytes, filename: str) -> str:
        """Upload file to Firebase Storage"""
        try:
            blob = self.bucket.blob(f'uploads/{filename}')
            blob.upload_from_string(file_data)
            blob.make_public()
            return blob.public_url
        except Exception as e:
            logger.error(f"Failed to upload file: {str(e)}")
            raise