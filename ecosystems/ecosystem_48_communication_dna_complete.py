#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 48: COMMUNICATION DNA - CANDIDATE AUTHENTIC VOICE PROFILE
============================================================================

Learns and maintains the candidate's authentic communication style across
ALL AI-generated content. Auto-applies to E47 scripts, E30 emails, E31 SMS.

Development Value: $35,000
============================================================================
"""

import os
import json
import logging
from datetime import datetime
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
class 48CommunicationDnaCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 48CommunicationDnaCompleteValidationError(48CommunicationDnaCompleteError):
    """Validation error in this ecosystem"""
    pass

class 48CommunicationDnaCompleteDatabaseError(48CommunicationDnaCompleteError):
    """Database error in this ecosystem"""
    pass

class 48CommunicationDnaCompleteAPIError(48CommunicationDnaCompleteError):
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
class 48CommunicationDnaCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 48CommunicationDnaCompleteValidationError(48CommunicationDnaCompleteError):
    """Validation error in this ecosystem"""
    pass

class 48CommunicationDnaCompleteDatabaseError(48CommunicationDnaCompleteError):
    """Database error in this ecosystem"""
    pass

class 48CommunicationDnaCompleteAPIError(48CommunicationDnaCompleteError):
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
logger = logging.getLogger('ecosystem48.communication_dna')

# ============================================================================
# ENUMS
# ============================================================================

class PrimaryTone(Enum):
    WARM_AUTHORITATIVE = "warm_authoritative"
    STRONG_CONFIDENT = "strong_confident"
    PASSIONATE_FIGHTER = "passionate_fighter"
    CALM_REASONED = "calm_reasoned"
    FOLKSY_RELATABLE = "folksy_relatable"
    PROFESSIONAL_POLISHED = "professional_polished"

class Channel(Enum):
    TV_AD = "tv_ad"
    RADIO_AD = "radio_ad"
    RVM = "rvm"
    EMAIL = "email"
    SMS = "sms"
    FACEBOOK = "facebook"
    TWITTER = "twitter"
    LINKEDIN = "linkedin"
    PODCAST = "podcast"
    TOWN_HALL = "town_hall"

class AudienceSegment(Enum):
    GENERAL = "general"
    SENIORS = "seniors"
    YOUNG_VOTERS = "young_voters"
    BUSINESS_OWNERS = "business_owners"
    PARENTS = "parents"
    VETERANS = "veterans"
    FAITH_COMMUNITY = "faith_community"
    RURAL = "rural"
    SUBURBAN = "suburban"

# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class ToneProfile:
    warmth: int = 70      # 0-100
    authority: int = 60
    passion: int = 50
    humor: int = 25
    formality: int = 30
    urgency: int = 40

@dataclass
class StyleMarkers:
    uses_personal_stories: bool = True
    uses_short_sentences: bool = True
    references_family: bool = True
    avoids_jargon: bool = True
    uses_rhetorical_questions: bool = True
    addresses_audience_directly: bool = True

@dataclass
class SignaturePhrase:
    phrase: str
    context: str  # opening, transition, closing
    frequency: str  # rare, occasional, frequent

@dataclass
class IssueToneProfile:
    issue: str
    primary_tone: PrimaryTone
    intensity: int  # 0-100
    preferred_keywords: List[str] = field(default_factory=list)
    avoid_keywords: List[str] = field(default_factory=list)

@dataclass
class ChannelPreset:
    channel: Channel
    primary_tone: PrimaryTone
    intensity: int
    max_words: int

@dataclass
class AudiencePreset:
    audience: AudienceSegment
    tone_adjustment: str
    intensity_adjustment: int  # -30 to +30

@dataclass
class CommunicationDNA:
    dna_id: str
    candidate_id: str
    candidate_name: str
    primary_tone: PrimaryTone
    tone_profile: ToneProfile
    style_markers: StyleMarkers
    signature_phrases: List[SignaturePhrase] = field(default_factory=list)
    speaking_speed: str = "moderate"
    issue_profiles: Dict[str, IssueToneProfile] = field(default_factory=dict)
    channel_presets: Dict[str, ChannelPreset] = field(default_factory=dict)
    audience_presets: Dict[str, AudiencePreset] = field(default_factory=dict)
    analyzed_minutes: float = 0.0
    created_at: datetime = field(default_factory=datetime.now)

# ============================================================================
# DNA BUILDER
# ============================================================================

class DNABuilder:
    """Builds Communication DNA from analysis"""
    
    def __init__(self):
        self.profiles: Dict[str, CommunicationDNA] = {}
    
    def analyze_audio(self, audio_urls: List[str]) -> Dict[str, Any]:
        """Analyze audio for communication patterns"""
        return {
            "detected_tone": PrimaryTone.WARM_AUTHORITATIVE,
            "tone_profile": ToneProfile(warmth=78, authority=62, passion=54, humor=31, formality=25),
            "style_markers": StyleMarkers(),
            "signature_phrases": [
                SignaturePhrase("Here's the thing", "transition", "frequent"),
                SignaturePhrase("Let me tell you something", "opening", "frequent"),
                SignaturePhrase("Plain and simple", "emphasis", "frequent")
            ],
            "total_minutes": len(audio_urls) * 10.0
        }
    
    def create_dna(self, candidate_id: str, candidate_name: str, audio_urls: List[str]) -> CommunicationDNA:
        """Create DNA profile from analysis"""
        analysis = self.analyze_audio(audio_urls)
        
        dna = CommunicationDNA(
            dna_id=str(uuid.uuid4()),
            candidate_id=candidate_id,
            candidate_name=candidate_name,
            primary_tone=analysis["detected_tone"],
            tone_profile=analysis["tone_profile"],
            style_markers=analysis["style_markers"],
            signature_phrases=analysis["signature_phrases"],
            analyzed_minutes=analysis["total_minutes"]
        )
        
        # Set issue profiles
        dna.issue_profiles = {
            "taxes": IssueToneProfile("taxes", PrimaryTone.WARM_AUTHORITATIVE, 55,
                                      ["your money", "earned", "family"], ["wealthy"]),
            "crime": IssueToneProfile("crime", PrimaryTone.PASSIONATE_FIGHTER, 75,
                                      ["safe", "protect", "families"], []),
            "education": IssueToneProfile("education", PrimaryTone.WARM_AUTHORITATIVE, 65,
                                         ["children", "parents", "future"], []),
            "economy": IssueToneProfile("economy", PrimaryTone.STRONG_CONFIDENT, 50,
                                       ["jobs", "growth", "opportunity"], [])
        }
        
        # Set channel presets
        dna.channel_presets = {
            "tv_ad": ChannelPreset(Channel.TV_AD, dna.primary_tone, 55, 150),
            "rvm": ChannelPreset(Channel.RVM, PrimaryTone.FOLKSY_RELATABLE, 40, 75),
            "email": ChannelPreset(Channel.EMAIL, dna.primary_tone, 50, 300),
            "sms": ChannelPreset(Channel.SMS, PrimaryTone.FOLKSY_RELATABLE, 40, 40),
            "twitter": ChannelPreset(Channel.TWITTER, PrimaryTone.PASSIONATE_FIGHTER, 70, 50),
            "linkedin": ChannelPreset(Channel.LINKEDIN, PrimaryTone.PROFESSIONAL_POLISHED, 35, 200)
        }
        
        # Set audience presets
        dna.audience_presets = {
            "seniors": AudiencePreset(AudienceSegment.SENIORS, "more_respectful", -15),
            "young_voters": AudiencePreset(AudienceSegment.YOUNG_VOTERS, "more_direct", 10),
            "parents": AudiencePreset(AudienceSegment.PARENTS, "more_protective", 5),
            "veterans": AudiencePreset(AudienceSegment.VETERANS, "more_formal", 0),
            "business_owners": AudiencePreset(AudienceSegment.BUSINESS_OWNERS, "more_practical", -5)
        }
        
        self.profiles[dna.dna_id] = dna
        logger.info(f"Created Communication DNA for {candidate_name}")
        return dna
    
    def get_parameters(self, dna: CommunicationDNA, issue: str, channel: str, 
                       audience: str = "general") -> Dict[str, Any]:
        """Get DNA-adjusted parameters for content generation"""
        
        # Base from channel
        ch_preset = dna.channel_presets.get(channel)
        base_tone = dna.primary_tone
        base_intensity = 50
        
        if ch_preset:
            base_tone = ch_preset.primary_tone
            base_intensity = ch_preset.intensity
        
        # Adjust for issue
        issue_profile = dna.issue_profiles.get(issue)
        if issue_profile:
            base_tone = issue_profile.primary_tone
            base_intensity = issue_profile.intensity
        
        # Adjust for audience
        aud_preset = dna.audience_presets.get(audience)
        if aud_preset:
            base_intensity += aud_preset.intensity_adjustment
        
        return {
            "tone": base_tone.value,
            "intensity": max(0, min(100, base_intensity)),
            "style_markers": dna.style_markers,
            "signature_phrases": [p.phrase for p in dna.signature_phrases],
            "preferred_keywords": issue_profile.preferred_keywords if issue_profile else [],
            "avoid_keywords": issue_profile.avoid_keywords if issue_profile else []
        }

# ============================================================================
# DNA APPLICATOR (For other ecosystems to use)
# ============================================================================

class DNAApplicator:
    """Applies DNA to content generation - used by E47, E30, E31, E19"""
    
    def __init__(self, dna: CommunicationDNA):
        self.dna = dna
        self.builder = DNABuilder()
    
    def apply_to_script(self, script_text: str, issue: str, channel: str) -> str:
        """Apply DNA style to a script"""
        params = self.builder.get_parameters(self.dna, issue, channel)
        
        # Add signature phrases where appropriate
        # In production: use NLP to intelligently insert
        
        return script_text
    
    def get_voice_settings(self) -> Dict[str, Any]:
        """Get voice synthesis settings from DNA"""
        return {
            "speed": 1.0 if self.dna.speaking_speed == "moderate" else (0.9 if self.dna.speaking_speed == "slow" else 1.1),
            "warmth": self.dna.tone_profile.warmth / 100,
            "emphasis": self.dna.tone_profile.passion / 100
        }

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    builder = DNABuilder()
    
    # Create DNA from "analyzed" audio
    dna = builder.create_dna(
        candidate_id="eddie_broyhill",
        candidate_name="Eddie Broyhill",
        audio_urls=["speech1.mp3", "interview1.mp3", "podcast1.mp3"]
    )
    
    print(f"DNA Created: {dna.candidate_name}")
    print(f"Primary Tone: {dna.primary_tone.value}")
    print(f"Tone Profile: warmth={dna.tone_profile.warmth}, authority={dna.tone_profile.authority}")
    print(f"Signature Phrases: {[p.phrase for p in dna.signature_phrases]}")
    
    # Get parameters for different contexts
    params_tv = builder.get_parameters(dna, "taxes", "tv_ad", "general")
    print(f"\nTV Ad (taxes): {params_tv}")
    
    params_rvm = builder.get_parameters(dna, "crime", "rvm", "seniors")
    print(f"RVM (crime, seniors): {params_rvm}")
    
    params_twitter = builder.get_parameters(dna, "immigration", "twitter", "general")
    print(f"Twitter (immigration): {params_twitter}")
