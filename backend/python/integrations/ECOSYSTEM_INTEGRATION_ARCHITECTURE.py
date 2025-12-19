#!/usr/bin/env python3
"""
================================================================================
BROYHILLGOP ECOSYSTEM INTEGRATION ARCHITECTURE
================================================================================

MASTER ORCHESTRATION LAYER
--------------------------
This module ensures all 44 ecosystems work together seamlessly through:

1. EVENT BUS - Centralized pub/sub for cross-ecosystem communication
2. DATA CONTRACTS - Standardized data formats between systems
3. TRIGGER ROUTING - Intelligent routing of automation triggers
4. ML PIPELINE - Coordinated machine learning and predictions
5. CACHE LAYER - Shared caching for performance
6. HEALTH MONITORING - Cross-ecosystem health checks
7. ERROR HANDLING - Graceful degradation and recovery

================================================================================
"""

import os
import json
import logging
import threading
import redis
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Callable, Any
from enum import Enum
from dataclasses import dataclass, field
from queue import Queue, PriorityQueue
import hashlib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('integration.architecture')


# ==============================================================================
# CONFIGURATION
# ==============================================================================

class IntegrationConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost:5432/broyhillgop")
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
    
    # Performance settings
    EVENT_QUEUE_SIZE = 10000
    CACHE_TTL_SECONDS = 300
    HEALTH_CHECK_INTERVAL = 30
    TRIGGER_TIMEOUT_MS = 5000
    MAX_RETRY_ATTEMPTS = 3


# ==============================================================================
# ECOSYSTEM REGISTRY - All 44 Ecosystems with Dependencies
# ==============================================================================

ECOSYSTEM_REGISTRY = {
    # CORE INFRASTRUCTURE (E0-E7)
    "E0": {
        "name": "DataHub",
        "type": "infrastructure",
        "provides": ["database", "event_bus", "health_monitoring"],
        "depends_on": [],
        "events_published": ["datahub.health", "datahub.query_slow", "datahub.connection_pool"],
        "events_subscribed": [],
        "priority": 1  # Starts first
    },
    "E1": {
        "name": "Donor Intelligence",
        "type": "core",
        "provides": ["donor_grades", "rfm_scores", "churn_prediction", "ask_optimization"],
        "depends_on": ["E0"],
        "events_published": ["donor.grade_changed", "donor.became_lapsed", "donor.upgraded", "donor.churn_risk_high"],
        "events_subscribed": ["donation.received", "contact.updated"],
        "ml_models": ["churn_predictor", "ask_optimizer", "channel_predictor"],
        "priority": 2
    },
    "E2": {
        "name": "Donation Processing",
        "type": "core",
        "provides": ["payment_processing", "refunds", "recurring_management"],
        "depends_on": ["E0", "E1", "E10"],
        "events_published": ["donation.received", "donation.first", "donation.recurring_started", "donation.failed"],
        "events_subscribed": ["contact.created"],
        "priority": 3
    },
    "E3": {
        "name": "Candidate Profiles",
        "type": "core",
        "provides": ["candidate_data", "issue_positions", "ai_context"],
        "depends_on": ["E0"],
        "events_published": ["candidate.position_changed", "candidate.endorsement_added"],
        "events_subscribed": [],
        "priority": 2
    },
    "E4": {
        "name": "Activist Network",
        "type": "core",
        "provides": ["activist_scores", "network_analysis", "show_rate_prediction"],
        "depends_on": ["E0", "E1"],
        "events_published": ["activist.score_changed", "activist.elite_identified"],
        "events_subscribed": ["volunteer.shift_completed", "event.attended"],
        "ml_models": ["show_rate_predictor"],
        "priority": 3
    },
    "E5": {
        "name": "Volunteer Management",
        "type": "core",
        "provides": ["volunteer_tracking", "shift_scheduling", "performance_grades"],
        "depends_on": ["E0", "E4"],
        "events_published": ["volunteer.shift_completed", "volunteer.no_show", "volunteer.grade_changed"],
        "events_subscribed": ["event.created"],
        "priority": 3
    },
    "E6": {
        "name": "Analytics Engine",
        "type": "core",
        "provides": ["campaign_metrics", "roi_calculation", "attribution"],
        "depends_on": ["E0"],
        "events_published": ["analytics.threshold_exceeded", "analytics.goal_reached"],
        "events_subscribed": ["*"],  # Subscribes to all events for tracking
        "priority": 2
    },
    "E7": {
        "name": "Issue Tracking",
        "type": "core",
        "provides": ["issue_positions", "concordance_scores", "donor_matching"],
        "depends_on": ["E0", "E1", "E3"],
        "events_published": ["issue.position_changed", "issue.trending"],
        "events_subscribed": ["news.issue_trending"],
        "priority": 3
    },
    
    # CONTENT & COMMUNICATIONS (E8-E15)
    "E8": {
        "name": "Communications Library",
        "type": "content",
        "provides": ["content_repository", "templates", "version_control"],
        "depends_on": ["E0"],
        "events_published": ["content.approved", "content.updated"],
        "events_subscribed": [],
        "priority": 2
    },
    "E9": {
        "name": "Content Creation AI",
        "type": "content",
        "provides": ["ai_content_generation", "variant_creation", "personalization"],
        "depends_on": ["E0", "E13"],
        "events_published": ["content.generated", "content.variants_ready"],
        "events_subscribed": ["content.requested"],
        "priority": 3
    },
    "E10": {
        "name": "Compliance Manager",
        "type": "content",
        "provides": ["fec_compliance", "disclaimers", "contribution_limits"],
        "depends_on": ["E0"],
        "events_published": ["compliance.violation", "compliance.filing_due"],
        "events_subscribed": ["donation.received", "content.created"],
        "priority": 2
    },
    "E11": {
        "name": "Budget Management",
        "type": "content",
        "provides": ["budget_tracking", "expense_approval", "forecasting"],
        "depends_on": ["E0"],
        "events_published": ["budget.threshold_exceeded", "budget.approved"],
        "events_subscribed": ["expense.recorded"],
        "priority": 3
    },
    "E11B": {
        "name": "Training LMS",
        "type": "content",
        "provides": ["training_modules", "certifications", "progress_tracking"],
        "depends_on": ["E0", "E5"],
        "events_published": ["training.completed", "certification.earned"],
        "events_subscribed": ["volunteer.approved"],
        "priority": 4
    },
    "E12": {
        "name": "Campaign Operations",
        "type": "content",
        "provides": ["task_management", "workflow_tracking", "milestones"],
        "depends_on": ["E0"],
        "events_published": ["task.completed", "milestone.reached"],
        "events_subscribed": ["campaign.launched"],
        "priority": 3
    },
    "E13": {
        "name": "AI Hub",
        "type": "content",
        "provides": ["claude_orchestration", "prompt_management", "ai_routing"],
        "depends_on": ["E0"],
        "events_published": ["ai.response_generated", "ai.error"],
        "events_subscribed": ["content.requested", "decision.needed"],
        "priority": 2
    },
    "E14": {
        "name": "Print Production",
        "type": "content",
        "provides": ["document_generation", "print_queue", "vendor_integration"],
        "depends_on": ["E0", "E8"],
        "events_published": ["print.queued", "print.completed"],
        "events_subscribed": ["content.approved"],
        "priority": 4
    },
    "E15": {
        "name": "Contact Directory",
        "type": "content",
        "provides": ["360_contact_view", "merge_detection", "enrichment"],
        "depends_on": ["E0", "E1"],
        "events_published": ["contact.created", "contact.updated", "contact.merged"],
        "events_subscribed": ["donation.received", "event.rsvp"],
        "priority": 2
    },
    
    # MEDIA & ADVERTISING (E16-E23)
    "E16": {
        "name": "TV/Radio AI",
        "type": "media",
        "provides": ["script_generation", "media_buying", "performance_tracking"],
        "depends_on": ["E0", "E9", "E13"],
        "events_published": ["media.ad_created", "media.performance_update"],
        "events_subscribed": ["campaign.launched"],
        "priority": 4
    },
    "E17": {
        "name": "RVM System",
        "type": "media",
        "provides": ["ringless_voicemail", "delivery_tracking"],
        "depends_on": ["E0", "E15"],
        "events_published": ["rvm.delivered", "rvm.failed"],
        "events_subscribed": ["campaign.rvm_scheduled"],
        "priority": 4
    },
    "E18": {
        "name": "VDP Composition Engine",
        "type": "media",
        "provides": ["variable_data_printing", "personalization", "image_generation"],
        "depends_on": ["E0", "E1", "E13", "E20", "E21"],
        "events_published": ["vdp.composed", "vdp.print_ready"],
        "events_subscribed": ["mail.campaign_started"],
        "priority": 4
    },
    "E19": {
        "name": "Social Media Manager",
        "type": "media",
        "provides": ["multi_platform_posting", "carousels", "scheduling"],
        "depends_on": ["E0", "E8", "E9"],
        "events_published": ["social.posted", "social.engagement_high"],
        "events_subscribed": ["content.approved", "news.positive_coverage"],
        "priority": 3
    },
    "E20": {
        "name": "Intelligence Brain",
        "type": "media",
        "provides": ["decision_engine", "event_processing", "action_routing"],
        "depends_on": ["E0", "E1", "E6", "E13"],
        "events_published": ["brain.decision_made", "brain.action_triggered"],
        "events_subscribed": ["*"],  # Central processor - subscribes to all
        "ml_models": ["decision_model", "priority_scorer"],
        "priority": 2
    },
    "E21": {
        "name": "ML Clustering",
        "type": "media",
        "provides": ["behavioral_segments", "lookalike_audiences", "clustering"],
        "depends_on": ["E0", "E1", "E6"],
        "events_published": ["ml.segments_updated", "ml.model_trained"],
        "events_subscribed": ["donation.received", "email.opened"],
        "ml_models": ["kmeans_clusterer", "lookalike_model"],
        "priority": 3
    },
    "E22": {
        "name": "A/B Testing Engine",
        "type": "media",
        "provides": ["experiment_management", "statistical_analysis", "auto_winner"],
        "depends_on": ["E0", "E6"],
        "events_published": ["ab.winner_declared", "ab.significance_reached"],
        "events_subscribed": ["email.opened", "email.clicked", "donation.received"],
        "priority": 3
    },
    "E23": {
        "name": "Creative Asset Engine",
        "type": "media",
        "provides": ["asset_management", "3d_generation", "brand_consistency"],
        "depends_on": ["E0", "E13"],
        "events_published": ["asset.created", "asset.approved"],
        "events_subscribed": ["content.requested"],
        "priority": 4
    },
    
    # COMMUNICATION CHANNELS (E30-E36)
    "E30": {
        "name": "Email System",
        "type": "channel",
        "provides": ["email_campaigns", "drip_sequences", "personalization"],
        "depends_on": ["E0", "E1", "E8", "E9", "E15"],
        "events_published": ["email.sent", "email.opened", "email.clicked", "email.bounced", "email.not_opened"],
        "events_subscribed": ["contact.created", "donation.received", "event.rsvp"],
        "priority": 3
    },
    "E31": {
        "name": "SMS System",
        "type": "channel",
        "provides": ["sms_campaigns", "rcs_messaging", "keyword_responses"],
        "depends_on": ["E0", "E8", "E15"],
        "events_published": ["sms.sent", "sms.delivered", "sms.received", "sms.keyword"],
        "events_subscribed": ["contact.created", "event.reminder_due"],
        "priority": 3
    },
    "E32": {
        "name": "Phone Banking",
        "type": "channel",
        "provides": ["call_campaigns", "dialer_integration", "script_management"],
        "depends_on": ["E0", "E5", "E15"],
        "events_published": ["phone.call_completed", "phone.positive_call", "phone.voicemail_left"],
        "events_subscribed": ["campaign.phone_scheduled"],
        "priority": 3
    },
    "E33": {
        "name": "Direct Mail",
        "type": "channel",
        "provides": ["mail_campaigns", "vdp_orchestration", "print_management"],
        "depends_on": ["E0", "E8", "E14", "E18"],
        "events_published": ["mail.queued", "mail.delivered", "mail.returned"],
        "events_subscribed": ["campaign.mail_scheduled"],
        "priority": 4
    },
    "E34": {
        "name": "Events System",
        "type": "channel",
        "provides": ["event_management", "rsvp_tracking", "check_in"],
        "depends_on": ["E0", "E15"],
        "events_published": ["event.created", "event.rsvp", "event.checked_in", "event.no_show"],
        "events_subscribed": ["calendar.event_scheduled"],
        "priority": 3
    },
    "E35": {
        "name": "Interactive Comm Hub",
        "type": "channel",
        "provides": ["ai_voice_agent", "ivr_menus", "message_center"],
        "depends_on": ["E0", "E13", "E15", "E42"],
        "events_published": ["voice.call_received", "voice.intent_detected", "message.received"],
        "events_subscribed": ["news.crisis_detected", "news.issue_trending"],
        "priority": 3
    },
    "E36": {
        "name": "Messenger Integration",
        "type": "channel",
        "provides": ["facebook_messenger", "instagram_dm", "chatbots"],
        "depends_on": ["E0", "E13", "E15"],
        "events_published": ["messenger.received", "messenger.keyword", "messenger.comment"],
        "events_subscribed": ["social.comment_received"],
        "priority": 4
    },
    
    # ADVANCED FEATURES (E37-E44)
    "E37": {
        "name": "Event Management",
        "type": "advanced",
        "provides": ["fundraisers", "rallies", "volunteer_events"],
        "depends_on": ["E0", "E15", "E34"],
        "events_published": ["event.fundraiser_created", "event.goal_reached"],
        "events_subscribed": ["calendar.event_scheduled"],
        "priority": 4
    },
    "E38": {
        "name": "Volunteer Coordination",
        "type": "advanced",
        "provides": ["shift_scheduling", "gamification", "leaderboards"],
        "depends_on": ["E0", "E5"],
        "events_published": ["volunteer.badge_earned", "volunteer.level_up"],
        "events_subscribed": ["volunteer.shift_completed"],
        "priority": 4
    },
    "E39": {
        "name": "P2P Fundraising",
        "type": "advanced",
        "provides": ["fundraiser_pages", "team_campaigns", "social_sharing"],
        "depends_on": ["E0", "E2", "E15"],
        "events_published": ["p2p.donation_received", "p2p.goal_reached"],
        "events_subscribed": ["donation.received"],
        "priority": 4
    },
    "E40": {
        "name": "Automation Control",
        "type": "advanced",
        "provides": ["ifttt_workflows", "trigger_processing", "timer_management"],
        "depends_on": ["E0", "E6", "E20"],
        "events_published": ["automation.triggered", "automation.completed", "automation.error"],
        "events_subscribed": ["*"],  # Subscribes to all for trigger matching
        "priority": 2
    },
    "E41": {
        "name": "Campaign Builder",
        "type": "advanced",
        "provides": ["campaign_creation", "ai_generation", "ifttt_selection"],
        "depends_on": ["E0", "E40"],
        "events_published": ["campaign.created", "campaign.launched"],
        "events_subscribed": [],
        "priority": 4
    },
    "E42": {
        "name": "News Intelligence",
        "type": "advanced",
        "provides": ["media_monitoring", "sentiment_analysis", "alert_system"],
        "depends_on": ["E0", "E13"],
        "events_published": [
            "news.breaking_mention", "news.crisis_detected", "news.competitor_attack",
            "news.issue_trending", "news.positive_coverage", "news.endorsement_coverage",
            "news.opponent_gaffe", "news.media_opportunity"
        ],
        "events_subscribed": [],
        "ml_models": ["sentiment_analyzer", "topic_classifier"],
        "priority": 2
    },
    "E43": {
        "name": "Advocacy Tools",
        "type": "advanced",
        "provides": ["petitions", "action_alerts", "voter_registration"],
        "depends_on": ["E0", "E15"],
        "events_published": ["petition.signed", "action.taken", "voter.registered"],
        "events_subscribed": ["news.issue_trending"],
        "priority": 4
    },
    "E44": {
        "name": "Vendor Compliance",
        "type": "advanced",
        "provides": ["vendor_management", "security_monitoring", "audit_logging"],
        "depends_on": ["E0"],
        "events_published": ["vendor.alert", "security.issue"],
        "events_subscribed": ["*"],  # Security monitoring
        "priority": 2
    }
}


# ==============================================================================
# EVENT BUS - Central Pub/Sub System
# ==============================================================================

class EventPriority(Enum):
    CRITICAL = 1   # Crisis, security
    HIGH = 2       # Donations, compliance
    NORMAL = 3     # Standard operations
    LOW = 4        # Analytics, background


@dataclass
class Event:
    """Standardized event structure"""
    event_type: str
    source_ecosystem: str
    data: Dict
    timestamp: datetime = field(default_factory=datetime.now)
    priority: EventPriority = EventPriority.NORMAL
    correlation_id: str = field(default_factory=lambda: str(hashlib.md5(str(datetime.now()).encode()).hexdigest()[:12]))
    retry_count: int = 0
    
    def to_dict(self) -> Dict:
        return {
            'event_type': self.event_type,
            'source': self.source_ecosystem,
            'data': self.data,
            'timestamp': self.timestamp.isoformat(),
            'priority': self.priority.value,
            'correlation_id': self.correlation_id,
            'retry_count': self.retry_count
        }


class EventBus:
    """Central event bus for all ecosystem communication"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self.redis = redis.Redis(
            host=IntegrationConfig.REDIS_HOST,
            port=IntegrationConfig.REDIS_PORT,
            decode_responses=True
        )
        self.subscribers: Dict[str, List[Callable]] = {}
        self.event_queue = PriorityQueue(maxsize=IntegrationConfig.EVENT_QUEUE_SIZE)
        self._processing = False
        self._lock = threading.Lock()
        
        # Start event processor
        self._start_processor()
        
        self._initialized = True
        logger.info("🚌 Event Bus initialized")
    
    def _start_processor(self):
        """Start background event processor"""
        def process_events():
            while True:
                try:
                    priority, event = self.event_queue.get(timeout=1)
                    self._dispatch_event(event)
                except:
                    continue
        
        thread = threading.Thread(target=process_events, daemon=True)
        thread.start()
    
    def publish(self, event: Event):
        """Publish event to the bus"""
        # Add to processing queue
        self.event_queue.put((event.priority.value, event))
        
        # Also publish to Redis for distributed systems
        self.redis.publish(
            f"events:{event.event_type}",
            json.dumps(event.to_dict())
        )
        
        logger.debug(f"Published event: {event.event_type} from {event.source_ecosystem}")
    
    def subscribe(self, event_pattern: str, callback: Callable, ecosystem: str):
        """Subscribe to events matching pattern"""
        with self._lock:
            if event_pattern not in self.subscribers:
                self.subscribers[event_pattern] = []
            self.subscribers[event_pattern].append({
                'callback': callback,
                'ecosystem': ecosystem
            })
        
        logger.debug(f"{ecosystem} subscribed to {event_pattern}")
    
    def _dispatch_event(self, event: Event):
        """Dispatch event to all matching subscribers"""
        event_type = event.event_type
        
        for pattern, handlers in self.subscribers.items():
            if self._matches_pattern(event_type, pattern):
                for handler in handlers:
                    try:
                        handler['callback'](event)
                    except Exception as e:
                        logger.error(f"Error in {handler['ecosystem']} handling {event_type}: {e}")
                        if event.retry_count < IntegrationConfig.MAX_RETRY_ATTEMPTS:
                            event.retry_count += 1
                            self.event_queue.put((event.priority.value, event))
    
    def _matches_pattern(self, event_type: str, pattern: str) -> bool:
        """Check if event type matches subscription pattern"""
        if pattern == "*":
            return True
        if pattern.endswith(".*"):
            prefix = pattern[:-2]
            return event_type.startswith(prefix)
        return event_type == pattern


# ==============================================================================
# TRIGGER ROUTER - Routes automation triggers to correct handlers
# ==============================================================================

class TriggerRouter:
    """Routes automation triggers efficiently"""
    
    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        self.trigger_handlers: Dict[str, List[Dict]] = {}
        self.db_url = IntegrationConfig.DATABASE_URL
        
        # Load trigger configurations
        self._load_trigger_configs()
        
        # Subscribe to all events for trigger matching
        event_bus.subscribe("*", self._handle_event, "TriggerRouter")
        
        logger.info("🎯 Trigger Router initialized")
    
    def _load_trigger_configs(self):
        """Load active workflow triggers from database"""
        try:
            conn = psycopg2.connect(self.db_url)
            cur = conn.cursor(cursor_factory=RealDictCursor)
            
            cur.execute("""
                SELECT workflow_id, trigger_type, trigger_config, candidate_id
                FROM automation_workflows
                WHERE status = 'active'
                AND mode != 'off'
                AND (timer_expires_at IS NULL OR timer_expires_at > NOW())
            """)
            
            for workflow in cur.fetchall():
                trigger_type = workflow['trigger_type']
                if trigger_type not in self.trigger_handlers:
                    self.trigger_handlers[trigger_type] = []
                self.trigger_handlers[trigger_type].append(workflow)
            
            conn.close()
            logger.info(f"Loaded {sum(len(h) for h in self.trigger_handlers.values())} trigger handlers")
        except Exception as e:
            logger.warning(f"Could not load triggers: {e}")
    
    def _handle_event(self, event: Event):
        """Handle incoming event and check for matching triggers"""
        event_type = event.event_type
        
        # Find matching triggers
        matching_triggers = self.trigger_handlers.get(event_type, [])
        
        for trigger in matching_triggers:
            # Check trigger conditions
            if self._evaluate_conditions(trigger, event):
                # Execute workflow
                self._execute_workflow(trigger['workflow_id'], event)
    
    def _evaluate_conditions(self, trigger: Dict, event: Event) -> bool:
        """Evaluate if trigger conditions are met"""
        config = trigger.get('trigger_config', {})
        data = event.data
        
        # Check all conditions
        for key, expected in config.items():
            if key.startswith('min_'):
                field = key[4:]
                if data.get(field, 0) < expected:
                    return False
            elif key.startswith('max_'):
                field = key[4:]
                if data.get(field, 0) > expected:
                    return False
            elif key == 'keywords':
                text = str(data.get('text', '') + data.get('message', '')).lower()
                if not any(kw.lower() in text for kw in expected):
                    return False
            elif data.get(key) != expected:
                return False
        
        return True
    
    def _execute_workflow(self, workflow_id: str, event: Event):
        """Execute workflow actions"""
        # Publish workflow execution event
        self.event_bus.publish(Event(
            event_type="automation.triggered",
            source_ecosystem="E40",
            data={
                'workflow_id': workflow_id,
                'trigger_event': event.event_type,
                'trigger_data': event.data
            },
            priority=EventPriority.HIGH
        ))


# ==============================================================================
# ML PIPELINE COORDINATOR - Coordinates ML operations across ecosystems
# ==============================================================================

class MLPipelineCoordinator:
    """Coordinates ML model training and predictions across ecosystems"""
    
    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        self.models: Dict[str, Dict] = {}
        self.prediction_cache = {}
        
        # Register ML models from ecosystems
        self._register_models()
        
        # Subscribe to events that need ML processing
        event_bus.subscribe("donation.received", self._on_donation, "MLPipeline")
        event_bus.subscribe("contact.created", self._on_contact, "MLPipeline")
        
        logger.info("🧠 ML Pipeline Coordinator initialized")
    
    def _register_models(self):
        """Register all ML models from ecosystems"""
        self.models = {
            # E1 - Donor Intelligence
            "churn_predictor": {"ecosystem": "E1", "type": "classification", "refresh_hours": 24},
            "ask_optimizer": {"ecosystem": "E1", "type": "regression", "refresh_hours": 12},
            "channel_predictor": {"ecosystem": "E1", "type": "classification", "refresh_hours": 24},
            
            # E4 - Activist Network
            "show_rate_predictor": {"ecosystem": "E4", "type": "regression", "refresh_hours": 24},
            
            # E20 - Intelligence Brain
            "decision_model": {"ecosystem": "E20", "type": "classification", "refresh_hours": 6},
            "priority_scorer": {"ecosystem": "E20", "type": "regression", "refresh_hours": 6},
            
            # E21 - ML Clustering
            "kmeans_clusterer": {"ecosystem": "E21", "type": "clustering", "refresh_hours": 168},  # Weekly
            "lookalike_model": {"ecosystem": "E21", "type": "similarity", "refresh_hours": 72},
            
            # E42 - News Intelligence
            "sentiment_analyzer": {"ecosystem": "E42", "type": "classification", "refresh_hours": 1},
            "topic_classifier": {"ecosystem": "E42", "type": "classification", "refresh_hours": 1},
        }
    
    def predict(self, model_name: str, features: Dict) -> Dict:
        """Get prediction from specified model"""
        if model_name not in self.models:
            return {"error": f"Unknown model: {model_name}"}
        
        # Check cache
        cache_key = f"{model_name}:{hash(frozenset(features.items()))}"
        if cache_key in self.prediction_cache:
            cached = self.prediction_cache[cache_key]
            if (datetime.now() - cached['timestamp']).seconds < IntegrationConfig.CACHE_TTL_SECONDS:
                return cached['prediction']
        
        # Get prediction (in production, calls actual model)
        prediction = self._call_model(model_name, features)
        
        # Cache result
        self.prediction_cache[cache_key] = {
            'prediction': prediction,
            'timestamp': datetime.now()
        }
        
        return prediction
    
    def _call_model(self, model_name: str, features: Dict) -> Dict:
        """Call the actual ML model"""
        # In production, this routes to the appropriate ecosystem
        model_info = self.models[model_name]
        return {
            'model': model_name,
            'ecosystem': model_info['ecosystem'],
            'prediction': 0.5,  # Placeholder
            'confidence': 0.8
        }
    
    def _on_donation(self, event: Event):
        """Process donation for ML updates"""
        donor_id = event.data.get('donor_id')
        if donor_id:
            # Trigger churn risk recalculation
            self.predict('churn_predictor', {'donor_id': donor_id})
    
    def _on_contact(self, event: Event):
        """Process new contact for ML segmentation"""
        contact_id = event.data.get('contact_id')
        if contact_id:
            # Trigger clustering assignment
            self.predict('kmeans_clusterer', {'contact_id': contact_id})


# ==============================================================================
# CACHE MANAGER - Shared caching across ecosystems
# ==============================================================================

class CacheManager:
    """Manages shared cache across all ecosystems"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self.redis = redis.Redis(
            host=IntegrationConfig.REDIS_HOST,
            port=IntegrationConfig.REDIS_PORT,
            decode_responses=True
        )
        self._initialized = True
        logger.info("📦 Cache Manager initialized")
    
    def get(self, key: str, ecosystem: str = None) -> Optional[Any]:
        """Get cached value"""
        full_key = f"{ecosystem}:{key}" if ecosystem else key
        value = self.redis.get(full_key)
        return json.loads(value) if value else None
    
    def set(self, key: str, value: Any, ttl: int = None, ecosystem: str = None):
        """Set cached value"""
        full_key = f"{ecosystem}:{key}" if ecosystem else key
        ttl = ttl or IntegrationConfig.CACHE_TTL_SECONDS
        self.redis.setex(full_key, ttl, json.dumps(value))
    
    def invalidate(self, key: str, ecosystem: str = None):
        """Invalidate cache key"""
        full_key = f"{ecosystem}:{key}" if ecosystem else key
        self.redis.delete(full_key)
    
    def invalidate_pattern(self, pattern: str):
        """Invalidate all keys matching pattern"""
        for key in self.redis.scan_iter(pattern):
            self.redis.delete(key)


# ==============================================================================
# HEALTH MONITOR - Cross-ecosystem health monitoring
# ==============================================================================

class HealthMonitor:
    """Monitors health of all ecosystems"""
    
    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        self.health_status: Dict[str, Dict] = {}
        self.db_url = IntegrationConfig.DATABASE_URL
        
        # Initialize health status for all ecosystems
        for eco_id in ECOSYSTEM_REGISTRY:
            self.health_status[eco_id] = {
                'status': 'unknown',
                'last_check': None,
                'errors': []
            }
        
        # Start health check loop
        self._start_monitoring()
        
        logger.info("🏥 Health Monitor initialized")
    
    def _start_monitoring(self):
        """Start background health monitoring"""
        def check_loop():
            while True:
                self._check_all_ecosystems()
                threading.Event().wait(IntegrationConfig.HEALTH_CHECK_INTERVAL)
        
        thread = threading.Thread(target=check_loop, daemon=True)
        thread.start()
    
    def _check_all_ecosystems(self):
        """Check health of all ecosystems"""
        for eco_id, eco_info in ECOSYSTEM_REGISTRY.items():
            try:
                # Check database connectivity
                self._check_database()
                
                # Check dependencies
                for dep in eco_info['depends_on']:
                    if self.health_status.get(dep, {}).get('status') != 'healthy':
                        raise Exception(f"Dependency {dep} unhealthy")
                
                self.health_status[eco_id] = {
                    'status': 'healthy',
                    'last_check': datetime.now(),
                    'errors': []
                }
            except Exception as e:
                self.health_status[eco_id] = {
                    'status': 'unhealthy',
                    'last_check': datetime.now(),
                    'errors': [str(e)]
                }
    
    def _check_database(self):
        """Check database connectivity"""
        conn = psycopg2.connect(self.db_url)
        cur = conn.cursor()
        cur.execute("SELECT 1")
        conn.close()
    
    def get_status(self) -> Dict:
        """Get health status of all ecosystems"""
        return {
            'timestamp': datetime.now().isoformat(),
            'overall': 'healthy' if all(h['status'] == 'healthy' for h in self.health_status.values()) else 'degraded',
            'ecosystems': self.health_status
        }


# ==============================================================================
# INTEGRATION ORCHESTRATOR - Main entry point
# ==============================================================================

class IntegrationOrchestrator:
    """Main orchestrator that initializes and coordinates all systems"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        logger.info("=" * 60)
        logger.info("🚀 INITIALIZING BROYHILLGOP INTEGRATION ORCHESTRATOR")
        logger.info("=" * 60)
        
        # Initialize core components
        self.event_bus = EventBus()
        self.cache = CacheManager()
        self.health = HealthMonitor(self.event_bus)
        self.trigger_router = TriggerRouter(self.event_bus)
        self.ml_pipeline = MLPipelineCoordinator(self.event_bus)
        
        # Register ecosystem event handlers
        self._register_ecosystem_handlers()
        
        self._initialized = True
        logger.info("✅ Integration Orchestrator ready")
    
    def _register_ecosystem_handlers(self):
        """Register event handlers for each ecosystem"""
        for eco_id, eco_info in ECOSYSTEM_REGISTRY.items():
            for event in eco_info.get('events_subscribed', []):
                if event != "*":
                    self.event_bus.subscribe(
                        event,
                        lambda e, eid=eco_id: self._route_to_ecosystem(eid, e),
                        eco_id
                    )
    
    def _route_to_ecosystem(self, ecosystem_id: str, event: Event):
        """Route event to appropriate ecosystem handler"""
        # In production, this would call the actual ecosystem handler
        logger.debug(f"Routing {event.event_type} to {ecosystem_id}")
    
    def publish_event(self, event_type: str, source: str, data: Dict,
                     priority: EventPriority = EventPriority.NORMAL):
        """Publish an event from any ecosystem"""
        event = Event(
            event_type=event_type,
            source_ecosystem=source,
            data=data,
            priority=priority
        )
        self.event_bus.publish(event)
    
    def get_health(self) -> Dict:
        """Get system health status"""
        return self.health.get_status()
    
    def predict(self, model: str, features: Dict) -> Dict:
        """Get ML prediction"""
        return self.ml_pipeline.predict(model, features)


# ==============================================================================
# EVENT FLOW DOCUMENTATION
# ==============================================================================

EVENT_FLOWS = """
================================================================================
CRITICAL EVENT FLOWS - How Ecosystems Communicate
================================================================================

1. NEW DONATION FLOW
   donation.received (E2) 
   → donor.grade_changed (E1) - Updates donor grade
   → ml.segment_updated (E21) - Updates behavioral segment
   → email.triggered (E30) - Thank you email via E40 automation
   → analytics.recorded (E6) - Records conversion

2. NEW CONTACT FLOW
   contact.created (E15)
   → ml.cluster_assigned (E21) - Assigns to behavioral cluster
   → email.welcome_sequence (E30) - Starts welcome series via E40
   → brain.decision (E20) - Determines optimal first touch

3. NEWS CRISIS FLOW
   news.crisis_detected (E42)
   → brain.urgent_action (E20) - Prioritizes response
   → automation.crisis_mode (E40) - Triggers crisis workflows
   → voice.greeting_updated (E35) - Updates phone greeting
   → social.posts_paused (E19) - Pauses scheduled posts
   → email.pause_check (E30) - Reviews pending emails

4. EVENT RSVP FLOW
   event.rsvp (E34)
   → email.confirmation (E30) - Sends confirmation
   → sms.reminder_scheduled (E31) - Schedules reminder
   → contact.updated (E15) - Updates contact record
   → volunteer.shift_check (E5) - Checks for volunteer shifts

5. CAMPAIGN LAUNCH FLOW
   campaign.launched (E41)
   → automation.workflows_activated (E40) - Activates IFTTT
   → email.campaign_started (E30) - Starts email sends
   → sms.campaign_started (E31) - Starts SMS sends
   → analytics.tracking_started (E6) - Begins tracking

6. LAPSED DONOR DETECTION
   donor.became_lapsed (E1)
   → automation.reactivation (E40) - Triggers reactivation workflow
   → email.lapsed_sequence (E30) - Starts re-engagement
   → ml.churn_analysis (E21) - Analyzes churn patterns

================================================================================
"""


# ==============================================================================
# DEPLOYMENT
# ==============================================================================

INTEGRATION_SCHEMA = """
-- Integration tables for cross-ecosystem coordination

-- Event log for debugging
CREATE TABLE IF NOT EXISTS integration_event_log (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    source_ecosystem VARCHAR(10) NOT NULL,
    target_ecosystems JSONB DEFAULT '[]',
    event_data JSONB DEFAULT '{}',
    priority INTEGER DEFAULT 3,
    correlation_id VARCHAR(50),
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_log_type ON integration_event_log(event_type);
CREATE INDEX IF NOT EXISTS idx_event_log_source ON integration_event_log(source_ecosystem);
CREATE INDEX IF NOT EXISTS idx_event_log_processed ON integration_event_log(processed);

-- Cross-ecosystem data contracts
CREATE TABLE IF NOT EXISTS data_contracts (
    contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_ecosystem VARCHAR(10) NOT NULL,
    target_ecosystem VARCHAR(10) NOT NULL,
    data_type VARCHAR(100) NOT NULL,
    schema_definition JSONB NOT NULL,
    version VARCHAR(20) DEFAULT '1.0',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ML model registry
CREATE TABLE IF NOT EXISTS ml_model_registry (
    model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name VARCHAR(100) NOT NULL,
    ecosystem VARCHAR(10) NOT NULL,
    model_type VARCHAR(50),
    version VARCHAR(20),
    trained_at TIMESTAMP,
    metrics JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Health check history
CREATE TABLE IF NOT EXISTS health_check_history (
    check_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ecosystem VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    error_message TEXT,
    checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_ecosystem ON health_check_history(ecosystem);
CREATE INDEX IF NOT EXISTS idx_health_checked ON health_check_history(checked_at);

SELECT 'Integration Architecture schema deployed!' as status;
"""


def deploy_integration_architecture():
    """Deploy integration architecture"""
    print("=" * 70)
    print("🔗 ECOSYSTEM INTEGRATION ARCHITECTURE - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(IntegrationConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(INTEGRATION_SCHEMA)
        conn.commit()
        conn.close()
        
        print("   ✅ integration_event_log table")
        print("   ✅ data_contracts table")
        print("   ✅ ml_model_registry table")
        print("   ✅ health_check_history table")
        
        print("\n" + "=" * 70)
        print("✅ INTEGRATION ARCHITECTURE DEPLOYED!")
        print("=" * 70)
        
        print("\n🔄 COMPONENTS:")
        print("   • Event Bus - Pub/sub for all ecosystems")
        print("   • Trigger Router - IFTTT automation routing")
        print("   • ML Pipeline - Coordinated predictions")
        print("   • Cache Manager - Shared caching")
        print("   • Health Monitor - Cross-ecosystem health")
        
        print("\n📊 REGISTERED ECOSYSTEMS:", len(ECOSYSTEM_REGISTRY))
        
        # Print ecosystem dependencies
        print("\n🔗 KEY DEPENDENCIES:")
        for eco_id, eco_info in sorted(ECOSYSTEM_REGISTRY.items(), key=lambda x: x[1]['priority']):
            deps = eco_info['depends_on']
            if deps:
                print(f"   {eco_id} ({eco_info['name']}) ← {', '.join(deps)}")
        
        print("\n" + EVENT_FLOWS)
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_integration_architecture()
    else:
        # Initialize orchestrator
        orchestrator = IntegrationOrchestrator()
        print(json.dumps(orchestrator.get_health(), indent=2, default=str))
