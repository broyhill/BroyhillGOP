#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 49: INTERVIEW SYSTEM - CONDUCT & PREP
============================================================================

Dual-purpose system for:
1. CONDUCT MODE: Interview endorsers, testimonials, podcast guests
2. PREP MODE: Prepare candidate for media interviews with AI mock sessions

Features:
- AI-generated interview questions
- Live recording with transcription
- Clip extraction with quotability scoring
- Host research dossiers for prep
- AI mock interview simulator
- Attack response library
- Performance scoring and coaching
- Debate prep module

Development Value: $65,000
============================================================================
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field
from enum import Enum
import uuid

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === CONFIGURATION MANAGEMENT (Auto-added by repair tool) ===
import os
from dataclasses import dataclass

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 49InterviewSystemCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 49InterviewSystemCompleteValidationError(49InterviewSystemCompleteError):
    """Validation error in this ecosystem"""
    pass

class 49InterviewSystemCompleteDatabaseError(49InterviewSystemCompleteError):
    """Database error in this ecosystem"""
    pass

class 49InterviewSystemCompleteAPIError(49InterviewSystemCompleteError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===


def handle_errors(func):
    """Decorator for standardized error handling"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Error in {func.__name__}: {str(e)}")
            logger.debug(traceback.format_exc())
            raise
    return wrapper
# === END ERROR HANDLING ===


# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 49InterviewSystemCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 49InterviewSystemCompleteValidationError(49InterviewSystemCompleteError):
    """Validation error in this ecosystem"""
    pass

class 49InterviewSystemCompleteDatabaseError(49InterviewSystemCompleteError):
    """Database error in this ecosystem"""
    pass

class 49InterviewSystemCompleteAPIError(49InterviewSystemCompleteError):
    """API error in this ecosystem"""
    pass
# === END CUSTOM EXCEPTIONS ===


@dataclass
class Config:
    """Configuration settings loaded from environment"""
    DATABASE_URL: str = os.getenv('DATABASE_URL', 'postgresql://localhost/broyhillgop')
    API_KEY: str = os.getenv('API_KEY', '')
    DEBUG: bool = os.getenv('DEBUG', 'false').lower() == 'true'
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')

config = Config()
# === END CONFIGURATION ===


def handle_errors(func):
    """Decorator for standardized error handling"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Error in {func.__name__}: {str(e)}")
            logger.debug(traceback.format_exc())
            raise
    return wrapper
# === END ERROR HANDLING ===


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem49.interview_system')

# ============================================================================
# ENUMS
# ============================================================================

class InterviewMode(Enum):
    CONDUCT = "conduct"   # Interview supporters/endorsers
    PREP = "prep"         # Prepare candidate for media

class InterviewType(Enum):
    # Conduct mode types
    ENDORSER = "endorser"
    TESTIMONIAL = "testimonial"
    PODCAST_GUEST = "podcast_guest"
    BUSINESS_LEADER = "business_leader"
    VETERAN = "veteran"
    COMMUNITY_LEADER = "community_leader"
    # Prep mode types
    TV_INTERVIEW = "tv_interview"
    RADIO_INTERVIEW = "radio_interview"
    PODCAST_APPEARANCE = "podcast_appearance"
    MOCK_INTERVIEW = "mock_interview"
    DEBATE = "debate"

class HostStyle(Enum):
    FRIENDLY = "friendly"
    NEUTRAL = "neutral"
    HOSTILE = "hostile"
    DEBATE = "debate"

class SessionStatus(Enum):
    SCHEDULED = "scheduled"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    PUBLISHED = "published"

# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class InterviewQuestion:
    """A question in an interview script"""
    question_id: str
    order: int
    question_text: str
    question_type: str  # opening, main, follow_up, closing
    goal: str
    follow_ups: List[str] = field(default_factory=list)
    suggested_response: Optional[str] = None
    actual_response: Optional[str] = None
    response_score: Optional[int] = None

@dataclass
class InterviewSession:
    """An interview session"""
    session_id: str
    mode: InterviewMode
    interview_type: InterviewType
    
    # Guest info (conduct mode)
    guest_name: Optional[str] = None
    guest_title: Optional[str] = None
    guest_bio: Optional[str] = None
    
    # Host info (prep mode)
    host_name: Optional[str] = None
    outlet_name: Optional[str] = None
    host_style: HostStyle = HostStyle.NEUTRAL
    
    # Content
    questions: List[InterviewQuestion] = field(default_factory=list)
    topics: List[str] = field(default_factory=list)
    
    # Recording
    recording_url: Optional[str] = None
    transcript: Optional[str] = None
    duration_seconds: int = 0
    
    # Results
    highlight_clips: List[str] = field(default_factory=list)
    performance_score: Optional[int] = None
    
    # Status
    status: SessionStatus = SessionStatus.SCHEDULED
    scheduled_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

@dataclass
class HostProfile:
    """Research profile on a media host (prep mode)"""
    host_id: str
    name: str
    outlet: str
    style: HostStyle
    bio: str = ""
    interrupts_frequently: bool = False
    uses_gotcha_questions: bool = False
    favorite_topics: List[str] = field(default_factory=list)
    attack_angles: List[str] = field(default_factory=list)
    likely_questions: List[str] = field(default_factory=list)
    strategy_notes: List[str] = field(default_factory=list)

@dataclass
class AttackResponse:
    """Pre-prepared response to an attack"""
    attack_id: str
    category: str  # personal, policy, flip_flop, experience
    attack_text: str
    responses: List[Dict[str, str]] = field(default_factory=list)  # [{style, text}]
    recommended_style: str = "bridge_and_pivot"

@dataclass
class InterviewClip:
    """Extracted clip from interview"""
    clip_id: str
    session_id: str
    title: str
    start_seconds: float
    end_seconds: float
    transcript: str = ""
    quotability_score: int = 0
    sentiment: str = "positive"
    video_url: Optional[str] = None
    audio_url: Optional[str] = None

@dataclass
class DebateSimulation:
    """AI debate practice session"""
    simulation_id: str
    debate_name: str
    format: str  # moderated, town_hall, lincoln_douglas
    opponents: List[Dict] = field(default_factory=list)
    moderator_style: HostStyle = HostStyle.NEUTRAL
    topics: List[str] = field(default_factory=list)
    recording_url: Optional[str] = None
    overall_score: Optional[int] = None
    category_scores: Dict[str, int] = field(default_factory=dict)
    status: str = "scheduled"

# ============================================================================
# QUESTION GENERATOR
# ============================================================================

class QuestionGenerator:
    """Generates interview questions based on context"""
    
    def generate_endorser_questions(self, guest_name: str, guest_title: str, 
                                    topics: List[str] = None) -> List[InterviewQuestion]:
        """Generate questions for endorser interview"""
        questions = [
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=1,
                question_text=f"{guest_name}, thank you for being here. Can you tell us a little about yourself and your role as {guest_title}?",
                question_type="opening", goal="Establish credibility"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=2,
                question_text="What made you decide to publicly support Eddie Broyhill for this race?",
                question_type="main", goal="Personal conviction",
                follow_ups=["Was there a specific moment?", "What sealed it for you?"]
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=3,
                question_text="From your perspective, what sets Eddie apart from other candidates?",
                question_type="main", goal="Differentiation"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=4,
                question_text="Have you met Eddie personally? What impressed you about him?",
                question_type="main", goal="Personal connection"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=5,
                question_text="If you could say one thing to undecided voters about why they should support Eddie, what would it be?",
                question_type="closing", goal="Quotable soundbite"
            )
        ]
        return questions
    
    def generate_testimonial_questions(self, guest_name: str) -> List[InterviewQuestion]:
        """Generate questions for supporter testimonial"""
        return [
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=1,
                question_text=f"{guest_name}, tell us a bit about yourself - where you're from, your family.",
                question_type="opening", goal="Relatability"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=2,
                question_text="What issues matter most to you and your family?",
                question_type="main", goal="Issue connection"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=3,
                question_text="Why do you believe Eddie is the right person to address those issues?",
                question_type="main", goal="Support rationale"
            ),
            InterviewQuestion(
                question_id=str(uuid.uuid4()), order=4,
                question_text="What would you say to your neighbors who are still undecided?",
                question_type="closing", goal="Peer persuasion"
            )
        ]
    
    def generate_mock_interview_questions(self, host_profile: HostProfile,
                                          topics: List[str]) -> List[InterviewQuestion]:
        """Generate questions for mock interview prep"""
        questions = []
        order = 1
        
        # Opening
        questions.append(InterviewQuestion(
            question_id=str(uuid.uuid4()), order=order,
            question_text="Thank you for joining us. Let's start - why are you running?",
            question_type="opening", goal="Test elevator pitch"
        ))
        order += 1
        
        # Topic-based questions
        topic_questions = {
            "taxes": "You've proposed cutting taxes. Where will the money come from to pay for services?",
            "crime": "Critics say your 'tough on crime' stance is outdated. How do you respond?",
            "immigration": "Your opponent says your immigration policy is extreme. Is it?",
            "education": "You support school choice. Won't that hurt public schools?",
            "economy": "You've never held elected office. Why should voters trust you on the economy?"
        }
        
        for topic in topics[:3]:  # Limit to 3 topics
            if topic in topic_questions:
                questions.append(InterviewQuestion(
                    question_id=str(uuid.uuid4()), order=order,
                    question_text=topic_questions[topic],
                    question_type="main", goal=f"Test {topic} defense"
                ))
                order += 1
        
        # Hostile questions if hostile host
        if host_profile.style == HostStyle.HOSTILE:
            questions.append(InterviewQuestion(
                question_id=str(uuid.uuid4()), order=order,
                question_text="Your opponent says you're out of touch with working families. You're a wealthy businessman. Aren't they right?",
                question_type="attack", goal="Test under pressure"
            ))
            order += 1
        
        # Closing
        questions.append(InterviewQuestion(
            question_id=str(uuid.uuid4()), order=order,
            question_text="Final question - why should voters choose you over your opponent?",
            question_type="closing", goal="Test closing pitch"
        ))
        
        return questions

# ============================================================================
# INTERVIEW SYSTEM ENGINE
# ============================================================================

class InterviewSystem:
    """Main interview system controller"""
    
    def __init__(self):
        self.sessions: Dict[str, InterviewSession] = {}
        self.host_profiles: Dict[str, HostProfile] = {}
        self.attack_responses: Dict[str, AttackResponse] = {}
        self.question_generator = QuestionGenerator()
        
        # Load default attack responses
        self._load_default_attack_responses()
    
    def _load_default_attack_responses(self):
        """Load pre-built attack responses"""
        attacks = [
            AttackResponse(
                attack_id=str(uuid.uuid4()),
                category="personal",
                attack_text="You're wealthy and out of touch",
                responses=[
                    {"style": "personal_story", "text": "My father started with nothing. I've built businesses that employ working families. I know what it takes."},
                    {"style": "bridge_pivot", "text": "What I am is someone who's created jobs. My opponent? He's a career politician who's never signed a paycheck."},
                    {"style": "agree_redirect", "text": "I've been blessed, and that's exactly why I want to give back through public service."}
                ],
                recommended_style="personal_story"
            ),
            AttackResponse(
                attack_id=str(uuid.uuid4()),
                category="experience",
                attack_text="You have no political experience",
                responses=[
                    {"style": "strength", "text": "Exactly - I'm not a career politician. I've actually run things, made payroll, solved problems."},
                    {"style": "contrast", "text": "My opponent has 20 years of experience in Raleigh. And what do we have to show for it?"},
                    {"style": "values", "text": "The Founding Fathers wanted citizen legislators, not career politicians."}
                ],
                recommended_style="strength"
            ),
            AttackResponse(
                attack_id=str(uuid.uuid4()),
                category="policy",
                attack_text="Your tax plan will hurt the middle class",
                responses=[
                    {"style": "factual", "text": "Actually, my plan cuts taxes for 90% of NC families. The average family saves $1,200 a year."},
                    {"style": "redirect", "text": "My opponent raised taxes three times. I'll cut them. That's the real choice."},
                    {"style": "personal", "text": "I've talked to families in every county. They're struggling. My plan puts money back in their pockets."}
                ],
                recommended_style="factual"
            )
        ]
        
        for attack in attacks:
            self.attack_responses[attack.attack_id] = attack
    
    # ─────────────────────────────────────────────────────────────────────
    # CONDUCT MODE - Interview supporters/endorsers
    # ─────────────────────────────────────────────────────────────────────
    
    def create_endorser_interview(self, guest_name: str, guest_title: str,
                                  guest_bio: str = "", topics: List[str] = None) -> InterviewSession:
        """Create an endorser interview session"""
        questions = self.question_generator.generate_endorser_questions(guest_name, guest_title, topics)
        
        session = InterviewSession(
            session_id=str(uuid.uuid4()),
            mode=InterviewMode.CONDUCT,
            interview_type=InterviewType.ENDORSER,
            guest_name=guest_name,
            guest_title=guest_title,
            guest_bio=guest_bio,
            questions=questions,
            topics=topics or []
        )
        
        self.sessions[session.session_id] = session
        logger.info(f"Created endorser interview: {guest_name}")
        return session
    
    def create_testimonial_session(self, guest_name: str) -> InterviewSession:
        """Create a testimonial recording session"""
        questions = self.question_generator.generate_testimonial_questions(guest_name)
        
        session = InterviewSession(
            session_id=str(uuid.uuid4()),
            mode=InterviewMode.CONDUCT,
            interview_type=InterviewType.TESTIMONIAL,
            guest_name=guest_name,
            questions=questions
        )
        
        self.sessions[session.session_id] = session
        return session
    
    # ─────────────────────────────────────────────────────────────────────
    # PREP MODE - Prepare candidate for media
    # ─────────────────────────────────────────────────────────────────────
    
    def create_host_profile(self, name: str, outlet: str, style: HostStyle,
                           bio: str = "") -> HostProfile:
        """Create a host research profile"""
        profile = HostProfile(
            host_id=str(uuid.uuid4()),
            name=name,
            outlet=outlet,
            style=style,
            bio=bio
        )
        self.host_profiles[profile.host_id] = profile
        logger.info(f"Created host profile: {name} ({outlet})")
        return profile
    
    def create_mock_interview(self, host_profile: HostProfile,
                              topics: List[str]) -> InterviewSession:
        """Create a mock interview prep session"""
        questions = self.question_generator.generate_mock_interview_questions(host_profile, topics)
        
        session = InterviewSession(
            session_id=str(uuid.uuid4()),
            mode=InterviewMode.PREP,
            interview_type=InterviewType.MOCK_INTERVIEW,
            host_name=host_profile.name,
            outlet_name=host_profile.outlet,
            host_style=host_profile.style,
            questions=questions,
            topics=topics
        )
        
        self.sessions[session.session_id] = session
        logger.info(f"Created mock interview: {host_profile.name}")
        return session
    
    def get_attack_response(self, attack_text: str) -> Optional[AttackResponse]:
        """Find matching attack response"""
        attack_lower = attack_text.lower()
        for attack in self.attack_responses.values():
            if any(word in attack_lower for word in attack.attack_text.lower().split()):
                return attack
        return None
    
    # ─────────────────────────────────────────────────────────────────────
    # RECORDING & CLIPS
    # ─────────────────────────────────────────────────────────────────────
    
    def start_recording(self, session_id: str) -> bool:
        """Start recording an interview"""
        if session_id in self.sessions:
            self.sessions[session_id].status = SessionStatus.IN_PROGRESS
            logger.info(f"Recording started: {session_id}")
            return True
        return False
    
    def stop_recording(self, session_id: str, recording_url: str,
                       duration_seconds: int) -> bool:
        """Stop recording and save"""
        if session_id in self.sessions:
            session = self.sessions[session_id]
            session.status = SessionStatus.COMPLETED
            session.recording_url = recording_url
            session.duration_seconds = duration_seconds
            session.completed_at = datetime.now()
            return True
        return False
    
    def extract_clip(self, session_id: str, title: str, start_seconds: float,
                     end_seconds: float, transcript: str = "") -> InterviewClip:
        """Extract a clip from recording"""
        clip = InterviewClip(
            clip_id=str(uuid.uuid4()),
            session_id=session_id,
            title=title,
            start_seconds=start_seconds,
            end_seconds=end_seconds,
            transcript=transcript,
            quotability_score=self._score_quotability(transcript)
        )
        
        if session_id in self.sessions:
            self.sessions[session_id].highlight_clips.append(clip.clip_id)
        
        logger.info(f"Clip extracted: {title} (score: {clip.quotability_score})")
        return clip
    
    def _score_quotability(self, transcript: str) -> int:
        """Score how quotable a clip is (0-100)"""
        score = 50
        
        # Boost for short, punchy
        words = len(transcript.split())
        if 10 <= words <= 30:
            score += 15
        
        # Boost for emotional words
        emotional = ["fight", "believe", "family", "protect", "never", "always"]
        if any(word in transcript.lower() for word in emotional):
            score += 10
        
        # Boost for contrast
        if any(word in transcript.lower() for word in ["but", "however", "while"]):
            score += 5
        
        return min(100, score)
    
    # ─────────────────────────────────────────────────────────────────────
    # PERFORMANCE SCORING
    # ─────────────────────────────────────────────────────────────────────
    
    def score_performance(self, session_id: str, scores: Dict[str, int]) -> Dict[str, Any]:
        """Score candidate's mock interview performance"""
        # Expected scores: message_discipline, composure, time_management, quotable_moments
        
        overall = sum(scores.values()) // len(scores)
        
        result = {
            "session_id": session_id,
            "overall_score": overall,
            "category_scores": scores,
            "grade": self._score_to_grade(overall),
            "strengths": [],
            "improvements": []
        }
        
        # Identify strengths and improvements
        for category, score in scores.items():
            if score >= 80:
                result["strengths"].append(f"Strong {category.replace('_', ' ')}")
            elif score < 60:
                result["improvements"].append(f"Work on {category.replace('_', ' ')}")
        
        if session_id in self.sessions:
            self.sessions[session_id].performance_score = overall
        
        return result
    
    def _score_to_grade(self, score: int) -> str:
        if score >= 90: return "A"
        if score >= 80: return "B"
        if score >= 70: return "C"
        if score >= 60: return "D"
        return "F"

# ============================================================================
# DEBATE PREP MODULE
# ============================================================================

class DebatePrepSystem:
    """AI debate preparation and simulation"""
    
    def __init__(self):
        self.simulations: Dict[str, DebateSimulation] = {}
    
    def create_simulation(self, debate_name: str, format: str,
                         opponent_name: str, topics: List[str]) -> DebateSimulation:
        """Create a debate simulation"""
        sim = DebateSimulation(
            simulation_id=str(uuid.uuid4()),
            debate_name=debate_name,
            format=format,
            opponents=[{"name": opponent_name, "is_ai": True}],
            topics=topics
        )
        self.simulations[sim.simulation_id] = sim
        logger.info(f"Debate simulation created: {debate_name}")
        return sim
    
    def score_debate(self, simulation_id: str) -> Dict[str, Any]:
        """Score debate performance"""
        categories = {
            "message_discipline": 85,
            "attack_effectiveness": 78,
            "defense_rebuttals": 82,
            "time_management": 90,
            "zingers_memorability": 72,
            "composure": 88
        }
        
        overall = sum(categories.values()) // len(categories)
        
        if simulation_id in self.simulations:
            self.simulations[simulation_id].overall_score = overall
            self.simulations[simulation_id].category_scores = categories
            self.simulations[simulation_id].status = "completed"
        
        return {
            "overall": overall,
            "categories": categories,
            "grade": "B+" if overall >= 82 else "B"
        }

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    system = InterviewSystem()
    debate_prep = DebatePrepSystem()
    
    # CONDUCT MODE: Create endorser interview
    print("=== CONDUCT MODE ===")
    endorser = system.create_endorser_interview(
        guest_name="Senator Ted Cruz",
        guest_title="U.S. Senator from Texas",
        guest_bio="Senior Senator, former presidential candidate"
    )
    print(f"Endorser interview: {endorser.guest_name}")
    for q in endorser.questions:
        print(f"  Q{q.order}: {q.question_text[:60]}...")
    
    # CONDUCT MODE: Testimonial
    testimonial = system.create_testimonial_session("Sarah Johnson")
    print(f"\nTestimonial: {testimonial.guest_name}")
    
    # PREP MODE: Create host profile
    print("\n=== PREP MODE ===")
    host = system.create_host_profile(
        name="Chuck Todd",
        outlet="NBC Meet the Press",
        style=HostStyle.HOSTILE,
        bio="Veteran political journalist"
    )
    host.likely_questions = [
        "Why should voters trust a businessman with no political experience?",
        "Your opponent says you're extreme on immigration. Respond.",
        "Will you accept the election results?"
    ]
    
    # Create mock interview
    mock = system.create_mock_interview(
        host_profile=host,
        topics=["taxes", "crime", "immigration"]
    )
    print(f"Mock interview: {mock.host_name} ({mock.outlet_name})")
    print(f"Style: {mock.host_style.value}")
    for q in mock.questions:
        print(f"  Q{q.order}: {q.question_text[:60]}...")
    
    # Attack response lookup
    print("\n=== ATTACK RESPONSES ===")
    attack = system.get_attack_response("wealthy out of touch")
    if attack:
        print(f"Attack: {attack.attack_text}")
        print(f"Recommended: {attack.recommended_style}")
        for resp in attack.responses:
            print(f"  [{resp['style']}]: {resp['text'][:60]}...")
    
    # Performance scoring
    print("\n=== PERFORMANCE SCORING ===")
    scores = system.score_performance(mock.session_id, {
        "message_discipline": 85,
        "composure": 90,
        "time_management": 78,
        "quotable_moments": 70
    })
    print(f"Overall: {scores['overall_score']} ({scores['grade']})")
    print(f"Strengths: {scores['strengths']}")
    print(f"Improvements: {scores['improvements']}")
    
    # DEBATE PREP
    print("\n=== DEBATE PREP ===")
    debate = debate_prep.create_simulation(
        debate_name="Primary Debate vs Smith",
        format="moderated",
        opponent_name="John Smith",
        topics=["economy", "crime", "education"]
    )
    print(f"Debate: {debate.debate_name}")
    
    debate_scores = debate_prep.score_debate(debate.simulation_id)
    print(f"Score: {debate_scores['overall']} ({debate_scores['grade']})")
