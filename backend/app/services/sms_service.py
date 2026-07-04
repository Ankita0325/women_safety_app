from twilio.rest import Client
from app.utils.config import settings
from typing import List, Dict, Optional
import logging

logger = logging.getLogger(__name__)

class SMSService:
    """SMS service using Twilio"""
    
    def __init__(self):
        self.client = Client(
            settings.TWILIO_ACCOUNT_SID,
            settings.TWILIO_AUTH_TOKEN
        )
        self.from_number = settings.TWILIO_PHONE_NUMBER
    
    def send_emergency_alert(self, to_numbers: List[str], user_data: Dict, location: Dict) -> bool:
        """Send emergency alert SMS to contacts"""
        try:
            message = self._format_emergency_message(user_data, location)
            
            for number in to_numbers:
                self.client.messages.create(
                    body=message,
                    from_=self.from_number,
                    to=number
                )
            
            logger.info(f"Emergency alert sent to {len(to_numbers)} contacts")
            return True
        except Exception as e:
            logger.error(f"Failed to send SMS: {str(e)}")
            return False
    
    def send_safety_alert(self, to_number: str, alert_data: Dict) -> bool:
        """Send safety alert to user"""
        try:
            message = f"""
🚨 SAFETY ALERT

{alert_data.get('title', 'Alert')}
{alert_data.get('description', '')}

Location: {alert_data.get('location', 'Unknown')}
Time: {alert_data.get('time', 'Now')}

Stay safe and be aware of your surroundings.
"""
            
            self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=to_number
            )
            return True
        except Exception as e:
            logger.error(f"Failed to send safety alert: {str(e)}")
            return False
    
    def send_verification_code(self, to_number: str, code: str) -> bool:
        """Send verification code via SMS"""
        try:
            message = f"""
Your Women Safety App verification code is: {code}

This code will expire in 10 minutes.
Do not share this code with anyone.
"""
            self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=to_number
            )
            return True
        except Exception as e:
            logger.error(f"Failed to send verification code: {str(e)}")
            return False
    
    def send_police_notification(self, police_station: Dict, emergency_data: Dict) -> bool:
        """Send notification to police station"""
        try:
            message = f"""
🚨 EMERGENCY ALERT - POLICE NOTIFICATION

Citizen: {emergency_data.get('user_name', 'Unknown')}
Location: {emergency_data.get('location', 'Unknown')}
GPS: https://maps.google.com/?q={emergency_data.get('lat')},{emergency_data.get('lng')}

Incident Type: {emergency_data.get('incident_type', 'Emergency')}
Description: {emergency_data.get('description', 'SOS alert triggered')}

Please respond immediately!
"""
            
            # In production, police stations would have phone numbers
            # For demo, we'll log it
            logger.info(f"Police notification: {message}")
            return True
        except Exception as e:
            logger.error(f"Failed to notify police: {str(e)}")
            return False
    
    def send_health_check(self, to_number: str, user_name: str) -> bool:
        """Send health check message"""
        try:
            message = f"""
Hi {user_name},

This is a health check from Women Safety App.
Are you safe?

Reply SAFE if you're okay.
Reply HELP if you need assistance.
"""
            self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=to_number
            )
            return True
        except Exception as e:
            logger.error(f"Failed to send health check: {str(e)}")
            return False
    
    def send_safety_tip(self, to_number: str, tip: str) -> bool:
        """Send daily safety tip"""
        try:
            message = f"""
💡 SAFETY TIP

{tip}

Stay safe with Women Safety App!
"""
            self.client.messages.create(
                body=message,
                from_=self.from_number,
                to=to_number
            )
            return True
        except Exception as e:
            logger.error(f"Failed to send safety tip: {str(e)}")
            return False
    
    def _format_emergency_message(self, user_data: Dict, location: Dict) -> str:
        """Format emergency alert message"""
        timestamp = location.get('timestamp', 'Unknown')
        if timestamp == 'Unknown':
            from datetime import datetime
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        return f"""
🚨🚨 EMERGENCY ALERT 🚨🚨

{user_data.get('name', 'Someone')} may be in danger!

📍 Live Location:
https://maps.google.com/?q={location.get('lat')},{location.get('lng')}

🕐 Time: {timestamp}

📱 Phone: {user_data.get('phone', 'Unknown')}

⚠️ Please contact immediately!
This is an emergency alert from Women Safety App.

--- This is an automated emergency message ---
"""