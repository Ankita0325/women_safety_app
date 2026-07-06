# backend/app/routes/auth.py

from fastapi import APIRouter, HTTPException, Depends, Header, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.schemas import UserCreate, UserLogin, UserResponse, UserRole
from app.services.firebase_service import FirebaseService
from app.utils.config import settings
from datetime import datetime, timedelta
import jwt
import logging
import httpx

router = APIRouter()
logger = logging.getLogger(__name__)
firebase = FirebaseService()
security = HTTPBearer()

def create_access_token(data: dict, expires_delta: timedelta = None):
    """Create local JWT for mock/offline authentication"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Dependency to retrieve current authenticated user from Bearer Token"""
    token = credentials.credentials
    try:
        # Check if it is a mock token or real Firebase token
        if token.startswith("mock_token_") or getattr(firebase, "use_mock", False):
            try:
                # Attempt to decode locally
                payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
                uid = payload.get("sub")
            except Exception:
                # If local decoding fails (e.g. token format is custom), extract uid from mock prefix
                if "_" in token:
                    uid = token.split("_")[-1]
                else:
                    uid = "mock_user"
            
            user = firebase.get_user(uid)
            if not user:
                # Return a default mock user if not found in db to keep app running
                return {
                    "uid": uid,
                    "email": "user@safesphere.com",
                    "name": "SafeSphere User",
                    "phone": "+919876543210",
                    "role": "user",
                    "emergency_contacts": [],
                    "is_verified": True
                }
            return user
        else:
            # Real Firebase Token Verification
            from firebase_admin import auth as firebase_auth
            decoded_token = firebase_auth.verify_id_token(token)
            uid = decoded_token['uid']
            user = firebase.get_user(uid)
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found in database"
                )
            return user
    except Exception as e:
        logger.error(f"Authentication error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.post("/register")
async def register(user_data: UserCreate):
    """Register a new user"""
    try:
        # Check if user already exists
        # In mock mode, check if we can query user by email
        existing_user = None
        if getattr(firebase, "use_mock", False):
            # Fetch user email locally if supported
            pass
        
        # Prepare user payload
        payload = {
            "name": user_data.name,
            "phone": user_data.phone,
            "email": user_data.email
        }
        
        # Create user
        uid = firebase.create_user(user_data.email, user_data.password, payload)
        
        # Generate token
        token = ""
        if getattr(firebase, "use_mock", False):
            token = create_access_token(data={"sub": uid, "role": "user"})
        else:
            # Generate custom Firebase token or rely on client-side SDK signing
            token = f"firebase_token_{uid}"
            
        user = firebase.get_user(uid)
        return {
            "token": token,
            "user": user,
            "status": "success",
            "message": "User registered successfully"
        }
    except Exception as e:
        logger.error(f"Registration failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Registration failed: {str(e)}"
        )

@router.post("/login")
async def login(credentials: UserLogin):
    """Authenticate user and return access token"""
    email = credentials.email
    password = credentials.password
    
    # Mock Backend Login Flow
    if getattr(firebase, "use_mock", False):
        # Retrieve user from local mock db
        uid = f"mock_{int(datetime.now().timestamp())}"
        # Look for user with this email
        db_user = None
        if hasattr(firebase, "_get_user_by_email"):
            db_user = firebase._get_user_by_email(email)
            
        if db_user:
            uid = db_user.get("uid")
            user = db_user
        else:
            # Auto-create mock user if not exists for easy testing/demo
            payload = {
                "name": email.split("@")[0].capitalize(),
                "phone": "+919876543210",
                "email": email
            }
            uid = firebase.create_user(email, password, payload)
            user = firebase.get_user(uid)
            
        token = create_access_token(data={"sub": uid, "role": user.get("role", "user")})
        return {
            "token": token,
            "user": user,
            "status": "success"
        }
        
    # Real Backend Login Flow (Firebase REST API)
    try:
        firebase_web_key = os.getenv("GOOGLE_MAPS_API_KEY", "") # Fallback to map key if not set separately
        # Using the standard Google Identity Toolkit API to authenticate email/password
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={firebase_web_key}",
                json={
                    "email": email,
                    "password": password,
                    "returnSecureToken": True
                }
            )
            
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
            
        resp_data = response.json()
        uid = resp_data["localId"]
        token = resp_data["idToken"]
        
        user = firebase.get_user(uid)
        if not user:
            # If authenticated in Auth but missing in Firestore, sync it
            payload = {
                "name": email.split("@")[0].capitalize(),
                "phone": "+919876543210",
                "email": email
            }
            firebase.update_user(uid, payload)
            user = firebase.get_user(uid)
            
        return {
            "token": token,
            "user": user,
            "status": "success"
        }
    except Exception as e:
        logger.error(f"Login failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed"
        )

@router.get("/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    """Get currently logged in user profile"""
    return current_user

@router.put("/profile")
async def update_profile(data: dict, current_user: dict = Depends(get_current_user)):
    """Update current user profile"""
    try:
        uid = current_user.get("uid")
        firebase.update_user(uid, data)
        updated_user = firebase.get_user(uid)
        return updated_user
    except Exception as e:
        logger.error(f"Profile update failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
