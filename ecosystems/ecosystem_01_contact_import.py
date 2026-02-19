#!/usr/bin/env python3
"""
============================================================================
E01 EXTENSION: CONTACT FILE IMPORT ENGINE
============================================================================

Handles contact file imports from:
- iPhone vCard (.vcf) files - individual and multiple contacts
- Microsoft/Outlook contacts (.csv export from Outlook)
- Google Contacts (.csv export)
- Android contacts (.vcf)
- Mobile "Share Contacts" via deep link / QR code

Integration with:
- E24 Candidate Portal (upload interface)
- E01 Data Import Engine (control panel, normalization)
- Candidate Media Library (storage)

Supports:
- Mobile: Share Contacts button triggers upload link
- Desktop: Drag-drop or file picker
- Bulk: Multi-contact vCard files

Author: BroyhillGOP Platform
Created: January 2026
Version: 1.0.0
============================================================================
"""

# Load environment
from dotenv import load_dotenv
load_dotenv("/opt/broyhillgop/config/supabase.env")
import os
import io
import re
import json
import uuid
import base64
import logging
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any, Union
from dataclasses import dataclass, field
from pathlib import Path

import psycopg2
from psycopg2.extras import RealDictCursor

# Optional imports
try:
    import redis
    HAS_REDIS = True
except ImportError:
    HAS_REDIS = False
    redis = None

try:
    import vobject
    HAS_VOBJECT = True
except ImportError:
    HAS_VOBJECT = False
    vobject = None

try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False
    pd = None

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem1.contact_import')


# ============================================================================
# CONFIGURATION
# ============================================================================

class ContactImportConfig:
    """Configuration for contact file imports"""
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
    
    # API endpoint for mobile share
    SHARE_UPLOAD_URL = os.getenv("SHARE_UPLOAD_URL", "https://upload.broyhillgop.com/contacts")
    
    # Upload link expiration
    UPLOAD_LINK_EXPIRY_HOURS = 24
    
    # File limits
    MAX_CONTACTS_PER_FILE = 10000
    MAX_FILE_SIZE_MB = 50


# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class ParsedContact:
    """Normalized contact from any source"""
    # Core fields
    email: Optional[str] = None
    phone: Optional[str] = None
    phone_mobile: Optional[str] = None
    phone_work: Optional[str] = None
    phone_home: Optional[str] = None
    
    # Name
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    full_name: Optional[str] = None
    prefix: Optional[str] = None  # Mr., Mrs., Dr.
    suffix: Optional[str] = None  # Jr., Sr., III
    nickname: Optional[str] = None
    
    # Address
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    country: Optional[str] = None
    
    # Work
    organization: Optional[str] = None
    title: Optional[str] = None
    department: Optional[str] = None
    
    # Social
    website: Optional[str] = None
    twitter: Optional[str] = None
    facebook: Optional[str] = None
    linkedin: Optional[str] = None
    
    # Meta
    birthday: Optional[datetime] = None
    notes: Optional[str] = None
    photo_data: Optional[bytes] = None
    
    # Source tracking
    source_file: str = ""
    source_format: str = ""  # 'vcard', 'outlook', 'google', 'android'
    raw_data: Dict = field(default_factory=dict)


@dataclass
class ContactImportResult:
    """Result of contact file import"""
    session_id: str
    candidate_id: str
    source: str  # 'mobile_share', 'desktop_upload', 'api'
    file_name: str
    file_format: str
    total_contacts: int
    imported: int
    duplicates: int
    errors: int
    error_details: List[Dict] = field(default_factory=list)
    started_at: datetime = field(default_factory=datetime.now)
    completed_at: Optional[datetime] = None


# ============================================================================
# VCARD PARSER
# ============================================================================

class VCardParser:
    """
    Parse vCard (.vcf) files from iPhone, Android, and other sources
    
    Supports:
    - vCard 2.1, 3.0, 4.0
    - Single and multi-contact files
    - Photo data (base64)
    - Multiple phone numbers/emails
    """
    
    def parse_file(self, content: Union[bytes, str, io.BytesIO]) -> List[ParsedContact]:
        """
        Parse vCard file content
        
        Args:
            content: File content as bytes, string, or BytesIO
            
        Returns:
            List of ParsedContact objects
        """
        # Convert to string
        if isinstance(content, bytes):
            content = content.decode('utf-8', errors='ignore')
        elif isinstance(content, io.BytesIO):
            content = content.read().decode('utf-8', errors='ignore')
        
        contacts = []
        
        if HAS_VOBJECT:
            # Use vobject library for robust parsing
            contacts = self._parse_with_vobject(content)
        else:
            # Fallback to manual parsing
            contacts = self._parse_manual(content)
        
        return contacts
    
    def _parse_with_vobject(self, content: str) -> List[ParsedContact]:
        """Parse using vobject library"""
        contacts = []
        
        # vobject can handle multi-contact files
        for vcard in vobject.readComponents(content):
            contact = ParsedContact(source_format='vcard')
            
            # Name
            if hasattr(vcard, 'n') and vcard.n.value:
                n = vcard.n.value
                contact.first_name = n.given or ''
                contact.last_name = n.family or ''
                contact.prefix = n.prefix or ''
                contact.suffix = n.suffix or ''
            
            if hasattr(vcard, 'fn'):
                contact.full_name = vcard.fn.value
            
            if hasattr(vcard, 'nickname'):
                contact.nickname = vcard.nickname.value
            
            # Email
            if hasattr(vcard, 'email'):
                # May have multiple emails
                emails = vcard.contents.get('email', [])
                if emails:
                    contact.email = emails[0].value
            
            # Phone numbers
            if hasattr(vcard, 'tel'):
                tels = vcard.contents.get('tel', [])
                for tel in tels:
                    phone = self._normalize_phone(tel.value)
                    tel_type = getattr(tel, 'type_param', '') or ''
                    
                    if isinstance(tel_type, list):
                        tel_type = ','.join(tel_type).lower()
                    else:
                        tel_type = tel_type.lower()
                    
                    if 'cell' in tel_type or 'mobile' in tel_type:
                        contact.phone_mobile = phone
                    elif 'work' in tel_type:
                        contact.phone_work = phone
                    elif 'home' in tel_type:
                        contact.phone_home = phone
                    elif not contact.phone:
                        contact.phone = phone
                
                # Use mobile as primary if available
                if not contact.phone:
                    contact.phone = contact.phone_mobile or contact.phone_work or contact.phone_home
            
            # Address
            if hasattr(vcard, 'adr'):
                addrs = vcard.contents.get('adr', [])
                if addrs:
                    adr = addrs[0].value
                    contact.address = ' '.join(filter(None, [adr.street, adr.extended]))
                    contact.city = adr.city or ''
                    contact.state = adr.region or ''
                    contact.zip_code = adr.code or ''
                    contact.country = adr.country or ''
            
            # Organization
            if hasattr(vcard, 'org'):
                org = vcard.org.value
                if isinstance(org, list):
                    contact.organization = org[0] if org else ''
                else:
                    contact.organization = str(org)
            
            if hasattr(vcard, 'title'):
                contact.title = vcard.title.value
            
            # URLs
            if hasattr(vcard, 'url'):
                urls = vcard.contents.get('url', [])
                for url_obj in urls:
                    url = url_obj.value
                    if 'twitter' in url.lower():
                        contact.twitter = url
                    elif 'facebook' in url.lower():
                        contact.facebook = url
                    elif 'linkedin' in url.lower():
                        contact.linkedin = url
                    elif not contact.website:
                        contact.website = url
            
            # Birthday
            if hasattr(vcard, 'bday'):
                try:
                    bday = vcard.bday.value
                    if isinstance(bday, str):
                        # Try parsing common formats
                        for fmt in ['%Y-%m-%d', '%Y%m%d', '%m/%d/%Y']:
                            try:
                                contact.birthday = datetime.strptime(bday, fmt)
                                break
                            except:
                                pass
                    else:
                        contact.birthday = bday
                except:
                    pass
            
            # Notes
            if hasattr(vcard, 'note'):
                contact.notes = vcard.note.value
            
            # Photo
            if hasattr(vcard, 'photo'):
                try:
                    photo = vcard.photo.value
                    if isinstance(photo, bytes):
                        contact.photo_data = photo
                    elif isinstance(photo, str):
                        # May be base64 encoded
                        contact.photo_data = base64.b64decode(photo)
                except:
                    pass
            
            contacts.append(contact)
        
        return contacts
    
    def _parse_manual(self, content: str) -> List[ParsedContact]:
        """Manual vCard parsing fallback"""
        contacts = []
        
        # Split into individual vCards
        vcards = re.split(r'(?=BEGIN:VCARD)', content)
        
        for vcard_text in vcards:
            if not vcard_text.strip() or 'BEGIN:VCARD' not in vcard_text:
                continue
            
            contact = ParsedContact(source_format='vcard')
            lines = vcard_text.split('\n')
            
            for line in lines:
                line = line.strip()
                if not line or ':' not in line:
                    continue
                
                # Handle folded lines (continuation)
                while lines and lines[0].startswith(' '):
                    line += lines.pop(0).strip()
                
                # Parse key:value
                if ';' in line.split(':')[0]:
                    key_parts = line.split(':')[0].split(';')
                    key = key_parts[0].upper()
                    params = key_parts[1:]
                else:
                    key = line.split(':')[0].upper()
                    params = []
                
                value = ':'.join(line.split(':')[1:])
                
                # Process fields
                if key == 'FN':
                    contact.full_name = value
                elif key == 'N':
                    parts = value.split(';')
                    if len(parts) >= 2:
                        contact.last_name = parts[0]
                        contact.first_name = parts[1]
                    if len(parts) >= 4:
                        contact.prefix = parts[3] if len(parts) > 3 else ''
                    if len(parts) >= 5:
                        contact.suffix = parts[4] if len(parts) > 4 else ''
                elif key == 'EMAIL':
                    if not contact.email:
                        contact.email = value
                elif key == 'TEL':
                    phone = self._normalize_phone(value)
                    param_str = ';'.join(params).lower()
                    
                    if 'cell' in param_str or 'mobile' in param_str:
                        contact.phone_mobile = phone
                    elif 'work' in param_str:
                        contact.phone_work = phone
                    elif 'home' in param_str:
                        contact.phone_home = phone
                    elif not contact.phone:
                        contact.phone = phone
                elif key == 'ADR':
                    parts = value.split(';')
                    if len(parts) >= 7:
                        contact.address = parts[2]
                        contact.city = parts[3]
                        contact.state = parts[4]
                        contact.zip_code = parts[5]
                        contact.country = parts[6]
                elif key == 'ORG':
                    contact.organization = value.split(';')[0]
                elif key == 'TITLE':
                    contact.title = value
                elif key == 'NOTE':
                    contact.notes = value
            
            # Use mobile as primary
            if not contact.phone:
                contact.phone = contact.phone_mobile or contact.phone_work or contact.phone_home
            
            if contact.email or contact.phone or contact.full_name:
                contacts.append(contact)
        
        return contacts
    
    def _normalize_phone(self, phone: str) -> str:
        """Normalize phone number to 10 digits"""
        if not phone:
            return ''
        digits = re.sub(r'\D', '', phone)
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        return digits if len(digits) == 10 else ''


# ============================================================================
# OUTLOOK/MICROSOFT CONTACTS PARSER
# ============================================================================

class OutlookContactsParser:
    """
    Parse Microsoft Outlook contact exports
    
    Supports:
    - CSV export from Outlook
    - Windows Contacts (.contact XML) 
    - PST export converted to CSV
    """
    
    # Common Outlook column mappings
    OUTLOOK_COLUMNS = {
        # Email
        'e-mail address': 'email',
        'email address': 'email',
        'e-mail': 'email',
        'email': 'email',
        'e-mail 2 address': 'email_2',
        'e-mail 3 address': 'email_3',
        
        # Name
        'first name': 'first_name',
        'first': 'first_name',
        'given name': 'first_name',
        'last name': 'last_name',
        'last': 'last_name',
        'surname': 'last_name',
        'family name': 'last_name',
        'middle name': 'middle_name',
        'title': 'prefix',
        'suffix': 'suffix',
        'nickname': 'nickname',
        
        # Phone
        'mobile phone': 'phone_mobile',
        'mobile': 'phone_mobile',
        'cell phone': 'phone_mobile',
        'primary phone': 'phone',
        'home phone': 'phone_home',
        'home': 'phone_home',
        'business phone': 'phone_work',
        'work phone': 'phone_work',
        'work': 'phone_work',
        'other phone': 'phone_other',
        
        # Address - Home
        'home street': 'address',
        'home address': 'address',
        'home city': 'city',
        'home state': 'state',
        'home postal code': 'zip_code',
        'home zip': 'zip_code',
        'home country': 'country',
        
        # Address - Business
        'business street': 'work_address',
        'business city': 'work_city',
        'business state': 'work_state',
        'business postal code': 'work_zip',
        'business country': 'work_country',
        
        # Work
        'company': 'organization',
        'organization': 'organization',
        'company name': 'organization',
        'job title': 'title',
        'department': 'department',
        
        # Other
        'web page': 'website',
        'website': 'website',
        'birthday': 'birthday',
        'notes': 'notes',
    }
    
    def parse_file(self, content: Union[bytes, io.BytesIO], file_name: str = '') -> List[ParsedContact]:
        """Parse Outlook export file"""
        if not HAS_PANDAS:
            raise RuntimeError("pandas required for Outlook CSV parsing")
        
        # Detect format
        if file_name.lower().endswith('.contact'):
            return self._parse_windows_contact(content)
        else:
            return self._parse_csv(content)
    
    def _parse_csv(self, content: Union[bytes, io.BytesIO]) -> List[ParsedContact]:
        """Parse Outlook CSV export"""
        if isinstance(content, bytes):
            content = io.BytesIO(content)
        
        # Try different encodings
        for encoding in ['utf-8', 'utf-16', 'cp1252', 'latin-1']:
            try:
                content.seek(0)
                df = pd.read_csv(content, encoding=encoding, dtype=str)
                break
            except:
                continue
        else:
            raise ValueError("Could not decode CSV file")
        
        # Normalize column names
        df.columns = [c.strip().lower() for c in df.columns]
        
        contacts = []
        
        for _, row in df.iterrows():
            contact = ParsedContact(source_format='outlook')
            
            for src_col, target_field in self.OUTLOOK_COLUMNS.items():
                if src_col in row and pd.notna(row[src_col]):
                    value = str(row[src_col]).strip()
                    if value:
                        if target_field == 'email':
                            contact.email = value.lower()
                        elif target_field == 'first_name':
                            contact.first_name = value
                        elif target_field == 'last_name':
                            contact.last_name = value
                        elif target_field == 'phone_mobile':
                            contact.phone_mobile = self._normalize_phone(value)
                        elif target_field == 'phone_work':
                            contact.phone_work = self._normalize_phone(value)
                        elif target_field == 'phone_home':
                            contact.phone_home = self._normalize_phone(value)
                        elif target_field == 'phone':
                            contact.phone = self._normalize_phone(value)
                        elif target_field == 'address':
                            contact.address = value
                        elif target_field == 'city':
                            contact.city = value
                        elif target_field == 'state':
                            contact.state = value
                        elif target_field == 'zip_code':
                            contact.zip_code = value
                        elif target_field == 'organization':
                            contact.organization = value
                        elif target_field == 'title':
                            contact.title = value
                        elif target_field == 'website':
                            contact.website = value
                        elif target_field == 'notes':
                            contact.notes = value
                        elif target_field == 'birthday':
                            contact.birthday = self._parse_date(value)
            
            # Use mobile as primary phone
            if not contact.phone:
                contact.phone = contact.phone_mobile or contact.phone_work or contact.phone_home
            
            # Build full name if not present
            if not contact.full_name and (contact.first_name or contact.last_name):
                contact.full_name = f"{contact.first_name or ''} {contact.last_name or ''}".strip()
            
            # Only add if has contact info
            if contact.email or contact.phone or contact.full_name:
                contacts.append(contact)
        
        return contacts
    
    def _parse_windows_contact(self, content: Union[bytes, io.BytesIO]) -> List[ParsedContact]:
        """Parse Windows .contact XML file"""
        # Windows Contacts are XML files
        if isinstance(content, io.BytesIO):
            content = content.read()
        
        # Simple XML parsing for .contact files
        contact = ParsedContact(source_format='windows_contact')
        
        # Extract common fields with regex (simplified)
        patterns = {
            'first_name': r'<c:GivenName>([^<]+)</c:GivenName>',
            'last_name': r'<c:FamilyName>([^<]+)</c:FamilyName>',
            'email': r'<c:Value>([^@<]+@[^<]+)</c:Value>',
            'phone': r'<c:Number>([^<]+)</c:Number>',
        }
        
        content_str = content.decode('utf-8', errors='ignore')
        
        for field, pattern in patterns.items():
            match = re.search(pattern, content_str)
            if match:
                setattr(contact, field, match.group(1))
        
        if contact.phone:
            contact.phone = self._normalize_phone(contact.phone)
        
        return [contact] if (contact.email or contact.phone) else []
    
    def _normalize_phone(self, phone: str) -> str:
        """Normalize phone number"""
        digits = re.sub(r'\D', '', phone)
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        return digits if len(digits) == 10 else ''
    
    def _parse_date(self, date_str: str) -> Optional[datetime]:
        """Parse date string"""
        formats = ['%Y-%m-%d', '%m/%d/%Y', '%m/%d/%y', '%d/%m/%Y', '%Y%m%d']
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except:
                pass
        return None


# ============================================================================
# GOOGLE CONTACTS PARSER
# ============================================================================

class GoogleContactsParser:
    """
    Parse Google Contacts CSV export
    """
    
    GOOGLE_COLUMNS = {
        'given name': 'first_name',
        'family name': 'last_name',
        'name': 'full_name',
        'nickname': 'nickname',
        'e-mail 1 - value': 'email',
        'e-mail 2 - value': 'email_2',
        'phone 1 - value': 'phone',
        'phone 2 - value': 'phone_2',
        'address 1 - street': 'address',
        'address 1 - city': 'city',
        'address 1 - region': 'state',
        'address 1 - postal code': 'zip_code',
        'address 1 - country': 'country',
        'organization 1 - name': 'organization',
        'organization 1 - title': 'title',
        'website 1 - value': 'website',
        'birthday': 'birthday',
        'notes': 'notes',
    }
    
    def parse_file(self, content: Union[bytes, io.BytesIO]) -> List[ParsedContact]:
        """Parse Google Contacts CSV"""
        if not HAS_PANDAS:
            raise RuntimeError("pandas required for Google Contacts CSV parsing")
        
        if isinstance(content, bytes):
            content = io.BytesIO(content)
        
        df = pd.read_csv(content, dtype=str)
        df.columns = [c.strip().lower() for c in df.columns]
        
        contacts = []
        
        for _, row in df.iterrows():
            contact = ParsedContact(source_format='google')
            
            for src_col, target_field in self.GOOGLE_COLUMNS.items():
                if src_col in row and pd.notna(row[src_col]):
                    value = str(row[src_col]).strip()
                    if value:
                        setattr(contact, target_field, value)
            
            # Normalize phone
            if contact.phone:
                digits = re.sub(r'\D', '', contact.phone)
                if len(digits) == 11 and digits.startswith('1'):
                    digits = digits[1:]
                contact.phone = digits if len(digits) == 10 else ''
            
            if contact.email or contact.phone or contact.full_name:
                contacts.append(contact)
        
        return contacts


# ============================================================================
# MOBILE SHARE INTEGRATION
# ============================================================================

class MobileShareHandler:
    """
    Handle mobile "Share Contacts" workflow
    
    Workflow:
    1. Candidate clicks "Share Contacts" in E24 portal (mobile)
    2. System generates secure upload link / QR code
    3. Link triggers native share sheet on iOS/Android
    4. Contacts are uploaded via browser
    5. Parsed and added to candidate's donor list
    
    Also supports:
    - SMS link delivery
    - QR code for laptop users to scan with phone
    """
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.redis = None
        
        if HAS_REDIS:
            try:
                self.redis = redis.Redis(
                    host=ContactImportConfig.REDIS_HOST,
                    port=ContactImportConfig.REDIS_PORT,
                    decode_responses=True
                )
                self.redis.ping()
            except:
                self.redis = None
    
    def _get_db(self):
        """Get database connection"""
        return psycopg2.connect(ContactImportConfig.DATABASE_URL)
    
    def generate_upload_link(
        self,
        source: str = 'mobile',  # 'mobile', 'desktop', 'qr'
        platform: str = None  # 'ios', 'android', 'windows', 'mac'
    ) -> Dict:
        """
        Generate secure upload link for contact sharing
        
        Returns dict with:
        - upload_url: Direct upload URL
        - deep_link: Native app deep link (iOS/Android)
        - qr_code_url: QR code image URL
        - session_id: Session tracking ID
        - expires_at: Expiration time
        """
        # Generate secure token
        token = secrets.token_urlsafe(32)
        session_id = str(uuid.uuid4())
        expires_at = datetime.now() + timedelta(hours=ContactImportConfig.UPLOAD_LINK_EXPIRY_HOURS)
        
        # Store session
        session_data = {
            'candidate_id': self.candidate_id,
            'session_id': session_id,
            'source': source,
            'platform': platform,
            'created_at': datetime.now().isoformat(),
            'expires_at': expires_at.isoformat()
        }
        
        if self.redis:
            self.redis.setex(
                f"contact_upload:{token}",
                ContactImportConfig.UPLOAD_LINK_EXPIRY_HOURS * 3600,
                json.dumps(session_data)
            )
        else:
            # Store in database
            conn = self._get_db()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO contact_upload_sessions 
                (session_id, candidate_id, token_hash, source, platform, expires_at)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (session_id, self.candidate_id, hashlib.sha256(token.encode()).hexdigest(),
                  source, platform, expires_at))
            conn.commit()
            conn.close()
        
        base_url = ContactImportConfig.SHARE_UPLOAD_URL
        upload_url = f"{base_url}?token={token}"
        
        # Generate platform-specific links
        result = {
            'session_id': session_id,
            'upload_url': upload_url,
            'expires_at': expires_at.isoformat(),
            'token': token
        }
        
        # iOS deep link for sharing contacts
        if platform == 'ios':
            # iOS uses the upload URL directly - user selects contacts in browser
            result['instructions'] = (
                "1. Open the link on your iPhone\n"
                "2. Tap 'Select Contacts' button\n"
                "3. Choose contacts to share\n"
                "4. Tap 'Upload' to send to campaign"
            )
        
        # Android share intent
        elif platform == 'android':
            result['instructions'] = (
                "1. Open the link on your Android phone\n"
                "2. Tap 'Share Contacts' button\n"
                "3. Select contacts from your list\n"
                "4. Tap 'Upload' to send to campaign"
            )
        
        # Desktop - suggest QR code
        else:
            result['instructions'] = (
                "Option 1: Open the link and upload a contact file (VCF, CSV)\n"
                "Option 2: Scan the QR code with your phone to share contacts"
            )
            # QR code URL (would be generated by frontend)
            result['qr_data'] = upload_url
        
        return result
    
    def send_upload_link_sms(self, phone: str) -> bool:
        """Send upload link via SMS to candidate's phone"""
        link_data = self.generate_upload_link(source='sms')
        
        # Publish SMS send event
        if self.redis:
            event = {
                'event_type': 'sms.send',
                'ecosystem': 1,
                'to': phone,
                'message': (
                    f"BroyhillGOP: Upload your contacts here: {link_data['upload_url']}\n"
                    f"Link expires in 24 hours."
                ),
                'timestamp': datetime.now().isoformat()
            }
            self.redis.publish('broyhillgop.events', json.dumps(event))
        
        return True
    
    def validate_upload_token(self, token: str) -> Optional[Dict]:
        """Validate upload token and return session data"""
        if self.redis:
            data = self.redis.get(f"contact_upload:{token}")
            if data:
                session = json.loads(data)
                if datetime.fromisoformat(session['expires_at']) > datetime.now():
                    return session
        else:
            # Check database
            conn = self._get_db()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute("""
                SELECT * FROM contact_upload_sessions
                WHERE token_hash = %s AND expires_at > NOW()
            """, (hashlib.sha256(token.encode()).hexdigest(),))
            row = cur.fetchone()
            conn.close()
            if row:
                return dict(row)
        
        return None
    
    def invalidate_token(self, token: str):
        """Invalidate token after use"""
        if self.redis:
            self.redis.delete(f"contact_upload:{token}")
        else:
            conn = self._get_db()
            cur = conn.cursor()
            cur.execute("""
                UPDATE contact_upload_sessions SET used_at = NOW()
                WHERE token_hash = %s
            """, (hashlib.sha256(token.encode()).hexdigest(),))
            conn.commit()
            conn.close()


# ============================================================================
# UNIFIED CONTACT IMPORT ENGINE
# ============================================================================

class ContactImportEngine:
    """
    Main engine for importing contacts from any source
    
    Integrates with:
    - E01 Data Import Engine (control panel, normalization)
    - E24 Candidate Portal (upload interface)
    - Candidate Media Library (storage)
    """
    
    def __init__(self, candidate_id: str):
        self.candidate_id = candidate_id
        self.vcard_parser = VCardParser()
        self.outlook_parser = OutlookContactsParser()
        self.google_parser = GoogleContactsParser()
        self.mobile_handler = MobileShareHandler(candidate_id)
        
        self.redis = None
        if HAS_REDIS:
            try:
                self.redis = redis.Redis(
                    host=ContactImportConfig.REDIS_HOST,
                    port=ContactImportConfig.REDIS_PORT,
                    decode_responses=True
                )
            except:
                pass
    
    def _get_db(self):
        return psycopg2.connect(ContactImportConfig.DATABASE_URL)
    
    def detect_format(self, file_name: str, content: bytes = None) -> str:
        """
        Detect contact file format
        
        Returns: 'vcard', 'outlook', 'google', 'unknown'
        """
        ext = Path(file_name).suffix.lower()
        
        if ext == '.vcf':
            return 'vcard'
        elif ext == '.contact':
            return 'windows_contact'
        elif ext == '.csv':
            # Detect CSV type from headers
            if content and HAS_PANDAS:
                try:
                    df = pd.read_csv(io.BytesIO(content), nrows=1)
                    cols = [c.lower() for c in df.columns]
                    
                    # Google Contacts specific columns
                    if 'given name' in cols and 'family name' in cols:
                        return 'google'
                    # Outlook specific columns
                    elif 'e-mail address' in cols or 'first name' in cols:
                        return 'outlook'
                except:
                    pass
            return 'outlook'  # Default CSV to Outlook
        
        return 'unknown'
    
    def parse_file(
        self,
        content: Union[bytes, io.BytesIO],
        file_name: str,
        format_hint: str = None
    ) -> List[ParsedContact]:
        """
        Parse contact file and return normalized contacts
        
        Args:
            content: File content
            file_name: Original filename
            format_hint: Optional format override
        
        Returns:
            List of ParsedContact objects
        """
        if isinstance(content, io.BytesIO):
            content_bytes = content.read()
            content.seek(0)
        else:
            content_bytes = content
        
        # Detect format
        file_format = format_hint or self.detect_format(file_name, content_bytes)
        
        if file_format == 'vcard':
            return self.vcard_parser.parse_file(content)
        elif file_format == 'windows_contact':
            return self.outlook_parser._parse_windows_contact(content)
        elif file_format == 'google':
            return self.google_parser.parse_file(content)
        elif file_format == 'outlook':
            return self.outlook_parser.parse_file(content, file_name)
        else:
            raise ValueError(f"Unknown contact file format: {file_format}")
    
    def import_contacts(
        self,
        content: Union[bytes, io.BytesIO],
        file_name: str,
        uploaded_by: str,
        source: str = 'upload',  # 'upload', 'mobile_share', 'api'
        settings: Dict = None
    ) -> ContactImportResult:
        """
        Full import workflow:
        1. Parse contact file
        2. Normalize contacts
        3. Deduplicate against existing donors
        4. Insert new donors
        5. Trigger E01 enrichment
        
        Returns:
            ContactImportResult with counts
        """
        settings = settings or {}
        session_id = str(uuid.uuid4())
        started_at = datetime.now()
        
        result = ContactImportResult(
            session_id=session_id,
            candidate_id=self.candidate_id,
            source=source,
            file_name=file_name,
            file_format=self.detect_format(file_name),
            total_contacts=0,
            imported=0,
            duplicates=0,
            errors=0,
            started_at=started_at
        )
        
        try:
            # Parse file
            contacts = self.parse_file(content, file_name)
            result.total_contacts = len(contacts)
            
            if not contacts:
                return result
            
            conn = self._get_db()
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            for contact in contacts:
                try:
                    # Check for duplicate by email
                    if contact.email:
                        cur.execute("""
                            SELECT donor_id FROM donors
                            WHERE candidate_id = %s AND LOWER(email) = LOWER(%s)
                        """, (self.candidate_id, contact.email))
                        
                        if cur.fetchone():
                            result.duplicates += 1
                            continue
                    
                    # Check for duplicate by phone
                    if contact.phone:
                        cur.execute("""
                            SELECT donor_id FROM donors
                            WHERE candidate_id = %s AND phone = %s
                        """, (self.candidate_id, contact.phone))
                        
                        if cur.fetchone():
                            result.duplicates += 1
                            continue
                    
                    # Insert new donor
                    donor_id = str(uuid.uuid4())
                    
                    cur.execute("""
                        INSERT INTO donors (
                            donor_id, candidate_id, email, phone,
                            first_name, last_name, address, city, state, zip_code,
                            employer, occupation, source, created_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                    """, (
                        donor_id, self.candidate_id,
                        contact.email, contact.phone,
                        contact.first_name, contact.last_name,
                        contact.address, contact.city,
                        self._normalize_state(contact.state),
                        contact.zip_code,
                        contact.organization, contact.title,
                        f"contact_import:{source}"
                    ))
                    
                    result.imported += 1
                    
                except Exception as e:
                    result.errors += 1
                    result.error_details.append({
                        'contact': contact.full_name or contact.email or 'Unknown',
                        'error': str(e)
                    })
            
            conn.commit()
            conn.close()
            
            # Trigger E01 enrichment
            self._trigger_enrichment(session_id, result.imported)
            
        except Exception as e:
            result.errors += 1
            result.error_details.append({'fatal_error': str(e)})
        
        result.completed_at = datetime.now()
        
        logger.info(
            f"Contact import complete: {result.imported} imported, "
            f"{result.duplicates} duplicates, {result.errors} errors"
        )
        
        return result
    
    def _normalize_state(self, state: str) -> str:
        """Normalize state to 2-letter code"""
        if not state:
            return ''
        
        state = state.strip().upper()
        if len(state) == 2:
            return state
        
        state_map = {
            'NORTH CAROLINA': 'NC', 'SOUTH CAROLINA': 'SC',
            'VIRGINIA': 'VA', 'TENNESSEE': 'TN', 'GEORGIA': 'GA',
            # ... (full mapping in main import engine)
        }
        
        return state_map.get(state, state[:2])
    
    def _trigger_enrichment(self, session_id: str, count: int):
        """Trigger E01 donor grading for imported contacts"""
        if self.redis:
            event = {
                'event_type': 'contact_import.completed',
                'ecosystem': 1,
                'session_id': session_id,
                'candidate_id': self.candidate_id,
                'imported_count': count,
                'action': 'enrich_donors',
                'timestamp': datetime.now().isoformat()
            }
            self.redis.publish('broyhillgop.events', json.dumps(event))


# ============================================================================
# DATABASE SCHEMA
# ============================================================================

CONTACT_IMPORT_SCHEMA = """
-- Contact Upload Sessions (for mobile share links)
CREATE TABLE IF NOT EXISTS contact_upload_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    source VARCHAR(50),  -- 'mobile', 'desktop', 'sms', 'qr'
    platform VARCHAR(50),  -- 'ios', 'android', 'windows', 'mac'
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    import_result JSONB
);

CREATE INDEX IF NOT EXISTS idx_contact_upload_token ON contact_upload_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_contact_upload_candidate ON contact_upload_sessions(candidate_id);

-- Contact Import History
CREATE TABLE IF NOT EXISTS contact_import_history (
    import_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    session_id UUID,
    uploaded_by UUID,
    source VARCHAR(50) NOT NULL,
    file_name VARCHAR(500),
    file_format VARCHAR(50),
    total_contacts INTEGER DEFAULT 0,
    imported_count INTEGER DEFAULT 0,
    duplicate_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    error_details JSONB,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    duration_seconds DECIMAL(10,2)
);

CREATE INDEX IF NOT EXISTS idx_contact_import_candidate ON contact_import_history(candidate_id);
"""


# ============================================================================
# API ENDPOINTS (for E24 Portal integration)
# ============================================================================

def create_api_routes(app):
    """
    Create Flask/FastAPI routes for contact import
    
    Endpoints:
    - POST /api/v1/contacts/upload - Upload contact file
    - POST /api/v1/contacts/share-link - Generate mobile share link
    - POST /api/v1/contacts/mobile-upload - Handle mobile upload
    - GET /api/v1/contacts/history - Get import history
    """
    
    @app.route('/api/v1/contacts/share-link', methods=['POST'])
    def generate_share_link():
        """Generate secure upload link for mobile sharing"""
        data = request.json
        candidate_id = data.get('candidate_id')
        platform = data.get('platform')  # 'ios', 'android', 'desktop'
        
        handler = MobileShareHandler(candidate_id)
        result = handler.generate_upload_link(
            source='mobile' if platform in ('ios', 'android') else 'desktop',
            platform=platform
        )
        
        return jsonify(result)
    
    @app.route('/api/v1/contacts/upload', methods=['POST'])
    def upload_contacts():
        """Upload contact file (desktop or mobile)"""
        candidate_id = request.form.get('candidate_id')
        uploaded_by = request.form.get('user_id')
        file = request.files.get('file')
        
        if not file:
            return jsonify({'error': 'No file provided'}), 400
        
        engine = ContactImportEngine(candidate_id)
        result = engine.import_contacts(
            content=file.read(),
            file_name=file.filename,
            uploaded_by=uploaded_by,
            source='upload'
        )
        
        return jsonify({
            'session_id': result.session_id,
            'total': result.total_contacts,
            'imported': result.imported,
            'duplicates': result.duplicates,
            'errors': result.errors
        })
    
    @app.route('/api/v1/contacts/mobile-upload', methods=['POST'])
    def mobile_upload():
        """Handle mobile share upload with token"""
        token = request.args.get('token')
        
        handler = MobileShareHandler('')  # Candidate ID from token
        session = handler.validate_upload_token(token)
        
        if not session:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        file = request.files.get('file')
        if not file:
            return jsonify({'error': 'No file provided'}), 400
        
        engine = ContactImportEngine(session['candidate_id'])
        result = engine.import_contacts(
            content=file.read(),
            file_name=file.filename,
            uploaded_by=session['candidate_id'],
            source='mobile_share'
        )
        
        # Invalidate token
        handler.invalidate_token(token)
        
        return jsonify({
            'success': True,
            'imported': result.imported,
            'duplicates': result.duplicates
        })


# ============================================================================
# E24 CANDIDATE PORTAL INTEGRATION - CONTACT SHARING UI
# ============================================================================

E24_CONTACT_SHARING_UI = """
<!-- 
    CONTACT SHARING COMPONENT FOR E24 CANDIDATE PORTAL
    Supports: iPhone vCard, Android Contacts, Outlook, Google, Desktop Upload
-->

<div id="contact-sharing-panel" class="portal-panel">
    <div class="panel-header">
        <h2><i class="fas fa-address-book"></i> Import Your Contacts</h2>
        <p class="subtitle">Add supporters from your phone or computer</p>
    </div>
    
    <div class="panel-body">
        <!-- DEVICE DETECTION -->
        <div id="device-detector" style="display:none;">
            <script>
                // Auto-detect device type
                const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
                const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
                const isAndroid = /Android/i.test(navigator.userAgent);
                
                document.getElementById('mobile-options').style.display = isMobile ? 'block' : 'none';
                document.getElementById('desktop-options').style.display = isMobile ? 'none' : 'block';
                
                // Store for API calls
                window.deviceInfo = {
                    isMobile: isMobile,
                    platform: isIOS ? 'ios' : (isAndroid ? 'android' : 'desktop')
                };
            </script>
        </div>
        
        <!-- MOBILE OPTIONS (iPhone/Android) -->
        <div id="mobile-options" class="upload-section">
            <h3><i class="fas fa-mobile-alt"></i> Share From Phone</h3>
            
            <div class="share-method">
                <button onclick="triggerNativeShare()" class="btn-primary btn-large">
                    <i class="fas fa-share-alt"></i>
                    Share Contacts
                </button>
                <p class="help-text">Opens your phone's contact picker</p>
            </div>
            
            <div class="or-divider">— OR —</div>
            
            <div class="share-method">
                <h4>Export & Upload</h4>
                <div class="instructions">
                    <div class="instruction-step" id="ios-instructions">
                        <strong>iPhone:</strong>
                        <ol>
                            <li>Open Contacts app</li>
                            <li>Select contacts to share</li>
                            <li>Tap "Share Contact"</li>
                            <li>Choose "Save to Files"</li>
                            <li>Upload the .vcf file below</li>
                        </ol>
                    </div>
                    <div class="instruction-step" id="android-instructions">
                        <strong>Android:</strong>
                        <ol>
                            <li>Open Contacts app</li>
                            <li>Menu → Export</li>
                            <li>Save as .vcf file</li>
                            <li>Upload the file below</li>
                        </ol>
                    </div>
                </div>
                
                <input type="file" id="mobile-contact-file" 
                       accept=".vcf,.csv" 
                       onchange="handleContactFileUpload(this)"
                       style="display:none;">
                <button onclick="document.getElementById('mobile-contact-file').click()" 
                        class="btn-secondary">
                    <i class="fas fa-upload"></i> Upload Contact File
                </button>
            </div>
        </div>
        
        <!-- DESKTOP OPTIONS (Windows/Mac) -->
        <div id="desktop-options" class="upload-section">
            <h3><i class="fas fa-laptop"></i> Import From Computer</h3>
            
            <!-- DRAG & DROP ZONE -->
            <div id="contact-dropzone" 
                 ondrop="handleContactDrop(event)" 
                 ondragover="event.preventDefault(); this.classList.add('dragover')"
                 ondragleave="this.classList.remove('dragover')">
                <i class="fas fa-cloud-upload-alt fa-3x"></i>
                <p>Drag & drop contact file here</p>
                <p class="help-text">Supports: vCard (.vcf), Outlook CSV, Google Contacts CSV</p>
            </div>
            
            <div class="or-divider">— OR —</div>
            
            <input type="file" id="desktop-contact-file" 
                   accept=".vcf,.csv,.contact" 
                   onchange="handleContactFileUpload(this)"
                   style="display:none;">
            <button onclick="document.getElementById('desktop-contact-file').click()" 
                    class="btn-secondary">
                <i class="fas fa-folder-open"></i> Browse Files
            </button>
            
            <!-- EXPORT INSTRUCTIONS -->
            <div class="export-instructions accordion">
                <details>
                    <summary><i class="fab fa-apple"></i> Export from iPhone/Mac Contacts</summary>
                    <ol>
                        <li>Open Contacts app</li>
                        <li>Select contacts (Cmd+A for all)</li>
                        <li>File → Export → Export vCard</li>
                        <li>Upload the .vcf file here</li>
                    </ol>
                </details>
                
                <details>
                    <summary><i class="fab fa-microsoft"></i> Export from Outlook</summary>
                    <ol>
                        <li>Open Outlook</li>
                        <li>File → Open & Export → Import/Export</li>
                        <li>Select "Export to a file" → CSV</li>
                        <li>Choose Contacts folder</li>
                        <li>Upload the CSV file here</li>
                    </ol>
                </details>
                
                <details>
                    <summary><i class="fab fa-google"></i> Export from Google Contacts</summary>
                    <ol>
                        <li>Go to contacts.google.com</li>
                        <li>Select contacts or "All contacts"</li>
                        <li>Export → Google CSV or vCard</li>
                        <li>Upload the file here</li>
                    </ol>
                </details>
                
                <details>
                    <summary><i class="fab fa-windows"></i> Export from Windows People</summary>
                    <ol>
                        <li>Open People app</li>
                        <li>Settings → Export contacts</li>
                        <li>Upload the exported file here</li>
                    </ol>
                </details>
            </div>
            
            <!-- QR CODE FOR MOBILE -->
            <div class="qr-share-option">
                <h4>Share from Phone Instead?</h4>
                <button onclick="generateContactUploadQR()" class="btn-outline">
                    <i class="fas fa-qrcode"></i> Show QR Code
                </button>
                <p class="help-text">Scan with your phone to share contacts</p>
                <div id="contact-qr-code" style="display:none;"></div>
            </div>
        </div>
        
        <!-- UPLOAD PROGRESS -->
        <div id="contact-upload-progress" style="display:none;">
            <div class="progress-bar">
                <div class="progress-fill" id="upload-progress-fill"></div>
            </div>
            <p id="upload-status">Processing contacts...</p>
        </div>
        
        <!-- IMPORT RESULTS -->
        <div id="contact-import-results" style="display:none;">
            <div class="results-summary">
                <div class="stat success">
                    <span class="number" id="imported-count">0</span>
                    <span class="label">Imported</span>
                </div>
                <div class="stat warning">
                    <span class="number" id="duplicate-count">0</span>
                    <span class="label">Duplicates</span>
                </div>
                <div class="stat error">
                    <span class="number" id="error-count">0</span>
                    <span class="label">Errors</span>
                </div>
            </div>
            <button onclick="resetContactUpload()" class="btn-outline">
                <i class="fas fa-redo"></i> Import More
            </button>
        </div>
    </div>
</div>

<script>
// Contact Upload JavaScript for E24 Portal

const ContactUploader = {
    candidateId: null,
    
    init(candidateId) {
        this.candidateId = candidateId;
        this.detectDevice();
    },
    
    detectDevice() {
        const isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
        document.getElementById('mobile-options').style.display = isMobile ? 'block' : 'none';
        document.getElementById('desktop-options').style.display = isMobile ? 'none' : 'block';
        
        // Show platform-specific instructions
        const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
        if (isMobile) {
            document.getElementById('ios-instructions').style.display = isIOS ? 'block' : 'none';
            document.getElementById('android-instructions').style.display = isIOS ? 'none' : 'block';
        }
    },
    
    async triggerNativeShare() {
        // For mobile: Try Web Share API or generate upload link
        if (navigator.share && navigator.canShare) {
            // Web Share API available (modern mobile browsers)
            try {
                // Generate secure upload link first
                const linkData = await this.getUploadLink();
                
                await navigator.share({
                    title: 'Share Contacts with Campaign',
                    text: 'Upload your contacts to help the campaign',
                    url: linkData.upload_url
                });
            } catch(err) {
                if (err.name !== 'AbortError') {
                    // Fallback to manual upload
                    document.getElementById('mobile-contact-file').click();
                }
            }
        } else {
            // Fallback: Show file picker
            document.getElementById('mobile-contact-file').click();
        }
    },
    
    async getUploadLink() {
        const response = await fetch('/api/v1/contacts/share-link', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                candidate_id: this.candidateId,
                platform: window.deviceInfo?.platform || 'desktop'
            })
        });
        return await response.json();
    },
    
    async handleFileUpload(input) {
        const file = input.files[0];
        if (!file) return;
        
        // Show progress
        document.getElementById('contact-upload-progress').style.display = 'block';
        document.getElementById('contact-import-results').style.display = 'none';
        
        const formData = new FormData();
        formData.append('file', file);
        formData.append('candidate_id', this.candidateId);
        formData.append('user_id', getCurrentUserId());
        
        try {
            const response = await fetch('/api/v1/contacts/upload', {
                method: 'POST',
                body: formData
            });
            
            const result = await response.json();
            this.showResults(result);
            
        } catch(err) {
            this.showError(err.message);
        }
    },
    
    handleDrop(event) {
        event.preventDefault();
        event.target.classList.remove('dragover');
        
        const file = event.dataTransfer.files[0];
        if (file) {
            // Create a fake input event
            const input = { files: [file] };
            this.handleFileUpload(input);
        }
    },
    
    async generateQRCode() {
        const linkData = await this.getUploadLink();
        
        // Generate QR code (using QRCode.js library)
        const qrContainer = document.getElementById('contact-qr-code');
        qrContainer.style.display = 'block';
        qrContainer.innerHTML = '';
        
        if (typeof QRCode !== 'undefined') {
            new QRCode(qrContainer, {
                text: linkData.upload_url,
                width: 200,
                height: 200
            });
        } else {
            // Fallback: show link
            qrContainer.innerHTML = `
                <p>Scan this link on your phone:</p>
                <code>${linkData.upload_url}</code>
            `;
        }
    },
    
    showResults(result) {
        document.getElementById('contact-upload-progress').style.display = 'none';
        document.getElementById('contact-import-results').style.display = 'block';
        
        document.getElementById('imported-count').textContent = result.imported || 0;
        document.getElementById('duplicate-count').textContent = result.duplicates || 0;
        document.getElementById('error-count').textContent = result.errors || 0;
        
        // Trigger E01 refresh if available
        if (typeof refreshDonorList === 'function') {
            refreshDonorList();
        }
    },
    
    showError(message) {
        document.getElementById('contact-upload-progress').style.display = 'none';
        document.getElementById('upload-status').textContent = 'Error: ' + message;
        document.getElementById('upload-status').classList.add('error');
    },
    
    reset() {
        document.getElementById('contact-upload-progress').style.display = 'none';
        document.getElementById('contact-import-results').style.display = 'none';
        document.getElementById('mobile-contact-file').value = '';
        document.getElementById('desktop-contact-file').value = '';
    }
};

// Global functions for HTML onclick handlers
function triggerNativeShare() { ContactUploader.triggerNativeShare(); }
function handleContactFileUpload(input) { ContactUploader.handleFileUpload(input); }
function handleContactDrop(event) { ContactUploader.handleDrop(event); }
function generateContactUploadQR() { ContactUploader.generateQRCode(); }
function resetContactUpload() { ContactUploader.reset(); }

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    ContactUploader.init(getCurrentCandidateId());
});
</script>

<style>
/* Contact Sharing Panel Styles */
#contact-sharing-panel {
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    margin: 20px 0;
}

#contact-sharing-panel .panel-header {
    background: linear-gradient(135deg, #1a365d, #2563eb);
    color: white;
    padding: 20px;
    border-radius: 8px 8px 0 0;
}

#contact-sharing-panel .panel-header h2 {
    margin: 0;
    font-size: 1.5rem;
}

#contact-sharing-panel .subtitle {
    margin: 5px 0 0;
    opacity: 0.8;
}

#contact-sharing-panel .panel-body {
    padding: 20px;
}

.upload-section {
    margin-bottom: 30px;
}

.upload-section h3 {
    color: #1a365d;
    border-bottom: 2px solid #e2e8f0;
    padding-bottom: 10px;
}

#contact-dropzone {
    border: 2px dashed #cbd5e0;
    border-radius: 8px;
    padding: 40px;
    text-align: center;
    color: #718096;
    transition: all 0.3s;
    cursor: pointer;
}

#contact-dropzone:hover,
#contact-dropzone.dragover {
    border-color: #2563eb;
    background: #ebf4ff;
    color: #2563eb;
}

.or-divider {
    text-align: center;
    color: #a0aec0;
    margin: 20px 0;
}

.btn-primary {
    background: linear-gradient(135deg, #2563eb, #1d4ed8);
    color: white;
    border: none;
    padding: 15px 30px;
    border-radius: 8px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: transform 0.2s;
}

.btn-primary:hover {
    transform: translateY(-2px);
}

.btn-secondary {
    background: #e2e8f0;
    color: #1a365d;
    border: none;
    padding: 12px 25px;
    border-radius: 6px;
    cursor: pointer;
}

.btn-outline {
    background: transparent;
    border: 2px solid #2563eb;
    color: #2563eb;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
}

.help-text {
    font-size: 0.85rem;
    color: #718096;
    margin-top: 5px;
}

.export-instructions details {
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    margin: 10px 0;
    padding: 10px 15px;
}

.export-instructions summary {
    cursor: pointer;
    font-weight: 500;
    color: #1a365d;
}

.export-instructions ol {
    margin: 10px 0 0 20px;
    color: #4a5568;
}

.results-summary {
    display: flex;
    justify-content: space-around;
    padding: 20px;
    background: #f7fafc;
    border-radius: 8px;
    margin-bottom: 20px;
}

.results-summary .stat {
    text-align: center;
}

.results-summary .number {
    display: block;
    font-size: 2rem;
    font-weight: bold;
}

.results-summary .success .number { color: #38a169; }
.results-summary .warning .number { color: #d69e2e; }
.results-summary .error .number { color: #e53e3e; }

.progress-bar {
    background: #e2e8f0;
    border-radius: 10px;
    height: 10px;
    overflow: hidden;
}

.progress-fill {
    background: linear-gradient(90deg, #2563eb, #38a169);
    height: 100%;
    width: 0%;
    animation: progress 2s ease-in-out infinite;
}

@keyframes progress {
    0% { width: 0%; }
    50% { width: 70%; }
    100% { width: 100%; }
}
</style>
"""


# ============================================================================
# CLI
# ============================================================================

if __name__ == "__main__":
    import sys

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01ContactImportError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01ContactImportValidationError(01ContactImportError):
    """Validation error in this ecosystem"""
    pass

class 01ContactImportDatabaseError(01ContactImportError):
    """Database error in this ecosystem"""
    pass

class 01ContactImportAPIError(01ContactImportError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===


# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 01ContactImportError(Exception):
    """Base exception for this ecosystem"""
    pass

class 01ContactImportValidationError(01ContactImportError):
    """Validation error in this ecosystem"""
    pass

class 01ContactImportDatabaseError(01ContactImportError):
    """Database error in this ecosystem"""
    pass

class 01ContactImportAPIError(01ContactImportError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===

    
    if len(sys.argv) < 2:
        print("📱 E01 Contact Import Engine")
        print()
        print("Usage:")
        print("  python ecosystem_01_contact_import.py --deploy")
        print("  python ecosystem_01_contact_import.py --parse <file.vcf>")
        print("  python ecosystem_01_contact_import.py --import <candidate_id> <file>")
        print()
        print("Supported formats:")
        print("  • iPhone vCard (.vcf)")
        print("  • Outlook contacts (.csv)")
        print("  • Google Contacts (.csv)")
        print("  • Windows Contacts (.contact)")
        print()
        sys.exit(0)
    
    command = sys.argv[1]
    
    if command == "--deploy":
        conn = psycopg2.connect(ContactImportConfig.DATABASE_URL)
        cur = conn.cursor()
        cur.execute(CONTACT_IMPORT_SCHEMA)
        conn.commit()
        conn.close()
        print("✅ Contact Import schema deployed!")
    
    elif command == "--parse" and len(sys.argv) > 2:
        file_path = sys.argv[2]
        with open(file_path, 'rb') as f:
            content = f.read()
        
        engine = ContactImportEngine('test')
        contacts = engine.parse_file(content, file_path)
        
        print(f"Found {len(contacts)} contacts:")
        for c in contacts[:10]:
            print(f"  • {c.full_name or 'Unknown'}: {c.email or 'no email'}, {c.phone or 'no phone'}")
    
    elif command == "--import" and len(sys.argv) > 3:
        candidate_id = sys.argv[2]
        file_path = sys.argv[3]
        
        with open(file_path, 'rb') as f:
            content = f.read()
        
        engine = ContactImportEngine(candidate_id)
        result = engine.import_contacts(content, file_path, 'cli')
        
        print(f"Import complete:")
        print(f"  Total: {result.total_contacts}")
        print(f"  Imported: {result.imported}")
        print(f"  Duplicates: {result.duplicates}")
        print(f"  Errors: {result.errors}")
