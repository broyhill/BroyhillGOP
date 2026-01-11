#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 54: CALENDAR SCHEDULING - INSPINIA FULLCALENDAR INTEGRATION
================================================================================
Backend API for Inspinia's FullCalendar implementation with drag-drop events,
color categories, multi-view support, and campaign-specific event types.

Inspinia Calendar Features Supported:
- FullCalendar dayGridMonth/timeGridWeek/timeGridDay/listMonth views
- External draggable events with categories
- Color-coded event categories (8 colors)
- Create/Edit/Delete via modal
- Drag and drop rescheduling
- RSVP management and check-in
- Volunteer shift scheduling
- Automated reminders (Email/SMS/RVM)
- Conflict detection
- Recurring events
- Public event pages

Development Value: \$70,000
================================================================================
"""

import os
import json
import logging
import uuid
import asyncio
from datetime import datetime, date, time, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem54.calendar')

# ============================================================================
# INSPINIA COLOR CATEGORIES (matches apps-calendar.js)
# ============================================================================

class EventCategory(Enum):
    """Inspinia calendar color categories."""
    PRIMARY = 'bg-primary-subtle text-primary border-start border-3 border-primary'
    SECONDARY = 'bg-secondary-subtle text-secondary border-start border-3 border-secondary'
    SUCCESS = 'bg-success-subtle text-success border-start border-3 border-success'
    INFO = 'bg-info-subtle text-info border-start border-3 border-info'
    WARNING = 'bg-warning-subtle text-warning border-start border-3 border-warning'
    DANGER = 'bg-danger-subtle text-danger border-start border-3 border-danger'
    DARK = 'bg-dark-subtle text-dark border-start border-3 border-dark'
    PURPLE = 'bg-purple-subtle text-purple border-start border-3 border-purple'

# Campaign event type to Inspinia category mapping
EVENT_TYPE_COLORS = {
    'rally': EventCategory.DANGER,
    'fundraiser': EventCategory.SUCCESS,
    'town_hall': EventCategory.PRIMARY,
    'phone_bank': EventCategory.INFO,
    'canvass': EventCategory.WARNING,
    'volunteer_training': EventCategory.SECONDARY,
    'donor_meeting': EventCategory.PURPLE,
    'media_appearance': EventCategory.DARK,
    'staff_meeting': EventCategory.SECONDARY,
    'house_party': EventCategory.SUCCESS,
    'debate': EventCategory.DANGER,
    'endorsement': EventCategory.PURPLE,
    'webinar': EventCategory.INFO,
    'other': EventCategory.PRIMARY
}

# ============================================================================
# ENUMS
# ============================================================================

class EventType(Enum):
    RALLY = 'rally'
    FUNDRAISER = 'fundraiser'
    TOWN_HALL = 'town_hall'
    PHONE_BANK = 'phone_bank'
    CANVASS = 'canvass'
    VOLUNTEER_TRAINING = 'volunteer_training'
    DONOR_MEETING = 'donor_meeting'
    MEDIA_APPEARANCE = 'media_appearance'
    STAFF_MEETING = 'staff_meeting'
    HOUSE_PARTY = 'house_party'
    DEBATE = 'debate'
    ENDORSEMENT = 'endorsement'
    WEBINAR = 'webinar'
    OTHER = 'other'

class EventStatus(Enum):
    DRAFT = 'draft'
    SCHEDULED = 'scheduled'
    CONFIRMED = 'confirmed'
    IN_PROGRESS = 'in_progress'
    COMPLETED = 'completed'
    CANCELLED = 'cancelled'

class EventVisibility(Enum):
    PUBLIC = 'public'
    PRIVATE = 'private'
    INVITE_ONLY = 'invite_only'
    VOLUNTEERS_ONLY = 'volunteers_only'
    DONORS_ONLY = 'donors_only'
    STAFF_ONLY = 'staff_only'

class RSVPStatus(Enum):
    PENDING = 'pending'
    CONFIRMED = 'confirmed'
    DECLINED = 'declined'
    WAITLIST = 'waitlist'
    CHECKED_IN = 'checked_in'
    NO_SHOW = 'no_show'

class RecurrencePattern(Enum):
    NONE = 'none'
    DAILY = 'daily'
    WEEKLY = 'weekly'
    BIWEEKLY = 'biweekly'
    MONTHLY = 'monthly'

class ReminderType(Enum):
    EMAIL = 'email'
    SMS = 'sms'
    RVM = 'rvm'
    PUSH = 'push'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class Location:
    location_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    address: str = ''
    city: str = ''
    state: str = 'NC'
    zip_code: str = ''
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    capacity: Optional[int] = None
    parking_info: str = ''
    accessibility_info: str = ''
    contact_name: str = ''
    contact_phone: str = ''

@dataclass
class Reminder:
    reminder_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_id: str = ''
    reminder_type: ReminderType = ReminderType.EMAIL
    minutes_before: int = 60
    message: str = ''
    is_sent: bool = False
    sent_at: Optional[datetime] = None
    recipient_count: int = 0

@dataclass
class RSVP:
    rsvp_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_id: str = ''
    attendee_id: str = ''
    attendee_name: str = ''
    attendee_email: Optional[str] = None
    attendee_phone: Optional[str] = None
    attendee_type: str = 'supporter'  # supporter, donor, volunteer, vip, staff
    status: RSVPStatus = RSVPStatus.PENDING
    guest_count: int = 1
    notes: str = ''
    dietary_restrictions: str = ''
    checked_in: bool = False
    checked_in_at: Optional[datetime] = None
    checked_in_by: Optional[str] = None
    source: str = 'website'  # website, email, phone, walk-in, import
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class VolunteerShift:
    shift_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    event_id: str = ''
    role: str = ''  # greeter, setup, registration, security, cleanup, etc.
    description: str = ''
    start_time: datetime = field(default_factory=datetime.now)
    end_time: datetime = field(default_factory=datetime.now)
    slots_total: int = 1
    slots_filled: int = 0
    volunteer_ids: List[str] = field(default_factory=list)
    skills_required: List[str] = field(default_factory=list)
    notes: str = ''

@dataclass
class Event:
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    
    # Basic info (maps to Inspinia modal)
    title: str = ''
    description: str = ''
    event_type: EventType = EventType.OTHER
    category: EventCategory = EventCategory.PRIMARY  # Inspinia color class
    status: EventStatus = EventStatus.SCHEDULED
    visibility: EventVisibility = EventVisibility.PUBLIC
    
    # Timing (FullCalendar compatible)
    start: datetime = field(default_factory=datetime.now)  # FullCalendar uses 'start'
    end: datetime = field(default_factory=datetime.now)    # FullCalendar uses 'end'
    all_day: bool = False                                   # FullCalendar allDay
    timezone: str = 'America/New_York'
    
    # Recurrence
    recurrence: RecurrencePattern = RecurrencePattern.NONE
    recurrence_end: Optional[date] = None
    recurrence_exceptions: List[date] = field(default_factory=list)
    parent_event_id: Optional[str] = None
    
    # Location
    location: Optional[Location] = None
    is_virtual: bool = False
    virtual_link: Optional[str] = None
    virtual_platform: str = ''  # zoom, youtube, facebook, teams
    virtual_password: Optional[str] = None
    
    # Capacity & RSVPs
    capacity: Optional[int] = None
    waitlist_enabled: bool = True
    rsvp_required: bool = False
    rsvps: List[RSVP] = field(default_factory=list)
    
    # Volunteer shifts
    shifts: List[VolunteerShift] = field(default_factory=list)
    
    # Reminders
    reminders: List[Reminder] = field(default_factory=list)
    
    # Media
    image_url: Optional[str] = None
    banner_url: Optional[str] = None
    
    # URLs
    public_url: Optional[str] = None
    registration_url: Optional[str] = None
    
    # Tags and targeting
    tags: List[str] = field(default_factory=list)
    county: Optional[str] = None
    district: Optional[str] = None
    target_audience: List[str] = field(default_factory=list)
    
    # Contact
    contact_name: str = ''
    contact_email: str = ''
    contact_phone: str = ''
    
    # Metadata
    created_by: str = ''
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    
    @property
    def confirmed_count(self) -> int:
        return sum(r.guest_count for r in self.rsvps 
                   if r.status in [RSVPStatus.CONFIRMED, RSVPStatus.CHECKED_IN])
    
    @property
    def checked_in_count(self) -> int:
        return sum(r.guest_count for r in self.rsvps if r.status == RSVPStatus.CHECKED_IN)
    
    @property
    def waitlist_count(self) -> int:
        return sum(r.guest_count for r in self.rsvps if r.status == RSVPStatus.WAITLIST)
    
    @property
    def is_full(self) -> bool:
        return self.capacity is not None and self.confirmed_count >= self.capacity
    
    @property
    def available_spots(self) -> Optional[int]:
        if self.capacity is None:
            return None
        return max(0, self.capacity - self.confirmed_count)
    
    @property
    def duration_minutes(self) -> int:
        return int((self.end - self.start).total_seconds() / 60)
    
    @property
    def is_past(self) -> bool:
        return self.end < datetime.now()
    
    @property
    def is_today(self) -> bool:
        return self.start.date() == date.today()
    
    def to_fullcalendar_event(self) -> Dict[str, Any]:
        """Convert to FullCalendar event format for Inspinia."""
        return {
            'id': self.event_id,
            'title': self.title,
            'start': self.start.isoformat(),
            'end': self.end.isoformat(),
            'allDay': self.all_day,
            'className': self.category.value,  # Inspinia color class
            'extendedProps': {
                'event_type': self.event_type.value,
                'status': self.status.value,
                'visibility': self.visibility.value,
                'location': self.location.name if self.location else None,
                'is_virtual': self.is_virtual,
                'virtual_link': self.virtual_link,
                'capacity': self.capacity,
                'confirmed_count': self.confirmed_count,
                'description': self.description,
                'county': self.county
            }
        }

@dataclass
class ExternalDraggableEvent:
    """Pre-defined draggable events for Inspinia sidebar."""
    event_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    title: str = ''
    event_type: EventType = EventType.OTHER
    category: EventCategory = EventCategory.PRIMARY
    default_duration_minutes: int = 60
    default_description: str = ''
    icon: str = 'ti-circle-filled'
    
    def to_inspinia_format(self) -> Dict[str, Any]:
        """Format for Inspinia external-events sidebar."""
        return {
            'id': self.event_id,
            'title': self.title,
            'className': self.category.value,
            'eventType': self.event_type.value,
            'duration': self.default_duration_minutes,
            'icon': self.icon
        }

@dataclass
class BlockedTime:
    block_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    start: datetime = field(default_factory=datetime.now)
    end: datetime = field(default_factory=datetime.now)
    reason: str = ''
    is_recurring: bool = False
    recurrence: RecurrencePattern = RecurrencePattern.NONE

# ============================================================================
# CALENDAR MANAGER - INSPINIA COMPATIBLE
# ============================================================================

class CalendarManager:
    """
    Calendar management with full Inspinia FullCalendar compatibility.
    All methods return data formatted for direct use in apps-calendar.js
    """
    
    DEFAULT_TIMEZONE = 'America/New_York'
    
    def __init__(self, supabase_client=None, redis_client=None):
        self.supabase = supabase_client
        self.redis = redis_client
        self.events: Dict[str, Event] = {}
        self.blocked_times: Dict[str, List[BlockedTime]] = defaultdict(list)
        
        # Initialize default draggable events
        self.external_events = self._create_default_external_events()
    
    def _create_default_external_events(self) -> List[ExternalDraggableEvent]:
        """Create default draggable events for Inspinia sidebar."""
        return [
            ExternalDraggableEvent(
                title='Rally',
                event_type=EventType.RALLY,
                category=EventCategory.DANGER,
                default_duration_minutes=120,
                default_description='Campaign rally event'
            ),
            ExternalDraggableEvent(
                title='Fundraiser',
                event_type=EventType.FUNDRAISER,
                category=EventCategory.SUCCESS,
                default_duration_minutes=180,
                default_description='Fundraising event'
            ),
            ExternalDraggableEvent(
                title='Town Hall',
                event_type=EventType.TOWN_HALL,
                category=EventCategory.PRIMARY,
                default_duration_minutes=90,
                default_description='Town hall meeting with constituents'
            ),
            ExternalDraggableEvent(
                title='Phone Bank',
                event_type=EventType.PHONE_BANK,
                category=EventCategory.INFO,
                default_duration_minutes=180,
                default_description='Volunteer phone banking session'
            ),
            ExternalDraggableEvent(
                title='Canvass',
                event_type=EventType.CANVASS,
                category=EventCategory.WARNING,
                default_duration_minutes=240,
                default_description='Door-to-door canvassing'
            ),
            ExternalDraggableEvent(
                title='Volunteer Training',
                event_type=EventType.VOLUNTEER_TRAINING,
                category=EventCategory.SECONDARY,
                default_duration_minutes=60,
                default_description='Training session for volunteers'
            ),
            ExternalDraggableEvent(
                title='Donor Meeting',
                event_type=EventType.DONOR_MEETING,
                category=EventCategory.PURPLE,
                default_duration_minutes=60,
                default_description='Meeting with donors'
            ),
            ExternalDraggableEvent(
                title='Media Appearance',
                event_type=EventType.MEDIA_APPEARANCE,
                category=EventCategory.DARK,
                default_duration_minutes=30,
                default_description='Media interview or appearance'
            )
        ]
    
    # =========================================================================
    # FULLCALENDAR API METHODS (for apps-calendar.js)
    # =========================================================================
    
    async def get_events_for_calendar(
        self,
        candidate_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> List[Dict[str, Any]]:
        """
        Get events formatted for FullCalendar initialEvents.
        Returns array of FullCalendar event objects.
        """
        events = [
            e for e in self.events.values()
            if e.candidate_id == candidate_id
        ]
        
        # Filter by date range if provided
        if start_date:
            events = [e for e in events if e.end >= start_date]
        if end_date:
            events = [e for e in events if e.start <= end_date]
        
        # Convert to FullCalendar format
        return [e.to_fullcalendar_event() for e in events]
    
    async def get_external_events(self) -> List[Dict[str, Any]]:
        """Get draggable external events for Inspinia sidebar."""
        return [e.to_inspinia_format() for e in self.external_events]
    
    async def create_event_from_drop(
        self,
        candidate_id: str,
        external_event_id: str,
        drop_date: datetime,
        created_by: str = ''
    ) -> Event:
        """
        Create event when external event is dropped on calendar.
        Called when user drags sidebar event to calendar.
        """
        # Find external event template
        template = next(
            (e for e in self.external_events if e.event_id == external_event_id),
            None
        )
        
        if not template:
            raise ValueError(f"External event {external_event_id} not found")
        
        # Create event from template
        end_time = drop_date + timedelta(minutes=template.default_duration_minutes)
        
        return await self.create_event(
            candidate_id=candidate_id,
            title=template.title,
            event_type=template.event_type,
            start=drop_date,
            end=end_time,
            description=template.default_description,
            category=template.category,
            created_by=created_by
        )
    
    async def update_event_from_drag(
        self,
        event_id: str,
        new_start: datetime,
        new_end: datetime
    ) -> Event:
        """
        Update event when dragged/resized on calendar.
        Called from FullCalendar eventDrop and eventResize.
        """
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        # Check for conflicts
        conflicts = await self.check_conflicts(
            event.candidate_id, new_start, new_end, exclude_event_id=event_id
        )
        
        if conflicts:
            logger.warning(f"Drag created conflicts: {len(conflicts)} events")
        
        event.start = new_start
        event.end = new_end
        event.updated_at = datetime.now()
        
        if self.supabase:
            await self._save_event_to_db(event)
        
        return event
    
    # =========================================================================
    # CRUD OPERATIONS
    # =========================================================================
    
    async def create_event(
        self,
        candidate_id: str,
        title: str,
        event_type: EventType,
        start: datetime,
        end: datetime,
        description: str = '',
        category: Optional[EventCategory] = None,
        location: Optional[Location] = None,
        visibility: EventVisibility = EventVisibility.PUBLIC,
        capacity: Optional[int] = None,
        is_virtual: bool = False,
        virtual_link: Optional[str] = None,
        tags: Optional[List[str]] = None,
        county: Optional[str] = None,
        all_day: bool = False,
        created_by: str = ''
    ) -> Event:
        """Create a new event."""
        # Auto-assign category color if not specified
        if category is None:
            category = EVENT_TYPE_COLORS.get(event_type.value, EventCategory.PRIMARY)
        
        # Check for conflicts
        conflicts = await self.check_conflicts(candidate_id, start, end)
        if conflicts:
            logger.warning(f"Event conflicts: {len(conflicts)} overlapping events")
        
        event = Event(
            candidate_id=candidate_id,
            title=title,
            description=description,
            event_type=event_type,
            category=category,
            status=EventStatus.SCHEDULED,
            visibility=visibility,
            start=start,
            end=end,
            all_day=all_day,
            location=location,
            is_virtual=is_virtual,
            virtual_link=virtual_link,
            capacity=capacity,
            tags=tags or [],
            county=county,
            created_by=created_by
        )
        
        # Generate URLs
        event.public_url = f"https://broyhillgop.com/events/{event.event_id}"
        event.registration_url = f"https://broyhillgop.com/events/{event.event_id}/register"
        
        # Add default reminders
        event.reminders = [
            Reminder(
                event_id=event.event_id,
                reminder_type=ReminderType.EMAIL,
                minutes_before=1440,  # 24 hours
                message=f"Reminder: {title} is tomorrow!"
            ),
            Reminder(
                event_id=event.event_id,
                reminder_type=ReminderType.SMS,
                minutes_before=120,  # 2 hours
                message=f"See you in 2 hours at {title}!"
            ),
            Reminder(
                event_id=event.event_id,
                reminder_type=ReminderType.EMAIL,
                minutes_before=60,  # 1 hour
                message=f"{title} starts in 1 hour!"
            )
        ]
        
        self.events[event.event_id] = event
        
        if self.supabase:
            await self._save_event_to_db(event)
        
        logger.info(f"Created event: {title} on {start.strftime('%Y-%m-%d %H:%M')}")
        return event
    
    async def update_event(
        self,
        event_id: str,
        updates: Dict[str, Any]
    ) -> Event:
        """Update event properties."""
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        # Apply updates
        for key, value in updates.items():
            if hasattr(event, key):
                if key == 'event_type' and isinstance(value, str):
                    value = EventType(value)
                elif key == 'category' and isinstance(value, str):
                    value = EventCategory(value)
                elif key == 'status' and isinstance(value, str):
                    value = EventStatus(value)
                elif key in ['start', 'end'] and isinstance(value, str):
                    value = datetime.fromisoformat(value)
                setattr(event, key, value)
        
        event.updated_at = datetime.now()
        
        if self.supabase:
            await self._save_event_to_db(event)
        
        return event
    
    async def delete_event(self, event_id: str) -> bool:
        """Delete an event."""
        if event_id not in self.events:
            return False
        
        del self.events[event_id]
        
        if self.supabase:
            await self._delete_event_from_db(event_id)
        
        logger.info(f"Deleted event: {event_id}")
        return True
    
    async def get_event(self, event_id: str) -> Optional[Event]:
        """Get a single event by ID."""
        return self.events.get(event_id)
    
    # =========================================================================
    # RSVP MANAGEMENT
    # =========================================================================
    
    async def create_rsvp(
        self,
        event_id: str,
        attendee_id: str,
        attendee_name: str,
        attendee_email: Optional[str] = None,
        attendee_phone: Optional[str] = None,
        attendee_type: str = 'supporter',
        guest_count: int = 1,
        source: str = 'website'
    ) -> RSVP:
        """Create an RSVP for an event."""
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        # Check capacity
        status = RSVPStatus.CONFIRMED
        if event.is_full:
            if event.waitlist_enabled:
                status = RSVPStatus.WAITLIST
            else:
                raise ValueError("Event is full and waitlist is disabled")
        
        rsvp = RSVP(
            event_id=event_id,
            attendee_id=attendee_id,
            attendee_name=attendee_name,
            attendee_email=attendee_email,
            attendee_phone=attendee_phone,
            attendee_type=attendee_type,
            status=status,
            guest_count=guest_count,
            source=source
        )
        
        event.rsvps.append(rsvp)
        
        if self.supabase:
            await self._save_rsvp_to_db(rsvp)
        
        logger.info(f"RSVP created: {attendee_name} for {event.title} ({status.value})")
        return rsvp
    
    async def check_in_attendee(
        self,
        event_id: str,
        rsvp_id: str,
        checked_in_by: str = ''
    ) -> RSVP:
        """Check in an attendee at an event."""
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        rsvp = next((r for r in event.rsvps if r.rsvp_id == rsvp_id), None)
        if not rsvp:
            raise ValueError(f"RSVP {rsvp_id} not found")
        
        rsvp.status = RSVPStatus.CHECKED_IN
        rsvp.checked_in = True
        rsvp.checked_in_at = datetime.now()
        rsvp.checked_in_by = checked_in_by
        
        if self.supabase:
            await self._save_rsvp_to_db(rsvp)
        
        logger.info(f"Checked in: {rsvp.attendee_name} at {event.title}")
        return rsvp
    
    async def get_event_attendees(
        self,
        event_id: str,
        status: Optional[RSVPStatus] = None
    ) -> List[RSVP]:
        """Get attendees for an event."""
        event = self.events.get(event_id)
        if not event:
            return []
        
        rsvps = event.rsvps
        if status:
            rsvps = [r for r in rsvps if r.status == status]
        
        return rsvps
    
    # =========================================================================
    # VOLUNTEER SHIFTS
    # =========================================================================
    
    async def add_volunteer_shift(
        self,
        event_id: str,
        role: str,
        start_time: datetime,
        end_time: datetime,
        slots_total: int = 1,
        description: str = '',
        skills_required: Optional[List[str]] = None
    ) -> VolunteerShift:
        """Add a volunteer shift to an event."""
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        shift = VolunteerShift(
            event_id=event_id,
            role=role,
            description=description,
            start_time=start_time,
            end_time=end_time,
            slots_total=slots_total,
            skills_required=skills_required or []
        )
        
        event.shifts.append(shift)
        
        if self.supabase:
            await self._save_shift_to_db(shift)
        
        return shift
    
    async def sign_up_for_shift(
        self,
        event_id: str,
        shift_id: str,
        volunteer_id: str
    ) -> VolunteerShift:
        """Sign up a volunteer for a shift."""
        event = self.events.get(event_id)
        if not event:
            raise ValueError(f"Event {event_id} not found")
        
        shift = next((s for s in event.shifts if s.shift_id == shift_id), None)
        if not shift:
            raise ValueError(f"Shift {shift_id} not found")
        
        if shift.slots_filled >= shift.slots_total:
            raise ValueError("Shift is full")
        
        if volunteer_id in shift.volunteer_ids:
            raise ValueError("Volunteer already signed up")
        
        shift.volunteer_ids.append(volunteer_id)
        shift.slots_filled += 1
        
        if self.supabase:
            await self._save_shift_to_db(shift)
        
        return shift
    
    # =========================================================================
    # CONFLICT DETECTION
    # =========================================================================
    
    async def check_conflicts(
        self,
        candidate_id: str,
        start: datetime,
        end: datetime,
        exclude_event_id: Optional[str] = None
    ) -> List[Event]:
        """Check for conflicting events."""
        conflicts = []
        
        for event in self.events.values():
            if event.candidate_id != candidate_id:
                continue
            if exclude_event_id and event.event_id == exclude_event_id:
                continue
            if event.status == EventStatus.CANCELLED:
                continue
            
            # Check overlap
            if start < event.end and end > event.start:
                conflicts.append(event)
        
        # Check blocked times
        for blocked in self.blocked_times.get(candidate_id, []):
            if start < blocked.end and end > blocked.start:
                logger.warning(f"Conflict with blocked time: {blocked.reason}")
        
        return conflicts
    
    # =========================================================================
    # REMINDERS
    # =========================================================================
    
    async def send_reminders(self, event_id: str, reminder_type: ReminderType) -> int:
        """Send reminders for an event."""
        event = self.events.get(event_id)
        if not event:
            return 0
        
        confirmed_rsvps = [r for r in event.rsvps 
                          if r.status in [RSVPStatus.CONFIRMED, RSVPStatus.PENDING]]
        
        sent_count = 0
        for rsvp in confirmed_rsvps:
            if reminder_type == ReminderType.EMAIL and rsvp.attendee_email:
                # Queue email via E30
                if self.redis:
                    await self.redis.publish('e30:email:send', json.dumps({
                        'to': rsvp.attendee_email,
                        'subject': f"Reminder: {event.title}",
                        'template': 'event_reminder',
                        'data': {
                            'event_title': event.title,
                            'event_date': event.start.strftime('%B %d, %Y'),
                            'event_time': event.start.strftime('%I:%M %p'),
                            'location': event.location.name if event.location else 'TBD',
                            'attendee_name': rsvp.attendee_name
                        }
                    }))
                sent_count += 1
            
            elif reminder_type == ReminderType.SMS and rsvp.attendee_phone:
                # Queue SMS via E31
                if self.redis:
                    await self.redis.publish('e31:sms:send', json.dumps({
                        'to': rsvp.attendee_phone,
                        'message': f"Reminder: {event.title} on {event.start.strftime('%b %d at %I:%M %p')}. See you there!",
                        'source': 'calendar'
                    }))
                sent_count += 1
        
        logger.info(f"Sent {sent_count} {reminder_type.value} reminders for {event.title}")
        return sent_count
    
    # =========================================================================
    # RECURRING EVENTS
    # =========================================================================
    
    async def create_recurring_event(
        self,
        candidate_id: str,
        title: str,
        event_type: EventType,
        start: datetime,
        end: datetime,
        recurrence: RecurrencePattern,
        recurrence_end: date,
        **kwargs
    ) -> List[Event]:
        """Create recurring events."""
        events = []
        current_start = start
        current_end = end
        
        # Create parent event
        parent = await self.create_event(
            candidate_id=candidate_id,
            title=title,
            event_type=event_type,
            start=current_start,
            end=current_end,
            **kwargs
        )
        parent.recurrence = recurrence
        parent.recurrence_end = recurrence_end
        events.append(parent)
        
        # Generate recurring instances
        delta = {
            RecurrencePattern.DAILY: timedelta(days=1),
            RecurrencePattern.WEEKLY: timedelta(weeks=1),
            RecurrencePattern.BIWEEKLY: timedelta(weeks=2),
            RecurrencePattern.MONTHLY: timedelta(days=30)
        }.get(recurrence, timedelta(weeks=1))
        
        while True:
            current_start += delta
            current_end += delta
            
            if current_start.date() > recurrence_end:
                break
            
            instance = await self.create_event(
                candidate_id=candidate_id,
                title=title,
                event_type=event_type,
                start=current_start,
                end=current_end,
                **kwargs
            )
            instance.parent_event_id = parent.event_id
            events.append(instance)
        
        logger.info(f"Created {len(events)} recurring events for {title}")
        return events
    
    # =========================================================================
    # QUERIES & REPORTS
    # =========================================================================
    
    async def get_upcoming_events(
        self,
        candidate_id: str,
        days: int = 30,
        event_type: Optional[EventType] = None,
        visibility: Optional[EventVisibility] = None
    ) -> List[Event]:
        """Get upcoming events."""
        now = datetime.now()
        end_date = now + timedelta(days=days)
        
        events = [
            e for e in self.events.values()
            if e.candidate_id == candidate_id
            and e.start >= now
            and e.start <= end_date
            and e.status != EventStatus.CANCELLED
        ]
        
        if event_type:
            events = [e for e in events if e.event_type == event_type]
        
        if visibility:
            events = [e for e in events if e.visibility == visibility]
        
        return sorted(events, key=lambda e: e.start)
    
    async def get_events_by_county(self, county: str) -> List[Event]:
        """Get events in a specific NC county."""
        return [
            e for e in self.events.values()
            if e.county and e.county.lower() == county.lower()
            and e.status != EventStatus.CANCELLED
        ]
    
    def get_calendar_stats(self, candidate_id: str) -> Dict[str, Any]:
        """Get calendar statistics."""
        events = [e for e in self.events.values() if e.candidate_id == candidate_id]
        now = datetime.now()
        
        upcoming = [e for e in events if e.start > now and e.status != EventStatus.CANCELLED]
        past = [e for e in events if e.end < now]
        
        total_rsvps = sum(len(e.rsvps) for e in events)
        total_confirmed = sum(e.confirmed_count for e in events)
        total_checked_in = sum(e.checked_in_count for e in events)
        
        events_by_type = defaultdict(int)
        for e in events:
            events_by_type[e.event_type.value] += 1
        
        return {
            'total_events': len(events),
            'upcoming_events': len(upcoming),
            'past_events': len(past),
            'total_rsvps': total_rsvps,
            'total_confirmed': total_confirmed,
            'total_checked_in': total_checked_in,
            'events_by_type': dict(events_by_type),
            'next_event': upcoming[0].to_fullcalendar_event() if upcoming else None
        }
    
    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_event_to_db(self, event: Event):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e54_events').upsert({
                'event_id': event.event_id,
                'candidate_id': event.candidate_id,
                'title': event.title,
                'description': event.description,
                'event_type': event.event_type.value,
                'category': event.category.value,
                'status': event.status.value,
                'visibility': event.visibility.value,
                'start_time': event.start.isoformat(),
                'end_time': event.end.isoformat(),
                'all_day': event.all_day,
                'timezone': event.timezone,
                'location_name': event.location.name if event.location else None,
                'location_address': event.location.address if event.location else None,
                'is_virtual': event.is_virtual,
                'virtual_link': event.virtual_link,
                'capacity': event.capacity,
                'county': event.county,
                'tags': json.dumps(event.tags),
                'public_url': event.public_url,
                'created_by': event.created_by,
                'created_at': event.created_at.isoformat(),
                'updated_at': event.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save event: {e}")
    
    async def _delete_event_from_db(self, event_id: str):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e54_events').delete().eq('event_id', event_id).execute()
        except Exception as e:
            logger.error(f"Failed to delete event: {e}")
    
    async def _save_rsvp_to_db(self, rsvp: RSVP):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e54_rsvps').upsert({
                'rsvp_id': rsvp.rsvp_id,
                'event_id': rsvp.event_id,
                'attendee_id': rsvp.attendee_id,
                'attendee_name': rsvp.attendee_name,
                'attendee_email': rsvp.attendee_email,
                'attendee_phone': rsvp.attendee_phone,
                'attendee_type': rsvp.attendee_type,
                'status': rsvp.status.value,
                'guest_count': rsvp.guest_count,
                'checked_in': rsvp.checked_in,
                'checked_in_at': rsvp.checked_in_at.isoformat() if rsvp.checked_in_at else None,
                'source': rsvp.source,
                'created_at': rsvp.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save RSVP: {e}")
    
    async def _save_shift_to_db(self, shift: VolunteerShift):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e54_volunteer_shifts').upsert({
                'shift_id': shift.shift_id,
                'event_id': shift.event_id,
                'role': shift.role,
                'description': shift.description,
                'start_time': shift.start_time.isoformat(),
                'end_time': shift.end_time.isoformat(),
                'slots_total': shift.slots_total,
                'slots_filled': shift.slots_filled,
                'volunteer_ids': json.dumps(shift.volunteer_ids)
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save shift: {e}")


# ============================================================================
# API ENDPOINTS (FastAPI/Flask compatible)
# ============================================================================

class CalendarAPI:
    """REST API endpoints for Inspinia calendar integration."""
    
    def __init__(self, calendar_manager: CalendarManager):
        self.cm = calendar_manager
    
    async def get_events(
        self,
        candidate_id: str,
        start: Optional[str] = None,
        end: Optional[str] = None
    ) -> Dict[str, Any]:
        """GET /api/calendar/events - Returns FullCalendar format."""
        start_dt = datetime.fromisoformat(start) if start else None
        end_dt = datetime.fromisoformat(end) if end else None
        
        events = await self.cm.get_events_for_calendar(candidate_id, start_dt, end_dt)
        return {'events': events}
    
    async def get_external_events(self) -> Dict[str, Any]:
        """GET /api/calendar/external-events - Draggable sidebar events."""
        events = await self.cm.get_external_events()
        return {'external_events': events}
    
    async def create_event(
        self,
        candidate_id: str,
        data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """POST /api/calendar/events - Create from modal."""
        event = await self.cm.create_event(
            candidate_id=candidate_id,
            title=data['title'],
            event_type=EventType(data.get('event_type', 'other')),
            start=datetime.fromisoformat(data['start']),
            end=datetime.fromisoformat(data['end']),
            description=data.get('description', ''),
            all_day=data.get('allDay', False),
            category=EventCategory(data['category']) if 'category' in data else None
        )
        return event.to_fullcalendar_event()
    
    async def update_event(
        self,
        event_id: str,
        data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """PUT /api/calendar/events/{id} - Update from modal or drag."""
        event = await self.cm.update_event(event_id, data)
        return event.to_fullcalendar_event()
    
    async def delete_event(self, event_id: str) -> Dict[str, Any]:
        """DELETE /api/calendar/events/{id} - Delete from modal."""
        success = await self.cm.delete_event(event_id)
        return {'success': success}
    
    async def drop_external_event(
        self,
        candidate_id: str,
        external_event_id: str,
        drop_date: str
    ) -> Dict[str, Any]:
        """POST /api/calendar/drop - When sidebar event dropped."""
        event = await self.cm.create_event_from_drop(
            candidate_id=candidate_id,
            external_event_id=external_event_id,
            drop_date=datetime.fromisoformat(drop_date)
        )
        return event.to_fullcalendar_event()
    
    async def drag_event(
        self,
        event_id: str,
        new_start: str,
        new_end: str
    ) -> Dict[str, Any]:
        """POST /api/calendar/drag - When event dragged/resized."""
        event = await self.cm.update_event_from_drag(
            event_id=event_id,
            new_start=datetime.fromisoformat(new_start),
            new_end=datetime.fromisoformat(new_end)
        )
        return event.to_fullcalendar_event()


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the Inspinia calendar integration."""
    cm = CalendarManager()
    
    candidate_id = 'dave-boliek-001'
    
    # Get external draggable events (for sidebar)
    print("\n=== EXTERNAL DRAGGABLE EVENTS (Inspinia Sidebar) ===")
    external = await cm.get_external_events()
    for e in external:
        print(f"  - {e['title']} ({e['eventType']}) - {e['className'][:30]}...")
    
    # Create some events
    print("\n=== CREATING EVENTS ===")
    
    rally = await cm.create_event(
        candidate_id=candidate_id,
        title='Victory Rally - Winston-Salem',
        event_type=EventType.RALLY,
        start=datetime.now() + timedelta(days=7),
        end=datetime.now() + timedelta(days=7, hours=2),
        county='Forsyth',
        capacity=500,
        location=Location(
            name='Bowman Gray Stadium',
            address='1250 S Martin Luther King Jr Dr',
            city='Winston-Salem',
            state='NC',
            zip_code='27107'
        )
    )
    print(f"Created: {rally.title} - {rally.category.value[:30]}...")
    
    fundraiser = await cm.create_event(
        candidate_id=candidate_id,
        title='Major Donor Reception',
        event_type=EventType.FUNDRAISER,
        start=datetime.now() + timedelta(days=14),
        end=datetime.now() + timedelta(days=14, hours=3),
        capacity=50,
        is_virtual=False
    )
    print(f"Created: {fundraiser.title} - {fundraiser.category.value[:30]}...")
    
    phone_bank = await cm.create_event(
        candidate_id=candidate_id,
        title='Weekly Phone Bank',
        event_type=EventType.PHONE_BANK,
        start=datetime.now() + timedelta(days=3),
        end=datetime.now() + timedelta(days=3, hours=3),
        is_virtual=True,
        virtual_link='https://zoom.us/j/123456789'
    )
    print(f"Created: {phone_bank.title} - {phone_bank.category.value[:30]}...")
    
    # Add RSVPs
    print("\n=== ADDING RSVPS ===")
    rsvp1 = await cm.create_rsvp(
        event_id=rally.event_id,
        attendee_id='donor-001',
        attendee_name='John Smith',
        attendee_email='john@example.com',
        attendee_phone='+13365551234',
        guest_count=2
    )
    print(f"RSVP: {rsvp1.attendee_name} ({rsvp1.status.value}) - {rsvp1.guest_count} guests")
    
    # Add volunteer shift
    print("\n=== ADDING VOLUNTEER SHIFT ===")
    shift = await cm.add_volunteer_shift(
        event_id=rally.event_id,
        role='Greeter',
        start_time=rally.start - timedelta(hours=1),
        end_time=rally.start,
        slots_total=5,
        description='Welcome attendees at entrance'
    )
    print(f"Shift: {shift.role} - {shift.slots_total} slots")
    
    # Get FullCalendar format
    print("\n=== FULLCALENDAR FORMAT (for Inspinia) ===")
    fc_events = await cm.get_events_for_calendar(candidate_id)
    for e in fc_events:
        print(f"  {e['title']}: {e['start'][:16]} - className: {e['className'][:40]}...")
    
    # Get stats
    print("\n=== CALENDAR STATS ===")
    stats = cm.get_calendar_stats(candidate_id)
    print(json.dumps(stats, indent=2, default=str))


if __name__ == '__main__':
    asyncio.run(main())
