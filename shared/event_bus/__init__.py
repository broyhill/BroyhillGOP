"""
shared/event_bus

Redis pub/sub client for the BroyhillGOP event bus.

Canonical channel: broyhillgop.events
Canonical event format (JSON):
    {
        'event_id': 'uuid-v4',
        'event_type': 'social.oauth.completed',
        'ecosystem': 'E19_TECH_PROVIDER',
        'candidate_id': 'uuid-or-null',
        'timestamp': 'iso-8601-utc',
        ...payload fields...
    }

Pattern matches ecosystem_20_intelligence_brain.py production code.
"""

from .publisher import (
    EventPublisher,
    NullEventPublisher,
    PublishResult,
    PublishFailure,
    canonical_event,
)
from .consumer import (
    EventConsumer,
    EventHandler,
)

__all__ = [
    "EventPublisher",
    "NullEventPublisher",
    "EventConsumer",
    "EventHandler",
    "PublishResult",
    "PublishFailure",
    "canonical_event",
]
