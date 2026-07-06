import os
import firebase_admin
from firebase_admin import credentials, firestore, auth, storage
from app.utils.config import settings
from datetime import datetime
from typing import Dict, List, Optional, Any
import json
import logging

logger = logging.getLogger(__name__)

class FirebaseService:
    """Firebase service for authentication, database, and storage with SQLite fallback"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance
    
    def _initialize(self):
        """Initialize Firebase with credentials, fallback to SQLite mock mode if missing"""
        self.use_mock = False
        try:
            if os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
                if not firebase_admin._apps:
                    cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                    firebase_admin.initialize_app(cred, {
                        'storageBucket': settings.FIREBASE_STORAGE_BUCKET
                    })
                self.db = firestore.client()
                self.bucket = storage.bucket()
                logger.info("Firebase initialized successfully")
            else:
                logger.warning(f"Firebase credentials not found at {settings.FIREBASE_CREDENTIALS_PATH}. Running in SQLite Mock mode.")
                self.use_mock = True
                self._init_sqlite_tables()
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {str(e)}. Running in SQLite Mock mode.")
            self.use_mock = True
            self._init_sqlite_tables()

    def _init_sqlite_tables(self):
        """Initialize local SQLite tables if running in mock mode"""
        try:
            from app.models.database import create_tables, SessionLocal, IncidentReportDB
            create_tables()
            logger.info("Local SQLite database initialized successfully for Mock mode")
            
            # Seed mock data if database is empty
            db = SessionLocal()
            if db.query(IncidentReportDB).count() == 0:
                logger.info("Seeding database with mock safety reports for SafeSphere...")
                from datetime import datetime, timedelta
                mock_reports = [
                    {
                        'id': 'seed_rep_1',
                        'incident_type': 'Harassment',
                        'description': 'Frequent catcalling and stalking reported under Bandra West flyover after dark.',
                        'latitude': 19.0480,
                        'longitude': 72.8310,
                        'address': 'Bandra West Flyover, Mumbai',
                        'is_anonymous': True,
                        'severity': 'high',
                        'status': 'verified',
                        'upvotes': 12,
                        'downvotes': 0,
                        'category': 'Harassment',
                        'safety_score': 32,
                        'expires_at': datetime.now() + timedelta(days=30),
                        'timestamp': datetime.now() - timedelta(days=1)
                    },
                    {
                        'id': 'seed_rep_2',
                        'incident_type': 'Poor Lighting',
                        'description': 'Khar Subway underpass has zero functional streetlights. Isolated and dark.',
                        'latitude': 19.0740,
                        'longitude': 72.8390,
                        'address': 'Khar Subway Underpass, Mumbai',
                        'is_anonymous': True,
                        'severity': 'high',
                        'status': 'verified',
                        'upvotes': 8,
                        'downvotes': 1,
                        'category': 'Poor Lighting',
                        'safety_score': 35,
                        'expires_at': datetime.now() + timedelta(days=30),
                        'timestamp': datetime.now() - timedelta(days=3)
                    },
                    {
                        'id': 'seed_rep_3',
                        'incident_type': 'Stalking',
                        'description': 'Suspicious group loitering and stalking pedestrians in isolated lanes near Andheri track.',
                        'latitude': 19.1020,
                        'longitude': 72.8550,
                        'address': 'Andheri East Dark Lane, Mumbai',
                        'is_anonymous': True,
                        'severity': 'high',
                        'status': 'verified',
                        'upvotes': 14,
                        'downvotes': 0,
                        'category': 'Stalking',
                        'safety_score': 25,
                        'expires_at': datetime.now() + timedelta(days=30),
                        'timestamp': datetime.now() - timedelta(days=2)
                    },
                    {
                        'id': 'seed_rep_4',
                        'incident_type': 'Unsafe Transport',
                        'description': 'Suspicious auto-rickshaw loitering reported on Juhu outer bypass street.',
                        'latitude': 19.0880,
                        'longitude': 72.8180,
                        'address': 'Juhu Outer Bypass Lane, Mumbai',
                        'is_anonymous': True,
                        'severity': 'medium',
                        'status': 'pending',
                        'upvotes': 4,
                        'downvotes': 0,
                        'category': 'Unsafe Transport',
                        'safety_score': 58,
                        'expires_at': datetime.now() + timedelta(days=30),
                        'timestamp': datetime.now() - timedelta(days=5)
                    },
                ]
                for r in mock_reports:
                    db.add(IncidentReportDB(
                        id=r['id'],
                        incident_type=r['incident_type'],
                        description=r['description'],
                        latitude=r['latitude'],
                        longitude=r['longitude'],
                        address=r['address'],
                        is_anonymous=r['is_anonymous'],
                        severity=r['severity'],
                        images=[],
                        timestamp=r['timestamp'],
                        user_id='seeder',
                        status=r['status'],
                        upvotes=r['upvotes'],
                        downvotes=r['downvotes'],
                        expires_at=r['expires_at'],
                        category=r['category'],
                        safety_score=r['safety_score'],
                        ai_analysis={}
                    ))
                db.commit()
                logger.info("Mock safety reports seeded successfully into SQLite.")
            db.close()
        except Exception as e:
            logger.error(f"Failed to initialize/seed SQLite tables: {str(e)}")

    # ==================== USER MANAGEMENT ====================
    
    def create_user(self, email: str, password: str, user_data: dict) -> str:
        """Create new user in Firebase Auth and Firestore, or SQLite fallback"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, User as DBUser
                db = SessionLocal()
                
                # Check if user already exists
                existing = db.query(DBUser).filter(DBUser.email == email).first()
                if existing:
                    db.close()
                    raise Exception("User already exists")
                    
                uid = f"mock_{int(datetime.now().timestamp())}_{email.split('@')[0]}"
                db_user = DBUser(
                    id=uid,
                    email=email,
                    name=user_data.get('name', 'Anonymous'),
                    phone=user_data.get('phone', ''),
                    role='user',
                    emergency_contacts=[],
                    is_verified=True,
                    firebase_uid=uid
                )
                db.add(db_user)
                db.commit()
                db.close()
                logger.info(f"Local user created successfully: {uid}")
                return uid
            except Exception as e:
                logger.error(f"Failed to create local user: {str(e)}")
                raise
                
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
        """Get user data from Firestore or SQLite"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, User as DBUser
                db = SessionLocal()
                db_user = db.query(DBUser).filter(DBUser.id == uid).first()
                if not db_user:
                    db.close()
                    return None
                res = {
                    'uid': db_user.id,
                    'email': db_user.email,
                    'name': db_user.name,
                    'phone': db_user.phone,
                    'role': db_user.role,
                    'emergency_contacts': db_user.emergency_contacts or [],
                    'created_at': db_user.created_at.isoformat() if db_user.created_at else None,
                    'updated_at': db_user.updated_at.isoformat() if db_user.updated_at else None,
                    'is_verified': db_user.is_verified
                }
                db.close()
                return res
            except Exception as e:
                logger.error(f"Failed to get local user: {str(e)}")
                return None

        try:
            user_ref = self.db.collection('users').document(uid)
            user_doc = user_ref.get()
            if user_doc.exists:
                return user_doc.to_dict()
            return None
        except Exception as e:
            logger.error(f"Failed to get user: {str(e)}")
            raise
    
    def _get_user_by_email(self, email: str) -> Optional[dict]:
        """Look up user by email in local database (Mock Mode helper)"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, User as DBUser
                db = SessionLocal()
                db_user = db.query(DBUser).filter(DBUser.email == email).first()
                if not db_user:
                    db.close()
                    return None
                res = {
                    'uid': db_user.id,
                    'email': db_user.email,
                    'name': db_user.name,
                    'phone': db_user.phone,
                    'role': db_user.role,
                    'emergency_contacts': db_user.emergency_contacts or [],
                    'created_at': db_user.created_at.isoformat() if db_user.created_at else None,
                    'updated_at': db_user.updated_at.isoformat() if db_user.updated_at else None,
                    'is_verified': db_user.is_verified
                }
                db.close()
                return res
            except Exception as e:
                logger.error(f"Failed to get local user by email: {str(e)}")
                return None
        return None

    def update_user(self, uid: str, data: dict) -> bool:
        """Update user data in Firestore or SQLite"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, User as DBUser
                db = SessionLocal()
                db_user = db.query(DBUser).filter(DBUser.id == uid).first()
                if db_user:
                    if 'name' in data: db_user.name = data['name']
                    if 'phone' in data: db_user.phone = data['phone']
                    if 'email' in data: db_user.email = data['email']
                    if 'role' in data: db_user.role = data['role']
                    if 'emergency_contacts' in data: db_user.emergency_contacts = data['emergency_contacts']
                    if 'is_verified' in data: db_user.is_verified = data['is_verified']
                    db_user.updated_at = datetime.now()
                    db.commit()
                    db.close()
                    logger.info(f"Local user updated successfully: {uid}")
                    return True
                db.close()
                return False
            except Exception as e:
                logger.error(f"Failed to update local user: {str(e)}")
                return False

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
        """Delete user from Auth and database"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, User as DBUser
                db = SessionLocal()
                db_user = db.query(DBUser).filter(DBUser.id == uid).first()
                if db_user:
                    db.delete(db_user)
                    db.commit()
                    db.close()
                    return True
                db.close()
                return False
            except Exception as e:
                logger.error(f"Failed to delete local user: {str(e)}")
                return False

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
        if self.use_mock:
            return self.update_user(uid, {'is_verified': True})
            
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
            user = self.get_user(uid)
            if user:
                contacts = user.get('emergency_contacts', [])
                # If new contact is primary, make all others non-primary
                if contact.get('is_primary', False):
                    for c in contacts:
                        c['is_primary'] = False
                
                # Check for duplicates by phone
                contacts = [c for c in contacts if c.get('phone') != contact.get('phone')]
                contacts.append(contact)
                
                return self.update_user(uid, {'emergency_contacts': contacts})
            return False
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
                return self.update_user(uid, {'emergency_contacts': updated_contacts})
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
        from datetime import datetime, timedelta
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, IncidentReportDB
                db = SessionLocal()
                report_id = f"rep_{int(datetime.now().timestamp())}"
                
                # Expiration calculation
                expires_at = None
                if report_data.get('expires_at'):
                    if isinstance(report_data['expires_at'], datetime):
                        expires_at = report_data['expires_at']
                    else:
                        expires_at = datetime.fromisoformat(report_data['expires_at'].replace('Z', ''))
                else:
                    expires_at = datetime.now() + timedelta(days=30)
                
                db_report = IncidentReportDB(
                    id=report_id,
                    incident_type=report_data.get('incident_type', 'General'),
                    description=report_data.get('description', ''),
                    latitude=float(report_data.get('latitude', 0.0)),
                    longitude=float(report_data.get('longitude', 0.0)),
                    address=report_data.get('address', ''),
                    is_anonymous=bool(report_data.get('is_anonymous', True)),
                    severity=report_data.get('severity', 'medium'),
                    images=report_data.get('images', []),
                    user_id=report_data.get('user_id', ''),
                    status=report_data.get('status', 'pending'),
                    upvotes=int(report_data.get('upvotes', 0)),
                    downvotes=int(report_data.get('downvotes', 0)),
                    expires_at=expires_at,
                    category=report_data.get('category', report_data.get('incident_type', 'Harassment')),
                    safety_score=int(report_data.get('safety_score', 100)),
                    ai_analysis=report_data.get('ai_analysis', {})
                )
                db.add(db_report)
                db.commit()
                db.close()
                logger.info(f"Local incident report added: {report_id}")
                return report_id
            except Exception as e:
                logger.error(f"Failed to add local incident report: {str(e)}")
                raise

        try:
            report_data['timestamp'] = datetime.now().isoformat()
            report_data['created_at'] = datetime.now().isoformat()
            if 'expires_at' not in report_data:
                report_data['expires_at'] = (datetime.now() + timedelta(days=30)).isoformat()
            report_ref = self.db.collection('incident_reports').document()
            report_ref.set(report_data)
            logger.info(f"Incident report added: {report_ref.id}")
            return report_ref.id
        except Exception as e:
            logger.error(f"Failed to add incident report: {str(e)}")
            raise
    
    def get_incident_reports(self, lat: float, lng: float, radius_km: float = 5) -> List[Dict]:
        """Get incident reports within radius (SQLite fallback)"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, IncidentReportDB
                db = SessionLocal()
                reports = db.query(IncidentReportDB).all()
                filtered_reports = []
                for r in reports:
                    # Filter by distance
                    dist = self._calculate_distance(lat, lng, r.latitude, r.longitude)
                    if dist <= radius_km:
                        filtered_reports.append({
                            'id': r.id,
                            'incident_type': r.incident_type,
                            'description': r.description,
                            'latitude': r.latitude,
                            'longitude': r.longitude,
                            'address': r.address,
                            'is_anonymous': r.is_anonymous,
                            'severity': r.severity,
                            'images': r.images or [],
                            'timestamp': r.timestamp.isoformat() if r.timestamp else datetime.now().isoformat(),
                            'user_id': r.user_id,
                            'status': r.status,
                            'upvotes': r.upvotes,
                            'downvotes': r.downvotes,
                            'expires_at': r.expires_at.isoformat() if r.expires_at else None,
                            'category': r.category,
                            'safety_score': r.safety_score,
                            'ai_analysis': r.ai_analysis or {}
                        })
                db.close()
                return filtered_reports
            except Exception as e:
                logger.error(f"Failed to get local incident reports: {str(e)}")
                return []

        try:
            reports = self.db.collection('incident_reports').limit(100).get()
            filtered_reports = []
            
            for doc in reports:
                data = doc.to_dict()
                data['id'] = doc.id
                # Calculate distance
                r_lat = data.get('latitude', 0.0)
                r_lng = data.get('longitude', 0.0)
                dist = self._calculate_distance(lat, lng, r_lat, r_lng)
                if dist <= radius_km:
                    filtered_reports.append(data)
            
            return filtered_reports
        except Exception as e:
            logger.error(f"Failed to get incident reports: {str(e)}")
            return []
    
    def get_incident_report(self, report_id: str) -> Optional[Dict]:
        """Get incident report by ID"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, IncidentReportDB
                db = SessionLocal()
                r = db.query(IncidentReportDB).filter(IncidentReportDB.id == report_id).first()
                if not r:
                    db.close()
                    return None
                res = {
                    'id': r.id,
                    'incident_type': r.incident_type,
                    'description': r.description,
                    'latitude': r.latitude,
                    'longitude': r.longitude,
                    'address': r.address,
                    'is_anonymous': r.is_anonymous,
                    'severity': r.severity,
                    'images': r.images or [],
                    'timestamp': r.timestamp.isoformat() if r.timestamp else None,
                    'user_id': r.user_id,
                    'status': r.status,
                    'upvotes': r.upvotes,
                    'downvotes': r.downvotes,
                    'expires_at': r.expires_at.isoformat() if r.expires_at else None,
                    'category': r.category,
                    'safety_score': r.safety_score,
                    'ai_analysis': r.ai_analysis or {}
                }
                db.close()
                return res
            except Exception as e:
                logger.error(f"Failed to get local incident report: {str(e)}")
                return None

        try:
            report_ref = self.db.collection('incident_reports').document(report_id)
            report_doc = report_ref.get()
            if report_doc.exists:
                data = report_doc.to_dict()
                data['id'] = report_doc.id
                return data
            return None
        except Exception as e:
            logger.error(f"Failed to get incident report: {str(e)}")
            raise
    
    def update_incident_report(self, report_id: str, data: dict) -> bool:
        """Update incident report"""
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, IncidentReportDB
                db = SessionLocal()
                r = db.query(IncidentReportDB).filter(IncidentReportDB.id == report_id).first()
                if r:
                    if 'incident_type' in data: r.incident_type = data['incident_type']
                    if 'description' in data: r.description = data['description']
                    if 'images' in data: r.images = data['images']
                    if 'severity' in data: r.severity = data['severity']
                    if 'status' in data: r.status = data['status']
                    if 'upvotes' in data: r.upvotes = data['upvotes']
                    if 'downvotes' in data: r.downvotes = data['downvotes']
                    if 'expires_at' in data: r.expires_at = data['expires_at']
                    if 'category' in data: r.category = data['category']
                    if 'safety_score' in data: r.safety_score = data['safety_score']
                    if 'ai_analysis' in data: r.ai_analysis = data['ai_analysis']
                    db.commit()
                    db.close()
                    return True
                db.close()
                return False
            except Exception as e:
                logger.error(f"Failed to update local incident report: {str(e)}")
                return False

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
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, EmergencyLog
                db = SessionLocal()
                emergency_id = f"emerg_{int(datetime.now().timestamp())}"
                db_log = EmergencyLog(
                    id=emergency_id,
                    user_id=emergency_data.get('user_id'),
                    latitude=emergency_data.get('latitude'),
                    longitude=emergency_data.get('longitude'),
                    status=emergency_data.get('status', 'active'),
                    incident_type=emergency_data.get('incident_type', 'general'),
                    description=emergency_data.get('description', 'SOS alert triggered'),
                    contacts_notified=emergency_data.get('contacts_notified', 0),
                    police_notified=emergency_data.get('police_notified', False)
                )
                db.add(db_log)
                db.commit()
                db.close()
                return emergency_id
            except Exception as e:
                logger.error(f"Failed to log local emergency: {str(e)}")
                raise

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
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, EmergencyLog
                db = SessionLocal()
                logs = db.query(EmergencyLog)\
                    .filter(EmergencyLog.user_id == user_id)\
                    .order_by(EmergencyLog.timestamp.desc())\
                    .limit(limit)\
                    .all()
                res = []
                for l in logs:
                    res.append({
                        'id': l.id,
                        'user_id': l.user_id,
                        'latitude': l.latitude,
                        'longitude': l.longitude,
                        'status': l.status,
                        'incident_type': l.incident_type,
                        'description': l.description,
                        'timestamp': l.timestamp.isoformat() if l.timestamp else None,
                        'resolved_at': l.resolved_at.isoformat() if l.resolved_at else None,
                        'contacts_notified': l.contacts_notified,
                        'police_notified': l.police_notified
                    })
                db.close()
                return res
            except Exception as e:
                logger.error(f"Failed to get local emergency logs: {str(e)}")
                return []

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
        if self.use_mock:
            try:
                from app.models.database import SessionLocal, EmergencyLog
                db = SessionLocal()
                log = db.query(EmergencyLog).filter(EmergencyLog.id == emergency_id).first()
                if log:
                    log.status = status
                    if status in ['resolved', 'cancelled']:
                        log.resolved_at = datetime.now()
                    db.commit()
                    db.close()
                    return True
                db.close()
                return False
            except Exception as e:
                logger.error(f"Failed to update local emergency status: {str(e)}")
                return False

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
        """Upload file to Firebase Storage or local filesystem"""
        if self.use_mock:
            try:
                # Save locally under app/static/uploads/
                backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
                static_dir = os.path.join(backend_dir, 'app', 'static', 'uploads')
                os.makedirs(static_dir, exist_ok=True)
                file_path = os.path.join(static_dir, filename)
                with open(file_path, 'wb') as f:
                    f.write(file_data)
                logger.info(f"Local evidence file uploaded: {filename}")
                return f"/static/uploads/{filename}"
            except Exception as e:
                logger.error(f"Failed to upload local file: {str(e)}")
                raise

        try:
            blob = self.bucket.blob(f'uploads/{filename}')
            blob.upload_from_string(file_data)
            blob.make_public()
            return blob.public_url
        except Exception as e:
            logger.error(f"Failed to upload file: {str(e)}")
            raise