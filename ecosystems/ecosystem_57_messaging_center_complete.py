#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 52: MESSAGING CENTER - DONOR/VOLUNTEER TO CANDIDATE COMMUNICATION
================================================================================
Two-way messaging system integrated with Inspinia template allowing donors and
volunteers to communicate directly with candidates through the BroyhillGOP portal.

Features:
- Inbound SMS/portal messages from donors/volunteers to candidates
- Candidate message center (user silo inbox)
- Real-time notifications via top panel icon (next to settings)
- Candidate newsfeed integration
- Profile homepage newsfeed display
- Two-way response capability
- Full message logging with datetime stamps
- Thread-based conversations
- Read/unread status tracking
- Priority flagging and categorization

Inspinia Integration:
- Message icon in top navbar (badge count)
- Message center page (message_center.html)
- Candidate dashboard widget
- Profile newsfeed component

Development Value: $85,000
================================================================================
"""

import os
import json
import logging
import uuid
import asyncio
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem52.messaging_center')

# ============================================================================
# ENUMS
# ============================================================================

class MessageDirection(Enum):
    INBOUND = 'inbound'    # Donor/volunteer to candidate
    OUTBOUND = 'outbound'  # Candidate to donor/volunteer

class MessageChannel(Enum):
    SMS = 'sms'
    PORTAL = 'portal'
    EMAIL = 'email'
    WHATSAPP = 'whatsapp'

class MessageStatus(Enum):
    PENDING = 'pending'
    DELIVERED = 'delivered'
    READ = 'read'
    REPLIED = 'replied'
    ARCHIVED = 'archived'
    FLAGGED = 'flagged'

class MessagePriority(Enum):
    LOW = 'low'
    NORMAL = 'normal'
    HIGH = 'high'
    URGENT = 'urgent'

class SenderType(Enum):
    DONOR = 'donor'
    VOLUNTEER = 'volunteer'
    SUPPORTER = 'supporter'
    VIP = 'vip'
    STAFF = 'staff'
    UNKNOWN = 'unknown'

class MessageCategory(Enum):
    GENERAL = 'general'
    QUESTION = 'question'
    FEEDBACK = 'feedback'
    COMPLAINT = 'complaint'
    ENDORSEMENT = 'endorsement'
    DONATION_INQUIRY = 'donation_inquiry'
    VOLUNTEER_SIGNUP = 'volunteer_signup'
    EVENT_INQUIRY = 'event_inquiry'
    MEDIA_REQUEST = 'media_request'
    URGENT = 'urgent'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class MessageAttachment:
    attachment_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    filename: str = ''
    file_type: str = ''
    file_size: int = 0
    storage_url: str = ''
    thumbnail_url: Optional[str] = None
    uploaded_at: datetime = field(default_factory=datetime.now)

@dataclass
class Message:
    message_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    thread_id: str = ''
    candidate_id: str = ''
    
    # Sender info
    sender_id: str = ''
    sender_name: str = ''
    sender_phone: Optional[str] = None
    sender_email: Optional[str] = None
    sender_type: SenderType = SenderType.UNKNOWN
    
    # Message content
    direction: MessageDirection = MessageDirection.INBOUND
    channel: MessageChannel = MessageChannel.PORTAL
    subject: Optional[str] = None
    body: str = ''
    attachments: List[MessageAttachment] = field(default_factory=list)
    
    # Status
    status: MessageStatus = MessageStatus.PENDING
    priority: MessagePriority = MessagePriority.NORMAL
    category: MessageCategory = MessageCategory.GENERAL
    
    # Metadata
    is_read: bool = False
    read_at: Optional[datetime] = None
    replied_at: Optional[datetime] = None
    reply_message_id: Optional[str] = None
    
    # Timestamps
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class MessageThread:
    thread_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    
    # Contact info
    contact_id: str = ''
    contact_name: str = ''
    contact_phone: Optional[str] = None
    contact_email: Optional[str] = None
    contact_type: SenderType = SenderType.UNKNOWN
    
    # Thread metadata
    subject: str = ''
    last_message_preview: str = ''
    last_message_at: datetime = field(default_factory=datetime.now)
    last_message_direction: MessageDirection = MessageDirection.INBOUND
    
    # Status
    message_count: int = 0
    unread_count: int = 0
    is_starred: bool = False
    is_archived: bool = False
    priority: MessagePriority = MessagePriority.NORMAL
    category: MessageCategory = MessageCategory.GENERAL
    
    # Labels/tags
    labels: List[str] = field(default_factory=list)
    
    # Messages in thread
    messages: List[Message] = field(default_factory=list)
    
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class NewsfeedItem:
    item_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    item_type: str = 'message'  # message, donation, volunteer_signup, etc.
    
    # Content
    title: str = ''
    summary: str = ''
    icon: str = 'fa-envelope'
    icon_color: str = 'primary'
    
    # Link to source
    source_id: str = ''
    source_type: str = ''
    action_url: Optional[str] = None
    
    # Display
    is_read: bool = False
    is_pinned: bool = False
    
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class NotificationBadge:
    candidate_id: str = ''
    unread_messages: int = 0
    urgent_messages: int = 0
    new_threads: int = 0
    last_updated: datetime = field(default_factory=datetime.now)

# ============================================================================
# MESSAGE CENTER CORE
# ============================================================================

class MessageCenter:
    """Core messaging center for candidate-constituent communication."""
    
    def __init__(self, supabase_client=None, redis_client=None):
        self.supabase = supabase_client
        self.redis = redis_client
        
        # In-memory storage (production uses database)
        self.threads: Dict[str, MessageThread] = {}
        self.messages: Dict[str, Message] = {}
        self.newsfeed: Dict[str, List[NewsfeedItem]] = defaultdict(list)
        self.badges: Dict[str, NotificationBadge] = {}
    
    # =========================================================================
    # INBOUND MESSAGE HANDLING
    # =========================================================================
    
    async def receive_message(
        self,
        candidate_id: str,
        sender_id: str,
        sender_name: str,
        body: str,
        channel: MessageChannel = MessageChannel.PORTAL,
        sender_phone: Optional[str] = None,
        sender_email: Optional[str] = None,
        sender_type: SenderType = SenderType.UNKNOWN,
        subject: Optional[str] = None,
        attachments: Optional[List[Dict]] = None
    ) -> Tuple[Message, MessageThread]:
        """Receive an inbound message from donor/volunteer."""
        
        # Find or create thread
        thread = await self._find_or_create_thread(
            candidate_id=candidate_id,
            contact_id=sender_id,
            contact_name=sender_name,
            contact_phone=sender_phone,
            contact_email=sender_email,
            contact_type=sender_type,
            subject=subject or f"Message from {sender_name}"
        )
        
        # Create message
        message = Message(
            thread_id=thread.thread_id,
            candidate_id=candidate_id,
            sender_id=sender_id,
            sender_name=sender_name,
            sender_phone=sender_phone,
            sender_email=sender_email,
            sender_type=sender_type,
            direction=MessageDirection.INBOUND,
            channel=channel,
            subject=subject,
            body=body,
            status=MessageStatus.DELIVERED,
            category=self._auto_categorize_message(body)
        )
        
        # Handle attachments
        if attachments:
            for att_data in attachments:
                attachment = MessageAttachment(**att_data)
                message.attachments.append(attachment)
        
        # Auto-detect priority
        message.priority = self._detect_priority(body, sender_type)
        
        # Add to thread
        thread.messages.append(message)
        thread.message_count += 1
        thread.unread_count += 1
        thread.last_message_preview = body[:100] + ('...' if len(body) > 100 else '')
        thread.last_message_at = message.created_at
        thread.last_message_direction = MessageDirection.INBOUND
        thread.updated_at = datetime.now()
        
        # Store
        self.messages[message.message_id] = message
        self.threads[thread.thread_id] = thread
        
        # Update notification badge
        await self._update_badge(candidate_id)
        
        # Create newsfeed item
        await self._create_newsfeed_item(candidate_id, message, thread)
        
        # Publish real-time notification
        await self._publish_notification(candidate_id, message, thread)
        
        # Save to database
        if self.supabase:
            await self._save_message_to_db(message)
            await self._save_thread_to_db(thread)
        
        logger.info(
            f"Message received from {sender_name} to candidate {candidate_id} "
            f"via {channel.value} [Thread: {thread.thread_id[:8]}]"
        )
        
        return message, thread
    
    async def receive_sms(
        self,
        candidate_id: str,
        from_phone: str,
        body: str,
        sender_name: Optional[str] = None
    ) -> Tuple[Message, MessageThread]:
        """Receive inbound SMS message."""
        # Lookup sender by phone
        sender_info = await self._lookup_contact_by_phone(from_phone)
        
        return await self.receive_message(
            candidate_id=candidate_id,
            sender_id=sender_info.get('id', from_phone),
            sender_name=sender_info.get('name', sender_name or from_phone),
            body=body,
            channel=MessageChannel.SMS,
            sender_phone=from_phone,
            sender_type=SenderType(sender_info.get('type', 'unknown'))
        )
    
    # =========================================================================
    # OUTBOUND MESSAGE HANDLING
    # =========================================================================
    
    async def send_reply(
        self,
        candidate_id: str,
        thread_id: str,
        body: str,
        channel: Optional[MessageChannel] = None,
        attachments: Optional[List[Dict]] = None
    ) -> Message:
        """Send reply from candidate to constituent."""
        thread = self.threads.get(thread_id)
        if not thread:
            raise ValueError(f"Thread {thread_id} not found")
        
        if thread.candidate_id != candidate_id:
            raise ValueError("Thread does not belong to this candidate")
        
        # Use same channel as last inbound message if not specified
        if not channel:
            inbound_msgs = [m for m in thread.messages if m.direction == MessageDirection.INBOUND]
            channel = inbound_msgs[-1].channel if inbound_msgs else MessageChannel.PORTAL
        
        # Create outbound message
        message = Message(
            thread_id=thread_id,
            candidate_id=candidate_id,
            sender_id=candidate_id,
            sender_name='Campaign',  # Or candidate name
            direction=MessageDirection.OUTBOUND,
            channel=channel,
            body=body,
            status=MessageStatus.PENDING
        )
        
        # Handle attachments
        if attachments:
            for att_data in attachments:
                attachment = MessageAttachment(**att_data)
                message.attachments.append(attachment)
        
        # Add to thread
        thread.messages.append(message)
        thread.message_count += 1
        thread.last_message_preview = body[:100] + ('...' if len(body) > 100 else '')
        thread.last_message_at = message.created_at
        thread.last_message_direction = MessageDirection.OUTBOUND
        thread.updated_at = datetime.now()
        
        # Mark previous inbound messages as replied
        for msg in thread.messages:
            if msg.direction == MessageDirection.INBOUND and msg.status != MessageStatus.REPLIED:
                msg.status = MessageStatus.REPLIED
                msg.replied_at = datetime.now()
                msg.reply_message_id = message.message_id
        
        # Store
        self.messages[message.message_id] = message
        
        # Send via appropriate channel
        await self._dispatch_outbound_message(message, thread)
        
        # Update badge
        await self._update_badge(candidate_id)
        
        # Save to database
        if self.supabase:
            await self._save_message_to_db(message)
            await self._save_thread_to_db(thread)
        
        logger.info(f"Reply sent to {thread.contact_name} via {channel.value}")
        
        return message
    
    async def _dispatch_outbound_message(self, message: Message, thread: MessageThread):
        """Dispatch message via appropriate channel."""
        if message.channel == MessageChannel.SMS and thread.contact_phone:
            # Send via E31 SMS system
            if self.redis:
                await self.redis.publish('e31:sms:send', json.dumps({
                    'to': thread.contact_phone,
                    'message': message.body,
                    'source': 'message_center',
                    'message_id': message.message_id
                }))
            message.status = MessageStatus.DELIVERED
            
        elif message.channel == MessageChannel.EMAIL and thread.contact_email:
            # Send via E30 Email system
            if self.redis:
                await self.redis.publish('e30:email:send', json.dumps({
                    'to': thread.contact_email,
                    'subject': f"Re: {thread.subject}",
                    'body': message.body,
                    'source': 'message_center',
                    'message_id': message.message_id
                }))
            message.status = MessageStatus.DELIVERED
            
        elif message.channel == MessageChannel.PORTAL:
            # Portal message - just mark delivered (user will see in portal)
            message.status = MessageStatus.DELIVERED
        
        message.updated_at = datetime.now()
    
    # =========================================================================
    # THREAD MANAGEMENT
    # =========================================================================
    
    async def _find_or_create_thread(
        self,
        candidate_id: str,
        contact_id: str,
        contact_name: str,
        contact_phone: Optional[str] = None,
        contact_email: Optional[str] = None,
        contact_type: SenderType = SenderType.UNKNOWN,
        subject: str = ''
    ) -> MessageThread:
        """Find existing thread or create new one."""
        # Look for existing thread with this contact
        for thread in self.threads.values():
            if (thread.candidate_id == candidate_id and 
                thread.contact_id == contact_id and
                not thread.is_archived):
                return thread
        
        # Create new thread
        thread = MessageThread(
            candidate_id=candidate_id,
            contact_id=contact_id,
            contact_name=contact_name,
            contact_phone=contact_phone,
            contact_email=contact_email,
            contact_type=contact_type,
            subject=subject
        )
        
        self.threads[thread.thread_id] = thread
        return thread
    
    async def get_threads(
        self,
        candidate_id: str,
        include_archived: bool = False,
        category: Optional[MessageCategory] = None,
        priority: Optional[MessagePriority] = None,
        unread_only: bool = False,
        limit: int = 50,
        offset: int = 0
    ) -> List[MessageThread]:
        """Get message threads for a candidate."""
        threads = [
            t for t in self.threads.values()
            if t.candidate_id == candidate_id
        ]
        
        # Filters
        if not include_archived:
            threads = [t for t in threads if not t.is_archived]
        
        if category:
            threads = [t for t in threads if t.category == category]
        
        if priority:
            threads = [t for t in threads if t.priority == priority]
        
        if unread_only:
            threads = [t for t in threads if t.unread_count > 0]
        
        # Sort by last message time (newest first)
        threads.sort(key=lambda t: t.last_message_at, reverse=True)
        
        # Pagination
        return threads[offset:offset + limit]
    
    async def get_thread(self, thread_id: str) -> Optional[MessageThread]:
        """Get a specific thread with all messages."""
        return self.threads.get(thread_id)
    
    async def mark_thread_read(self, candidate_id: str, thread_id: str):
        """Mark all messages in thread as read."""
        thread = self.threads.get(thread_id)
        if not thread or thread.candidate_id != candidate_id:
            return
        
        for message in thread.messages:
            if message.direction == MessageDirection.INBOUND and not message.is_read:
                message.is_read = True
                message.read_at = datetime.now()
                message.status = MessageStatus.READ
        
        thread.unread_count = 0
        thread.updated_at = datetime.now()
        
        await self._update_badge(candidate_id)
        
        if self.supabase:
            await self._save_thread_to_db(thread)
    
    async def star_thread(self, candidate_id: str, thread_id: str, starred: bool = True):
        """Star/unstar a thread."""
        thread = self.threads.get(thread_id)
        if thread and thread.candidate_id == candidate_id:
            thread.is_starred = starred
            thread.updated_at = datetime.now()
    
    async def archive_thread(self, candidate_id: str, thread_id: str):
        """Archive a thread."""
        thread = self.threads.get(thread_id)
        if thread and thread.candidate_id == candidate_id:
            thread.is_archived = True
            thread.updated_at = datetime.now()
            await self._update_badge(candidate_id)
    
    async def add_label(self, candidate_id: str, thread_id: str, label: str):
        """Add label to thread."""
        thread = self.threads.get(thread_id)
        if thread and thread.candidate_id == candidate_id:
            if label not in thread.labels:
                thread.labels.append(label)
                thread.updated_at = datetime.now()
    
    # =========================================================================
    # NOTIFICATION BADGE
    # =========================================================================
    
    async def _update_badge(self, candidate_id: str):
        """Update notification badge counts."""
        threads = [
            t for t in self.threads.values()
            if t.candidate_id == candidate_id and not t.is_archived
        ]
        
        unread_messages = sum(t.unread_count for t in threads)
        urgent_messages = sum(
            1 for t in threads 
            if t.priority == MessagePriority.URGENT and t.unread_count > 0
        )
        
        # Count new threads (created in last 24 hours)
        yesterday = datetime.now() - timedelta(hours=24)
        new_threads = sum(1 for t in threads if t.created_at > yesterday)
        
        badge = NotificationBadge(
            candidate_id=candidate_id,
            unread_messages=unread_messages,
            urgent_messages=urgent_messages,
            new_threads=new_threads,
            last_updated=datetime.now()
        )
        
        self.badges[candidate_id] = badge
        
        # Publish to Redis for real-time updates
        if self.redis:
            await self.redis.publish(f'badge:{candidate_id}', json.dumps({
                'unread': unread_messages,
                'urgent': urgent_messages,
                'new_threads': new_threads
            }))
        
        return badge
    
    async def get_badge(self, candidate_id: str) -> NotificationBadge:
        """Get current notification badge counts."""
        if candidate_id not in self.badges:
            await self._update_badge(candidate_id)
        return self.badges.get(candidate_id, NotificationBadge(candidate_id=candidate_id))
    
    # =========================================================================
    # NEWSFEED INTEGRATION
    # =========================================================================
    
    async def _create_newsfeed_item(
        self,
        candidate_id: str,
        message: Message,
        thread: MessageThread
    ):
        """Create newsfeed item for new message."""
        # Determine icon based on channel/type
        icons = {
            MessageChannel.SMS: ('fa-mobile', 'info'),
            MessageChannel.EMAIL: ('fa-envelope', 'primary'),
            MessageChannel.PORTAL: ('fa-comment', 'success'),
            MessageChannel.WHATSAPP: ('fa-whatsapp', 'success')
        }
        icon, color = icons.get(message.channel, ('fa-envelope', 'primary'))
        
        # Urgent messages get warning color
        if message.priority == MessagePriority.URGENT:
            color = 'danger'
            icon = 'fa-exclamation-circle'
        
        item = NewsfeedItem(
            candidate_id=candidate_id,
            item_type='message',
            title=f"New message from {message.sender_name}",
            summary=message.body[:150] + ('...' if len(message.body) > 150 else ''),
            icon=icon,
            icon_color=color,
            source_id=thread.thread_id,
            source_type='message_thread',
            action_url=f"/message-center/{thread.thread_id}"
        )
        
        self.newsfeed[candidate_id].insert(0, item)
        
        # Keep only last 100 items
        if len(self.newsfeed[candidate_id]) > 100:
            self.newsfeed[candidate_id] = self.newsfeed[candidate_id][:100]
        
        if self.supabase:
            await self._save_newsfeed_item_to_db(item)
    
    async def get_newsfeed(
        self,
        candidate_id: str,
        limit: int = 20,
        offset: int = 0,
        item_type: Optional[str] = None
    ) -> List[NewsfeedItem]:
        """Get newsfeed items for candidate dashboard."""
        items = self.newsfeed.get(candidate_id, [])
        
        if item_type:
            items = [i for i in items if i.item_type == item_type]
        
        return items[offset:offset + limit]
    
    # =========================================================================
    # REAL-TIME NOTIFICATIONS
    # =========================================================================
    
    async def _publish_notification(
        self,
        candidate_id: str,
        message: Message,
        thread: MessageThread
    ):
        """Publish real-time notification via Redis/WebSocket."""
        if not self.redis:
            return
        
        notification = {
            'type': 'new_message',
            'candidate_id': candidate_id,
            'thread_id': thread.thread_id,
            'message_id': message.message_id,
            'sender_name': message.sender_name,
            'preview': message.body[:100],
            'channel': message.channel.value,
            'priority': message.priority.value,
            'timestamp': message.created_at.isoformat()
        }
        
        await self.redis.publish(f'notifications:{candidate_id}', json.dumps(notification))
    
    # =========================================================================
    # HELPER METHODS
    # =========================================================================
    
    def _auto_categorize_message(self, body: str) -> MessageCategory:
        """Auto-categorize message based on content."""
        body_lower = body.lower()
        
        # Check for donation-related
        if any(w in body_lower for w in ['donate', 'donation', 'contribute', 'contribution', 'money']):
            return MessageCategory.DONATION_INQUIRY
        
        # Check for volunteer
        if any(w in body_lower for w in ['volunteer', 'help out', 'sign up', 'join']):
            return MessageCategory.VOLUNTEER_SIGNUP
        
        # Check for event
        if any(w in body_lower for w in ['event', 'rally', 'meeting', 'attend']):
            return MessageCategory.EVENT_INQUIRY
        
        # Check for question
        if '?' in body:
            return MessageCategory.QUESTION
        
        # Check for complaint
        if any(w in body_lower for w in ['complaint', 'unhappy', 'disappointed', 'angry']):
            return MessageCategory.COMPLAINT
        
        # Check for endorsement/support
        if any(w in body_lower for w in ['endorse', 'support', 'vote for', 'backing']):
            return MessageCategory.ENDORSEMENT
        
        # Check for media
        if any(w in body_lower for w in ['interview', 'press', 'media', 'reporter', 'journalist']):
            return MessageCategory.MEDIA_REQUEST
        
        return MessageCategory.GENERAL
    
    def _detect_priority(self, body: str, sender_type: SenderType) -> MessagePriority:
        """Detect message priority."""
        body_lower = body.lower()
        
        # Urgent keywords
        if any(w in body_lower for w in ['urgent', 'emergency', 'asap', 'immediately', 'critical']):
            return MessagePriority.URGENT
        
        # VIP senders get high priority
        if sender_type == SenderType.VIP:
            return MessagePriority.HIGH
        
        # Media requests are high priority
        if any(w in body_lower for w in ['interview', 'press', 'deadline']):
            return MessagePriority.HIGH
        
        return MessagePriority.NORMAL
    
    async def _lookup_contact_by_phone(self, phone: str) -> Dict[str, Any]:
        """Lookup contact info by phone number."""
        # In production, query donor/volunteer database
        if self.supabase:
            try:
                # Check donors
                result = await self.supabase.table('donors').select(
                    'donor_id, first_name, last_name, donor_grade'
                ).eq('phone', phone).single().execute()
                
                if result.data:
                    grade = result.data.get('donor_grade', 'U')
                    sender_type = 'vip' if grade in ['A+', 'A', 'A-'] else 'donor'
                    return {
                        'id': result.data['donor_id'],
                        'name': f"{result.data['first_name']} {result.data['last_name']}",
                        'type': sender_type
                    }
                
                # Check volunteers
                result = await self.supabase.table('volunteers').select(
                    'volunteer_id, first_name, last_name'
                ).eq('phone', phone).single().execute()
                
                if result.data:
                    return {
                        'id': result.data['volunteer_id'],
                        'name': f"{result.data['first_name']} {result.data['last_name']}",
                        'type': 'volunteer'
                    }
            except:
                pass
        
        return {'id': phone, 'name': phone, 'type': 'unknown'}
    
    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_message_to_db(self, message: Message):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e52_messages').upsert({
                'message_id': message.message_id,
                'thread_id': message.thread_id,
                'candidate_id': message.candidate_id,
                'sender_id': message.sender_id,
                'sender_name': message.sender_name,
                'sender_phone': message.sender_phone,
                'sender_email': message.sender_email,
                'sender_type': message.sender_type.value,
                'direction': message.direction.value,
                'channel': message.channel.value,
                'subject': message.subject,
                'body': message.body,
                'status': message.status.value,
                'priority': message.priority.value,
                'category': message.category.value,
                'is_read': message.is_read,
                'read_at': message.read_at.isoformat() if message.read_at else None,
                'replied_at': message.replied_at.isoformat() if message.replied_at else None,
                'created_at': message.created_at.isoformat(),
                'updated_at': message.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save message: {e}")
    
    async def _save_thread_to_db(self, thread: MessageThread):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e52_message_threads').upsert({
                'thread_id': thread.thread_id,
                'candidate_id': thread.candidate_id,
                'contact_id': thread.contact_id,
                'contact_name': thread.contact_name,
                'contact_phone': thread.contact_phone,
                'contact_email': thread.contact_email,
                'contact_type': thread.contact_type.value,
                'subject': thread.subject,
                'last_message_preview': thread.last_message_preview,
                'last_message_at': thread.last_message_at.isoformat(),
                'last_message_direction': thread.last_message_direction.value,
                'message_count': thread.message_count,
                'unread_count': thread.unread_count,
                'is_starred': thread.is_starred,
                'is_archived': thread.is_archived,
                'priority': thread.priority.value,
                'category': thread.category.value,
                'labels': json.dumps(thread.labels),
                'created_at': thread.created_at.isoformat(),
                'updated_at': thread.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save thread: {e}")
    
    async def _save_newsfeed_item_to_db(self, item: NewsfeedItem):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e52_newsfeed').insert({
                'item_id': item.item_id,
                'candidate_id': item.candidate_id,
                'item_type': item.item_type,
                'title': item.title,
                'summary': item.summary,
                'icon': item.icon,
                'icon_color': item.icon_color,
                'source_id': item.source_id,
                'source_type': item.source_type,
                'action_url': item.action_url,
                'is_read': item.is_read,
                'created_at': item.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save newsfeed item: {e}")


# ============================================================================
# INSPINIA TEMPLATE INTEGRATION
# ============================================================================

class InspiniaMessageWidget:
    """Widget data for Inspinia template integration."""
    
    @staticmethod
    def get_navbar_badge_html(badge: NotificationBadge) -> str:
        """Generate HTML for navbar message badge (next to settings icon)."""
        badge_class = 'badge-danger' if badge.urgent_messages > 0 else 'badge-primary'
        count = badge.unread_messages
        
        return f"""
        <li class="nav-item dropdown">
            <a class="nav-link dropdown-toggle count-info" href="#" data-toggle="dropdown">
                <i class="fa fa-envelope"></i>
                {f'<span class="badge {badge_class}">{count}</span>' if count > 0 else ''}
            </a>
            <ul class="dropdown-menu dropdown-messages">
                <li class="dropdown-header">
                    <h6>You have {count} new message{'s' if count != 1 else ''}</h6>
                </li>
                <div id="message-dropdown-list"></div>
                <li class="dropdown-footer">
                    <a href="/message-center">View All Messages</a>
                </li>
            </ul>
        </li>
        """
    
    @staticmethod
    def get_dashboard_widget_html(threads: List[MessageThread], limit: int = 5) -> str:
        """Generate HTML for dashboard message widget."""
        messages_html = ""
        for thread in threads[:limit]:
            priority_class = 'border-left-danger' if thread.priority == MessagePriority.URGENT else ''
            unread_class = 'font-weight-bold' if thread.unread_count > 0 else ''
            
            messages_html += f"""
            <a href="/message-center/{thread.thread_id}" class="list-group-item list-group-item-action {priority_class}">
                <div class="d-flex w-100 justify-content-between">
                    <h6 class="mb-1 {unread_class}">{thread.contact_name}</h6>
                    <small class="text-muted">{thread.last_message_at.strftime('%b %d')}</small>
                </div>
                <p class="mb-1 small text-truncate">{thread.last_message_preview}</p>
                <small class="text-muted">{thread.channel if hasattr(thread, 'channel') else 'Portal'}</small>
            </a>
            """
        
        return f"""
        <div class="ibox">
            <div class="ibox-title">
                <h5><i class="fa fa-envelope"></i> Messages</h5>
                <div class="ibox-tools">
                    <a href="/message-center" class="btn btn-xs btn-primary">View All</a>
                </div>
            </div>
            <div class="ibox-content">
                <div class="list-group">
                    {messages_html if messages_html else '<p class="text-muted text-center">No messages</p>'}
                </div>
            </div>
        </div>
        """
    
    @staticmethod
    def get_newsfeed_widget_html(items: List[NewsfeedItem], limit: int = 10) -> str:
        """Generate HTML for profile homepage newsfeed."""
        feed_html = ""
        for item in items[:limit]:
            feed_html += f"""
            <div class="feed-element">
                <a href="{item.action_url or '#'}" class="float-left">
                    <div class="icon-circle bg-{item.icon_color}">
                        <i class="fa {item.icon} text-white"></i>
                    </div>
                </a>
                <div class="media-body">
                    <strong>{item.title}</strong>
                    <p class="mb-1 small">{item.summary}</p>
                    <small class="text-muted">{item.created_at.strftime('%b %d, %Y %I:%M %p')}</small>
                </div>
            </div>
            """
        
        return f"""
        <div class="ibox">
            <div class="ibox-title">
                <h5><i class="fa fa-rss"></i> Activity Feed</h5>
            </div>
            <div class="ibox-content">
                <div class="feed-activity-list">
                    {feed_html if feed_html else '<p class="text-muted text-center">No activity</p>'}
                </div>
            </div>
        </div>
        """


# ============================================================================
# API ROUTES (FastAPI/Flask Integration)
# ============================================================================

class MessageCenterAPI:
    """API endpoints for message center."""
    
    def __init__(self, message_center: MessageCenter):
        self.mc = message_center
    
    async def get_threads_endpoint(
        self,
        candidate_id: str,
        category: Optional[str] = None,
        priority: Optional[str] = None,
        unread_only: bool = False,
        limit: int = 50,
        offset: int = 0
    ) -> Dict[str, Any]:
        """GET /api/messages/threads"""
        threads = await self.mc.get_threads(
            candidate_id=candidate_id,
            category=MessageCategory(category) if category else None,
            priority=MessagePriority(priority) if priority else None,
            unread_only=unread_only,
            limit=limit,
            offset=offset
        )
        
        return {
            'threads': [self._serialize_thread(t) for t in threads],
            'total': len(threads),
            'limit': limit,
            'offset': offset
        }
    
    async def get_thread_endpoint(
        self,
        candidate_id: str,
        thread_id: str
    ) -> Dict[str, Any]:
        """GET /api/messages/threads/{thread_id}"""
        thread = await self.mc.get_thread(thread_id)
        if not thread or thread.candidate_id != candidate_id:
            return {'error': 'Thread not found'}
        
        # Mark as read when viewing
        await self.mc.mark_thread_read(candidate_id, thread_id)
        
        return self._serialize_thread(thread, include_messages=True)
    
    async def send_reply_endpoint(
        self,
        candidate_id: str,
        thread_id: str,
        body: str,
        channel: Optional[str] = None
    ) -> Dict[str, Any]:
        """POST /api/messages/threads/{thread_id}/reply"""
        message = await self.mc.send_reply(
            candidate_id=candidate_id,
            thread_id=thread_id,
            body=body,
            channel=MessageChannel(channel) if channel else None
        )
        
        return self._serialize_message(message)
    
    async def get_badge_endpoint(self, candidate_id: str) -> Dict[str, Any]:
        """GET /api/messages/badge"""
        badge = await self.mc.get_badge(candidate_id)
        return {
            'unread_messages': badge.unread_messages,
            'urgent_messages': badge.urgent_messages,
            'new_threads': badge.new_threads,
            'last_updated': badge.last_updated.isoformat()
        }
    
    async def get_newsfeed_endpoint(
        self,
        candidate_id: str,
        limit: int = 20,
        offset: int = 0
    ) -> Dict[str, Any]:
        """GET /api/messages/newsfeed"""
        items = await self.mc.get_newsfeed(candidate_id, limit, offset)
        return {
            'items': [self._serialize_newsfeed_item(i) for i in items],
            'total': len(items),
            'limit': limit,
            'offset': offset
        }
    
    def _serialize_thread(self, thread: MessageThread, include_messages: bool = False) -> Dict[str, Any]:
        data = {
            'thread_id': thread.thread_id,
            'contact': {
                'id': thread.contact_id,
                'name': thread.contact_name,
                'phone': thread.contact_phone,
                'email': thread.contact_email,
                'type': thread.contact_type.value
            },
            'subject': thread.subject,
            'last_message': {
                'preview': thread.last_message_preview,
                'at': thread.last_message_at.isoformat(),
                'direction': thread.last_message_direction.value
            },
            'message_count': thread.message_count,
            'unread_count': thread.unread_count,
            'is_starred': thread.is_starred,
            'is_archived': thread.is_archived,
            'priority': thread.priority.value,
            'category': thread.category.value,
            'labels': thread.labels,
            'created_at': thread.created_at.isoformat(),
            'updated_at': thread.updated_at.isoformat()
        }
        
        if include_messages:
            data['messages'] = [self._serialize_message(m) for m in thread.messages]
        
        return data
    
    def _serialize_message(self, message: Message) -> Dict[str, Any]:
        return {
            'message_id': message.message_id,
            'sender': {
                'id': message.sender_id,
                'name': message.sender_name,
                'type': message.sender_type.value
            },
            'direction': message.direction.value,
            'channel': message.channel.value,
            'subject': message.subject,
            'body': message.body,
            'status': message.status.value,
            'priority': message.priority.value,
            'category': message.category.value,
            'is_read': message.is_read,
            'read_at': message.read_at.isoformat() if message.read_at else None,
            'replied_at': message.replied_at.isoformat() if message.replied_at else None,
            'created_at': message.created_at.isoformat()
        }
    
    def _serialize_newsfeed_item(self, item: NewsfeedItem) -> Dict[str, Any]:
        return {
            'item_id': item.item_id,
            'type': item.item_type,
            'title': item.title,
            'summary': item.summary,
            'icon': item.icon,
            'icon_color': item.icon_color,
            'action_url': item.action_url,
            'is_read': item.is_read,
            'created_at': item.created_at.isoformat()
        }


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the messaging center."""
    mc = MessageCenter()
    
    candidate_id = 'dave-boliek-001'
    
    # Simulate receiving messages
    print("\n=== RECEIVING INBOUND MESSAGES ===")
    
    msg1, thread1 = await mc.receive_message(
        candidate_id=candidate_id,
        sender_id='donor-001',
        sender_name='John Smith',
        body='Hi Dave, I just donated $100 to your campaign. Keep fighting for judicial integrity!',
        channel=MessageChannel.PORTAL,
        sender_type=SenderType.DONOR
    )
    print(f"Message 1 received: {msg1.sender_name} - {msg1.category.value}")
    
    msg2, thread2 = await mc.receive_sms(
        candidate_id=candidate_id,
        from_phone='+13365551234',
        body='URGENT: I need to speak with the campaign about an endorsement opportunity. Please call me ASAP!',
        sender_name='Jane Doe'
    )
    print(f"Message 2 received: {msg2.sender_name} - {msg2.priority.value} priority")
    
    msg3, thread3 = await mc.receive_message(
        candidate_id=candidate_id,
        sender_id='vol-001',
        sender_name='Bob Wilson',
        body='I want to volunteer for your campaign! What events do you have coming up?',
        channel=MessageChannel.EMAIL,
        sender_email='bob@example.com',
        sender_type=SenderType.VOLUNTEER
    )
    print(f"Message 3 received: {msg3.sender_name} - {msg3.category.value}")
    
    # Get badge
    badge = await mc.get_badge(candidate_id)
    print(f"\n=== NOTIFICATION BADGE ===")
    print(f"Unread: {badge.unread_messages}, Urgent: {badge.urgent_messages}, New Threads: {badge.new_threads}")
    
    # Get threads
    threads = await mc.get_threads(candidate_id)
    print(f"\n=== MESSAGE THREADS ({len(threads)}) ===")
    for t in threads:
        print(f"  [{t.priority.value.upper()}] {t.contact_name}: {t.last_message_preview[:50]}...")
    
    # Send reply
    print("\n=== SENDING REPLY ===")
    reply = await mc.send_reply(
        candidate_id=candidate_id,
        thread_id=thread1.thread_id,
        body='Thank you so much for your generous support, John! Together we will restore integrity to our courts.'
    )
    print(f"Reply sent to {thread1.contact_name} via {reply.channel.value}")
    
    # Get newsfeed
    feed = await mc.get_newsfeed(candidate_id)
    print(f"\n=== NEWSFEED ({len(feed)} items) ===")
    for item in feed:
        print(f"  [{item.icon_color}] {item.title}: {item.summary[:50]}...")
    
    # Generate widget HTML
    widget = InspiniaMessageWidget()
    
    print("\n=== NAVBAR BADGE HTML ===")
    badge_html = widget.get_navbar_badge_html(badge)
    print(badge_html[:200] + '...')
    
    print("\n=== DASHBOARD WIDGET HTML ===")
    dashboard_html = widget.get_dashboard_widget_html(threads)
    print(dashboard_html[:300] + '...')


if __name__ == '__main__':
    asyncio.run(main())
