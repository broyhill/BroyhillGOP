#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 48: COMMUNICATION DNA - CANDIDATE AUTHENTIC VOICE PROFILE
================================================================================
Learns and maintains the candidate's authentic communication style across
ALL AI-generated content. Auto-applies to E47 scripts, E30 emails, E31 SMS.

Features:
- Voice fingerprint analysis from sample content
- Tone/style preferences by context
- Vocabulary and phrase patterns
- Regional dialect considerations
- Issue-specific messaging templates
- Authenticity scoring for generated content
- Cross-ecosystem style enforcement

Development Value: $95,000
================================================================================
"""

import os
import json
import logging
import uuid
import re
from datetime import datetime
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
import asyncio
from collections import Counter

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem48.communication_dna')

# ============================================================================
# ENUMS
# ============================================================================

class PrimaryTone(Enum):
    AUTHORITATIVE = 'authoritative'
    CONVERSATIONAL = 'conversational'
    INSPIRATIONAL = 'inspirational'
    PASSIONATE = 'passionate'
    MEASURED = 'measured'
    FOLKSY = 'folksy'
    PROFESSIONAL = 'professional'
    EMPATHETIC = 'empathetic'

class CommunicationContext(Enum):
    FUNDRAISING = 'fundraising'
    VOTER_OUTREACH = 'voter_outreach'
    ISSUE_ADVOCACY = 'issue_advocacy'
    ATTACK_RESPONSE = 'attack_response'
    THANK_YOU = 'thank_you'
    EVENT_INVITATION = 'event_invitation'
    ENDORSEMENT = 'endorsement'
    CRISIS = 'crisis'
    CELEBRATION = 'celebration'
    ANNOUNCEMENT = 'announcement'

class ContentChannel(Enum):
    EMAIL = 'email'
    SMS = 'sms'
    RVM = 'rvm'
    SOCIAL_FACEBOOK = 'social_facebook'
    SOCIAL_TWITTER = 'social_twitter'
    SOCIAL_INSTAGRAM = 'social_instagram'
    VIDEO_SCRIPT = 'video_script'
    RADIO_SCRIPT = 'radio_script'
    DIRECT_MAIL = 'direct_mail'
    SPEECH = 'speech'
    PRESS_RELEASE = 'press_release'
    TALKING_POINTS = 'talking_points'

class SentenceStructure(Enum):
    SIMPLE = 'simple'
    COMPOUND = 'compound'
    COMPLEX = 'complex'
    VARIED = 'varied'

class VocabularyLevel(Enum):
    SIMPLE = 'simple'           # 6th grade
    MODERATE = 'moderate'       # 8th grade
    SOPHISTICATED = 'sophisticated'  # 12th grade
    MIXED = 'mixed'

class RegionalDialect(Enum):
    NEUTRAL = 'neutral'
    SOUTHERN = 'southern'
    APPALACHIAN = 'appalachian'
    COASTAL_NC = 'coastal_nc'
    PIEDMONT_NC = 'piedmont_nc'
    MOUNTAIN_NC = 'mountain_nc'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class VoiceFingerprint:
    """Unique voice characteristics extracted from samples."""
    fingerprint_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    
    # Tone & Style
    primary_tone: PrimaryTone = PrimaryTone.CONVERSATIONAL
    secondary_tones: List[PrimaryTone] = field(default_factory=list)
    formality_score: float = 0.5  # 0=casual, 1=formal
    warmth_score: float = 0.7     # 0=distant, 1=warm
    energy_level: float = 0.6     # 0=calm, 1=high energy
    
    # Vocabulary
    vocabulary_level: VocabularyLevel = VocabularyLevel.MODERATE
    avg_sentence_length: float = 15.0
    sentence_structure: SentenceStructure = SentenceStructure.VARIED
    
    # Signature elements
    favorite_phrases: List[str] = field(default_factory=list)
    power_words: List[str] = field(default_factory=list)
    avoided_words: List[str] = field(default_factory=list)
    signature_opener: Optional[str] = None
    signature_closer: Optional[str] = None
    
    # Regional
    regional_dialect: RegionalDialect = RegionalDialect.PIEDMONT_NC
    local_references: List[str] = field(default_factory=list)
    
    # Pronouns & Voice
    uses_first_person_plural: bool = True  # "We" vs "I"
    direct_address_style: str = 'friend'   # friend, neighbor, fellow
    
    # Metrics
    samples_analyzed: int = 0
    last_updated: datetime = field(default_factory=datetime.now)
    confidence_score: float = 0.0

@dataclass
class ContextStyle:
    """Style preferences for specific communication contexts."""
    context: CommunicationContext = CommunicationContext.VOTER_OUTREACH
    tone_override: Optional[PrimaryTone] = None
    urgency_level: float = 0.5
    call_to_action_style: str = 'direct'  # direct, soft, implied
    emotional_appeal: str = 'balanced'     # logical, emotional, balanced
    key_phrases: List[str] = field(default_factory=list)
    opening_templates: List[str] = field(default_factory=list)
    closing_templates: List[str] = field(default_factory=list)

@dataclass
class ChannelFormat:
    """Format preferences for specific channels."""
    channel: ContentChannel = ContentChannel.EMAIL
    max_length: int = 500
    paragraph_style: str = 'short'  # short, medium, long
    use_bullet_points: bool = False
    use_emojis: bool = False
    greeting_style: str = 'personal'  # personal, formal, none
    signature_style: str = 'full'     # full, short, none

@dataclass 
class ContentSample:
    """A sample of candidate's actual communication."""
    sample_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    content: str = ''
    channel: ContentChannel = ContentChannel.EMAIL
    context: CommunicationContext = CommunicationContext.VOTER_OUTREACH
    performance_score: Optional[float] = None  # If we know how it performed
    created_at: datetime = field(default_factory=datetime.now)
    is_approved: bool = True  # Candidate approved this style

@dataclass
class CommunicationDNA:
    """Complete communication DNA profile for a candidate."""
    dna_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ''
    candidate_name: str = ''
    
    # Core fingerprint
    fingerprint: VoiceFingerprint = field(default_factory=VoiceFingerprint)
    
    # Context-specific styles
    context_styles: Dict[CommunicationContext, ContextStyle] = field(default_factory=dict)
    
    # Channel formats
    channel_formats: Dict[ContentChannel, ChannelFormat] = field(default_factory=dict)
    
    # Issue positions (for consistent messaging)
    issue_talking_points: Dict[str, List[str]] = field(default_factory=dict)
    
    # Samples library
    samples: List[ContentSample] = field(default_factory=list)
    
    # Meta
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    version: int = 1

@dataclass
class AuthenticityScore:
    """Score for how authentic generated content is to candidate's voice."""
    score_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    content: str = ''
    overall_score: float = 0.0
    
    # Component scores
    tone_match: float = 0.0
    vocabulary_match: float = 0.0
    structure_match: float = 0.0
    phrase_match: float = 0.0
    
    # Issues found
    issues: List[str] = field(default_factory=list)
    suggestions: List[str] = field(default_factory=list)
    
    # Rewritten version
    improved_content: Optional[str] = None

# ============================================================================
# DNA ANALYZER
# ============================================================================

class DNAAnalyzer:
    """Analyzes content samples to build voice fingerprint."""
    
    # Common contractions for formality detection
    CONTRACTIONS = [
        "don't", "won't", "can't", "couldn't", "wouldn't", "shouldn't",
        "isn't", "aren't", "wasn't", "weren't", "hasn't", "haven't",
        "I'm", "you're", "we're", "they're", "it's", "that's",
        "I've", "you've", "we've", "they've", "I'll", "you'll",
        "we'll", "they'll", "let's", "here's", "there's", "what's"
    ]
    
    # Southern/NC regional markers
    SOUTHERN_MARKERS = [
        "y'all", "fixing to", "might could", "over yonder", "reckon",
        "bless", "ain't", "folks", "fixin'", "gonna", "wanna"
    ]
    
    # Power words commonly used in political speech
    POWER_WORDS = [
        "fight", "stand", "protect", "freedom", "liberty", "family",
        "community", "together", "future", "children", "promise",
        "commitment", "values", "faith", "strong", "bold", "lead"
    ]
    
    def __init__(self):
        self.word_frequency: Counter = Counter()
        self.phrase_frequency: Counter = Counter()
        self.sentence_lengths: List[int] = []
    
    def analyze_sample(self, sample: ContentSample) -> Dict[str, Any]:
        """Analyze a single content sample."""
        content = sample.content.lower()
        words = re.findall(r'\b\w+\b', content)
        sentences = re.split(r'[.!?]+', sample.content)
        sentences = [s.strip() for s in sentences if s.strip()]
        
        analysis = {
            'word_count': len(words),
            'sentence_count': len(sentences),
            'avg_sentence_length': len(words) / max(len(sentences), 1),
            'unique_words': len(set(words)),
            'vocabulary_richness': len(set(words)) / max(len(words), 1),
            
            # Formality indicators
            'contraction_count': sum(1 for w in self.CONTRACTIONS if w.lower() in content),
            'formal_ratio': self._calculate_formality(content, words),
            
            # Regional markers
            'southern_markers': [m for m in self.SOUTHERN_MARKERS if m in content],
            
            # Power words
            'power_words_used': [w for w in self.POWER_WORDS if w in words],
            
            # Pronouns
            'first_person_singular': content.count(' i ') + content.count("i'm") + content.count("i've"),
            'first_person_plural': content.count(' we ') + content.count("we're") + content.count("we've"),
            
            # Questions
            'question_count': content.count('?'),
            
            # Exclamations (energy)
            'exclamation_count': content.count('!')
        }
        
        # Update counters
        self.word_frequency.update(words)
        self.sentence_lengths.extend([len(s.split()) for s in sentences])
        
        # Extract 2-3 word phrases
        for i in range(len(words) - 2):
            phrase = ' '.join(words[i:i+3])
            self.phrase_frequency[phrase] += 1
        
        return analysis
    
    def _calculate_formality(self, content: str, words: List[str]) -> float:
        """Calculate formality score (0-1)."""
        informal_indicators = 0
        formal_indicators = 0
        
        # Contractions = informal
        for c in self.CONTRACTIONS:
            if c.lower() in content:
                informal_indicators += 1
        
        # Long words = formal
        long_words = sum(1 for w in words if len(w) > 8)
        formal_indicators += long_words / max(len(words), 1) * 10
        
        # Slang/regional = informal
        for m in self.SOUTHERN_MARKERS:
            if m in content:
                informal_indicators += 2
        
        total = informal_indicators + formal_indicators
        if total == 0:
            return 0.5
        
        return formal_indicators / total
    
    def build_fingerprint(
        self,
        samples: List[ContentSample],
        candidate_id: str
    ) -> VoiceFingerprint:
        """Build voice fingerprint from multiple samples."""
        if not samples:
            return VoiceFingerprint(candidate_id=candidate_id)
        
        # Reset counters
        self.word_frequency = Counter()
        self.phrase_frequency = Counter()
        self.sentence_lengths = []
        
        # Analyze all samples
        analyses = [self.analyze_sample(s) for s in samples]
        
        # Aggregate metrics
        avg_formality = sum(a['formal_ratio'] for a in analyses) / len(analyses)
        avg_sentence_length = sum(a['avg_sentence_length'] for a in analyses) / len(analyses)
        
        # Determine vocabulary level
        avg_vocab_richness = sum(a['vocabulary_richness'] for a in analyses) / len(analyses)
        if avg_vocab_richness < 0.4:
            vocab_level = VocabularyLevel.SIMPLE
        elif avg_vocab_richness < 0.6:
            vocab_level = VocabularyLevel.MODERATE
        else:
            vocab_level = VocabularyLevel.SOPHISTICATED
        
        # Determine tone
        total_exclamations = sum(a['exclamation_count'] for a in analyses)
        total_questions = sum(a['question_count'] for a in analyses)
        total_words = sum(a['word_count'] for a in analyses)
        
        energy_level = min(1.0, total_exclamations / max(total_words, 1) * 100)
        
        if avg_formality > 0.7:
            primary_tone = PrimaryTone.PROFESSIONAL
        elif energy_level > 0.5:
            primary_tone = PrimaryTone.PASSIONATE
        elif total_questions / max(len(analyses), 1) > 2:
            primary_tone = PrimaryTone.CONVERSATIONAL
        else:
            primary_tone = PrimaryTone.MEASURED
        
        # Extract favorite phrases (appear in multiple samples)
        common_phrases = [
            phrase for phrase, count in self.phrase_frequency.most_common(20)
            if count >= 2
        ]
        
        # Get power words used
        all_power_words = []
        for a in analyses:
            all_power_words.extend(a['power_words_used'])
        power_word_counts = Counter(all_power_words)
        top_power_words = [w for w, c in power_word_counts.most_common(10)]
        
        # Determine pronoun preference
        total_singular = sum(a['first_person_singular'] for a in analyses)
        total_plural = sum(a['first_person_plural'] for a in analyses)
        uses_we = total_plural > total_singular
        
        # Check for regional dialect
        all_southern = []
        for a in analyses:
            all_southern.extend(a['southern_markers'])
        
        if len(all_southern) > len(samples):
            regional = RegionalDialect.SOUTHERN
        else:
            regional = RegionalDialect.PIEDMONT_NC
        
        fingerprint = VoiceFingerprint(
            candidate_id=candidate_id,
            primary_tone=primary_tone,
            formality_score=avg_formality,
            energy_level=energy_level,
            vocabulary_level=vocab_level,
            avg_sentence_length=avg_sentence_length,
            favorite_phrases=common_phrases[:10],
            power_words=top_power_words,
            uses_first_person_plural=uses_we,
            regional_dialect=regional,
            samples_analyzed=len(samples),
            confidence_score=min(1.0, len(samples) / 10)  # More samples = higher confidence
        )
        
        logger.info(
            f"Built fingerprint for {candidate_id}: {primary_tone.value} tone, "
            f"{vocab_level.value} vocabulary, {len(samples)} samples analyzed"
        )
        
        return fingerprint


# ============================================================================
# DNA MANAGER
# ============================================================================

class CommunicationDNAManager:
    """Manages communication DNA profiles for candidates."""
    
    def __init__(self, supabase_client=None):
        self.supabase = supabase_client
        self.profiles: Dict[str, CommunicationDNA] = {}
        self.analyzer = DNAAnalyzer()
    
    async def create_profile(
        self,
        candidate_id: str,
        candidate_name: str
    ) -> CommunicationDNA:
        """Create a new communication DNA profile."""
        dna = CommunicationDNA(
            candidate_id=candidate_id,
            candidate_name=candidate_name,
            fingerprint=VoiceFingerprint(candidate_id=candidate_id)
        )
        
        # Initialize default context styles
        for context in CommunicationContext:
            dna.context_styles[context] = self._create_default_context_style(context)
        
        # Initialize default channel formats
        for channel in ContentChannel:
            dna.channel_formats[channel] = self._create_default_channel_format(channel)
        
        self.profiles[candidate_id] = dna
        
        if self.supabase:
            await self._save_profile_to_db(dna)
        
        logger.info(f"Created DNA profile for {candidate_name}")
        return dna
    
    def _create_default_context_style(self, context: CommunicationContext) -> ContextStyle:
        """Create default style for a context."""
        defaults = {
            CommunicationContext.FUNDRAISING: ContextStyle(
                context=context,
                urgency_level=0.7,
                call_to_action_style='direct',
                emotional_appeal='emotional',
                key_phrases=['your support', 'make a difference', 'chip in']
            ),
            CommunicationContext.VOTER_OUTREACH: ContextStyle(
                context=context,
                urgency_level=0.5,
                call_to_action_style='soft',
                emotional_appeal='balanced',
                key_phrases=['your voice matters', 'together we can']
            ),
            CommunicationContext.ATTACK_RESPONSE: ContextStyle(
                context=context,
                tone_override=PrimaryTone.AUTHORITATIVE,
                urgency_level=0.6,
                call_to_action_style='direct',
                emotional_appeal='logical',
                key_phrases=['the facts are clear', 'let me be direct']
            ),
            CommunicationContext.THANK_YOU: ContextStyle(
                context=context,
                urgency_level=0.2,
                call_to_action_style='implied',
                emotional_appeal='emotional',
                key_phrases=['grateful', 'blessed', 'humbled']
            ),
            CommunicationContext.CRISIS: ContextStyle(
                context=context,
                tone_override=PrimaryTone.MEASURED,
                urgency_level=0.8,
                call_to_action_style='direct',
                emotional_appeal='logical',
                key_phrases=['we are taking action', 'your safety']
            )
        }
        
        return defaults.get(context, ContextStyle(context=context))
    
    def _create_default_channel_format(self, channel: ContentChannel) -> ChannelFormat:
        """Create default format for a channel."""
        formats = {
            ContentChannel.EMAIL: ChannelFormat(
                channel=channel,
                max_length=800,
                paragraph_style='short',
                greeting_style='personal'
            ),
            ContentChannel.SMS: ChannelFormat(
                channel=channel,
                max_length=160,
                paragraph_style='short',
                greeting_style='none',
                use_emojis=True
            ),
            ContentChannel.RVM: ChannelFormat(
                channel=channel,
                max_length=250,  # ~30 seconds
                paragraph_style='short',
                greeting_style='personal'
            ),
            ContentChannel.SOCIAL_TWITTER: ChannelFormat(
                channel=channel,
                max_length=280,
                paragraph_style='short',
                greeting_style='none',
                use_emojis=True
            ),
            ContentChannel.VIDEO_SCRIPT: ChannelFormat(
                channel=channel,
                max_length=450,  # ~60 seconds
                paragraph_style='medium',
                greeting_style='personal'
            ),
            ContentChannel.DIRECT_MAIL: ChannelFormat(
                channel=channel,
                max_length=1500,
                paragraph_style='medium',
                greeting_style='formal',
                signature_style='full'
            ),
            ContentChannel.SPEECH: ChannelFormat(
                channel=channel,
                max_length=3000,
                paragraph_style='long',
                greeting_style='formal'
            )
        }
        
        return formats.get(channel, ChannelFormat(channel=channel))
    
    async def add_sample(
        self,
        candidate_id: str,
        content: str,
        channel: ContentChannel,
        context: CommunicationContext,
        performance_score: Optional[float] = None
    ) -> ContentSample:
        """Add a content sample and update fingerprint."""
        dna = self.profiles.get(candidate_id)
        if not dna:
            raise ValueError(f"No DNA profile for candidate {candidate_id}")
        
        sample = ContentSample(
            candidate_id=candidate_id,
            content=content,
            channel=channel,
            context=context,
            performance_score=performance_score
        )
        
        dna.samples.append(sample)
        
        # Rebuild fingerprint with new sample
        dna.fingerprint = self.analyzer.build_fingerprint(dna.samples, candidate_id)
        dna.updated_at = datetime.now()
        dna.version += 1
        
        if self.supabase:
            await self._save_sample_to_db(sample)
            await self._save_profile_to_db(dna)
        
        logger.info(f"Added sample for {candidate_id}, fingerprint updated (v{dna.version})")
        return sample
    
    async def set_issue_talking_points(
        self,
        candidate_id: str,
        issue: str,
        talking_points: List[str]
    ):
        """Set talking points for a specific issue."""
        dna = self.profiles.get(candidate_id)
        if not dna:
            raise ValueError(f"No DNA profile for candidate {candidate_id}")
        
        dna.issue_talking_points[issue] = talking_points
        dna.updated_at = datetime.now()
        
        if self.supabase:
            await self._save_profile_to_db(dna)
        
        logger.info(f"Set {len(talking_points)} talking points for {issue}")
    
    def get_style_guide(
        self,
        candidate_id: str,
        channel: ContentChannel,
        context: CommunicationContext
    ) -> Dict[str, Any]:
        """Get complete style guide for content generation."""
        dna = self.profiles.get(candidate_id)
        if not dna:
            return {}
        
        fp = dna.fingerprint
        ctx_style = dna.context_styles.get(context, ContextStyle(context=context))
        ch_format = dna.channel_formats.get(channel, ChannelFormat(channel=channel))
        
        # Determine effective tone
        effective_tone = ctx_style.tone_override or fp.primary_tone
        
        return {
            'candidate': {
                'id': candidate_id,
                'name': dna.candidate_name
            },
            'voice': {
                'primary_tone': effective_tone.value,
                'secondary_tones': [t.value for t in fp.secondary_tones],
                'formality': fp.formality_score,
                'warmth': fp.warmth_score,
                'energy': fp.energy_level,
                'vocabulary_level': fp.vocabulary_level.value,
                'regional_dialect': fp.regional_dialect.value
            },
            'structure': {
                'avg_sentence_length': fp.avg_sentence_length,
                'sentence_structure': fp.sentence_structure.value,
                'max_length': ch_format.max_length,
                'paragraph_style': ch_format.paragraph_style,
                'use_bullet_points': ch_format.use_bullet_points
            },
            'signature_elements': {
                'favorite_phrases': fp.favorite_phrases,
                'power_words': fp.power_words,
                'avoided_words': fp.avoided_words,
                'opener': fp.signature_opener,
                'closer': fp.signature_closer
            },
            'context': {
                'type': context.value,
                'urgency': ctx_style.urgency_level,
                'cta_style': ctx_style.call_to_action_style,
                'emotional_appeal': ctx_style.emotional_appeal,
                'key_phrases': ctx_style.key_phrases
            },
            'format': {
                'channel': channel.value,
                'greeting_style': ch_format.greeting_style,
                'signature_style': ch_format.signature_style,
                'use_emojis': ch_format.use_emojis
            },
            'pronouns': {
                'use_we': fp.uses_first_person_plural,
                'address_style': fp.direct_address_style
            },
            'issue_talking_points': dna.issue_talking_points
        }


# ============================================================================
# AUTHENTICITY SCORER
# ============================================================================

class AuthenticityScorer:
    """Scores generated content for authenticity to candidate voice."""
    
    def __init__(self, dna_manager: CommunicationDNAManager):
        self.dna_manager = dna_manager
    
    def score_content(
        self,
        candidate_id: str,
        content: str,
        channel: ContentChannel,
        context: CommunicationContext
    ) -> AuthenticityScore:
        """Score content authenticity and suggest improvements."""
        dna = self.dna_manager.profiles.get(candidate_id)
        if not dna:
            return AuthenticityScore(content=content, overall_score=0.5)
        
        fp = dna.fingerprint
        issues = []
        suggestions = []
        
        # Analyze content
        words = re.findall(r'\b\w+\b', content.lower())
        sentences = re.split(r'[.!?]+', content)
        sentences = [s.strip() for s in sentences if s.strip()]
        
        # 1. Tone match (25%)
        tone_score = self._score_tone_match(content, fp)
        if tone_score < 0.6:
            issues.append(f"Tone doesn't match {fp.primary_tone.value} style")
            suggestions.append(f"Adjust tone to be more {fp.primary_tone.value}")
        
        # 2. Vocabulary match (25%)
        vocab_score = self._score_vocabulary_match(words, fp)
        if vocab_score < 0.6:
            issues.append("Vocabulary level doesn't match candidate's style")
        
        # 3. Structure match (25%)
        structure_score = self._score_structure_match(sentences, fp)
        if structure_score < 0.6:
            issues.append(
                f"Sentence length should average {fp.avg_sentence_length:.0f} words"
            )
        
        # 4. Phrase match (25%)
        phrase_score = self._score_phrase_match(content, fp)
        if phrase_score < 0.5 and fp.favorite_phrases:
            suggestions.append(
                f"Consider using phrases like: {', '.join(fp.favorite_phrases[:3])}")
        
        # Check for avoided words
        for word in fp.avoided_words:
            if word.lower() in content.lower():
                issues.append(f"Contains avoided word: '{word}'")
                phrase_score -= 0.1
        
        # Check pronoun usage
        if fp.uses_first_person_plural:
            i_count = content.lower().count(' i ')
            we_count = content.lower().count(' we ')
            if i_count > we_count * 2:
                issues.append("Candidate prefers 'we' over 'I'")
                suggestions.append("Replace some 'I' with 'we' for inclusive tone")
        
        overall_score = (tone_score + vocab_score + structure_score + phrase_score) / 4
        
        result = AuthenticityScore(
            content=content,
            overall_score=overall_score,
            tone_match=tone_score,
            vocabulary_match=vocab_score,
            structure_match=structure_score,
            phrase_match=phrase_score,
            issues=issues,
            suggestions=suggestions
        )
        
        # Generate improved version if score is low
        if overall_score < 0.7:
            result.improved_content = self._improve_content(content, dna, result)
        
        return result
    
    def _score_tone_match(self, content: str, fp: VoiceFingerprint) -> float:
        """Score how well content matches expected tone."""
        score = 0.7  # Base score
        
        exclamation_ratio = content.count('!') / max(len(content.split()), 1)
        question_ratio = content.count('?') / max(len(content.split()), 1)
        
        # Check energy level match
        if fp.primary_tone == PrimaryTone.PASSIONATE:
            if exclamation_ratio > 0.05:
                score += 0.2
        elif fp.primary_tone == PrimaryTone.MEASURED:
            if exclamation_ratio < 0.02:
                score += 0.2
        elif fp.primary_tone == PrimaryTone.CONVERSATIONAL:
            if question_ratio > 0.02:
                score += 0.2
        
        # Check formality
        contraction_count = sum(1 for c in DNAAnalyzer.CONTRACTIONS 
                               if c.lower() in content.lower())
        if fp.formality_score < 0.4 and contraction_count > 0:
            score += 0.1
        elif fp.formality_score > 0.7 and contraction_count == 0:
            score += 0.1
        
        return min(1.0, score)
    
    def _score_vocabulary_match(self, words: List[str], fp: VoiceFingerprint) -> float:
        """Score vocabulary level match."""
        avg_word_length = sum(len(w) for w in words) / max(len(words), 1)
        
        expected_avg = {
            VocabularyLevel.SIMPLE: 4.5,
            VocabularyLevel.MODERATE: 5.5,
            VocabularyLevel.SOPHISTICATED: 6.5,
            VocabularyLevel.MIXED: 5.5
        }
        
        target = expected_avg.get(fp.vocabulary_level, 5.5)
        diff = abs(avg_word_length - target)
        
        if diff < 0.5:
            return 1.0
        elif diff < 1.0:
            return 0.8
        elif diff < 1.5:
            return 0.6
        else:
            return 0.4
    
    def _score_structure_match(self, sentences: List[str], fp: VoiceFingerprint) -> float:
        """Score sentence structure match."""
        if not sentences:
            return 0.5
        
        avg_length = sum(len(s.split()) for s in sentences) / len(sentences)
        target = fp.avg_sentence_length
        
        diff = abs(avg_length - target)
        
        if diff < 3:
            return 1.0
        elif diff < 6:
            return 0.8
        elif diff < 10:
            return 0.6
        else:
            return 0.4
    
    def _score_phrase_match(self, content: str, fp: VoiceFingerprint) -> float:
        """Score use of signature phrases."""
        if not fp.favorite_phrases and not fp.power_words:
            return 0.7
        
        content_lower = content.lower()
        
        phrase_matches = sum(1 for p in fp.favorite_phrases if p.lower() in content_lower)
        power_matches = sum(1 for w in fp.power_words if w.lower() in content_lower)
        
        total_signature = len(fp.favorite_phrases) + len(fp.power_words)
        matches = phrase_matches + power_matches
        
        if matches >= 3:
            return 1.0
        elif matches >= 2:
            return 0.8
        elif matches >= 1:
            return 0.6
        else:
            return 0.4
    
    def _improve_content(
        self,
        content: str,
        dna: CommunicationDNA,
        score: AuthenticityScore
    ) -> str:
        """Generate improved version of content."""
        improved = content
        fp = dna.fingerprint
        
        # Replace I with We if needed
        if fp.uses_first_person_plural:
            improved = re.sub(r'\bI am\b', 'We are', improved)
            improved = re.sub(r'\bI have\b', 'We have', improved)
            improved = re.sub(r'\bI will\b', 'We will', improved)
        
        # Add signature closer if missing
        if fp.signature_closer and fp.signature_closer not in improved:
            if not improved.rstrip().endswith(('.', '!', '?')):
                improved += '.'
            improved += f" {fp.signature_closer}"
        
        # Add power word if none present
        if fp.power_words and score.phrase_match < 0.5:
            # Find a good place to insert
            if 'together' not in improved.lower() and 'together' in fp.power_words:
                improved = improved.replace(' can ', ' can work together to ')
        
        return improved


# ============================================================================
# CONTENT GENERATOR INTEGRATION
# ============================================================================

class DNAContentAdapter:
    """Adapts AI-generated content to match candidate DNA."""
    
    def __init__(self, dna_manager: CommunicationDNAManager):
        self.dna_manager = dna_manager
        self.scorer = AuthenticityScorer(dna_manager)
    
    def create_prompt_prefix(
        self,
        candidate_id: str,
        channel: ContentChannel,
        context: CommunicationContext
    ) -> str:
        """Create prompt prefix for AI content generation."""
        style_guide = self.dna_manager.get_style_guide(candidate_id, channel, context)
        
        if not style_guide:
            return ""
        
        voice = style_guide.get('voice', {})
        sig = style_guide.get('signature_elements', {})
        ctx = style_guide.get('context', {})
        fmt = style_guide.get('format', {})
        
        prompt = f"""Write in the voice of {style_guide['candidate']['name']} with these characteristics:

VOICE & TONE:
- Primary tone: {voice.get('primary_tone', 'conversational')}
- Formality level: {'formal' if voice.get('formality', 0.5) > 0.6 else 'casual/conversational'}
- Energy level: {'high energy' if voice.get('energy', 0.5) > 0.6 else 'measured and calm'}
- Regional style: {voice.get('regional_dialect', 'neutral')}

LANGUAGE PREFERENCES:
- Use "{'we' if style_guide.get('pronouns', {}).get('use_we') else 'I'}" as primary pronoun
- Average sentence length: {style_guide['structure'].get('avg_sentence_length', 15):.0f} words
- Vocabulary: {voice.get('vocabulary_level', 'moderate')}

SIGNATURE PHRASES TO INCLUDE:
{', '.join(sig.get('favorite_phrases', [])[:5]) or 'None specified'}

POWER WORDS TO USE:
{', '.join(sig.get('power_words', [])[:5]) or 'None specified'}

CONTEXT: {ctx.get('type', 'general')}
- Urgency level: {'high' if ctx.get('urgency', 0.5) > 0.6 else 'moderate' if ctx.get('urgency', 0.5) > 0.3 else 'low'}
- Call to action style: {ctx.get('cta_style', 'direct')}
- Emotional appeal: {ctx.get('emotional_appeal', 'balanced')}

FORMAT REQUIREMENTS:
- Channel: {fmt.get('channel', 'email')}
- Maximum length: {style_guide['structure'].get('max_length', 500)} characters
- Greeting style: {fmt.get('greeting_style', 'personal')}
- Use emojis: {'Yes' if fmt.get('use_emojis') else 'No'}

"""
        return prompt
    
    async def adapt_content(
        self,
        candidate_id: str,
        content: str,
        channel: ContentChannel,
        context: CommunicationContext,
        min_score: float = 0.7
    ) -> Tuple[str, AuthenticityScore]:
        """Score and potentially improve content to match DNA."""
        score = self.scorer.score_content(candidate_id, content, channel, context)
        
        if score.overall_score >= min_score:
            return content, score
        
        # Use improved version if available
        if score.improved_content:
            improved_score = self.scorer.score_content(
                candidate_id, score.improved_content, channel, context
            )
            if improved_score.overall_score > score.overall_score:
                return score.improved_content, improved_score
        
        return content, score


# ============================================================================
# DATABASE OPERATIONS
# ============================================================================

class DNADatabase:
    """Database operations for Communication DNA."""
    
    def __init__(self, supabase_client):
        self.supabase = supabase_client
    
    async def save_profile(self, dna: CommunicationDNA):
        """Save DNA profile to database."""
        if not self.supabase:
            return
        
        try:
            fp = dna.fingerprint
            await self.supabase.table('e48_communication_dna').upsert({
                'dna_id': dna.dna_id,
                'candidate_id': dna.candidate_id,
                'candidate_name': dna.candidate_name,
                'primary_tone': fp.primary_tone.value,
                'formality_score': fp.formality_score,
                'warmth_score': fp.warmth_score,
                'energy_level': fp.energy_level,
                'vocabulary_level': fp.vocabulary_level.value,
                'avg_sentence_length': fp.avg_sentence_length,
                'favorite_phrases': json.dumps(fp.favorite_phrases),
                'power_words': json.dumps(fp.power_words),
                'avoided_words': json.dumps(fp.avoided_words),
                'uses_first_person_plural': fp.uses_first_person_plural,
                'regional_dialect': fp.regional_dialect.value,
                'samples_analyzed': fp.samples_analyzed,
                'confidence_score': fp.confidence_score,
                'issue_talking_points': json.dumps(dna.issue_talking_points),
                'version': dna.version,
                'updated_at': dna.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save DNA profile: {e}")
    
    async def load_profile(self, candidate_id: str) -> Optional[CommunicationDNA]:
        """Load DNA profile from database."""
        if not self.supabase:
            return None
        
        try:
            result = await self.supabase.table('e48_communication_dna').select('*').eq(
                'candidate_id', candidate_id
            ).single().execute()
            
            if result.data:
                data = result.data
                dna = CommunicationDNA(
                    dna_id=data['dna_id'],
                    candidate_id=data['candidate_id'],
                    candidate_name=data['candidate_name'],
                    version=data['version']
                )
                
                dna.fingerprint = VoiceFingerprint(
                    candidate_id=candidate_id,
                    primary_tone=PrimaryTone(data['primary_tone']),
                    formality_score=data['formality_score'],
                    warmth_score=data['warmth_score'],
                    energy_level=data['energy_level'],
                    vocabulary_level=VocabularyLevel(data['vocabulary_level']),
                    avg_sentence_length=data['avg_sentence_length'],
                    favorite_phrases=json.loads(data['favorite_phrases']),
                    power_words=json.loads(data['power_words']),
                    avoided_words=json.loads(data['avoided_words']),
                    uses_first_person_plural=data['uses_first_person_plural'],
                    regional_dialect=RegionalDialect(data['regional_dialect']),
                    samples_analyzed=data['samples_analyzed'],
                    confidence_score=data['confidence_score']
                )
                
                dna.issue_talking_points = json.loads(data['issue_talking_points'])
                
                return dna
        except Exception as e:
            logger.error(f"Failed to load DNA profile: {e}")
        
        return None


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the communication DNA system."""
    manager = CommunicationDNAManager()
    
    # Create profile for Dave Boliek
    dna = await manager.create_profile(
        candidate_id='dave-boliek-001',
        candidate_name='Dave Boliek'
    )
    
    # Add sample content
    samples = [
        """Friends, we are at a crossroads in North Carolina. Our courts must 
        uphold the Constitution, protect our families, and ensure justice for all.
        Together, we can restore integrity to our judicial system. I'm asking for 
        your support today - will you stand with us?""",
        
        """Thank you so much for your generous contribution! Your support means 
        the world to our campaign. Together, we're building something special here
        in the Tar Heel State. We couldn't do this without neighbors like you.""",
        
        """The radical left wants to pack our courts with activist judges. We won't
        let that happen! Join our fight to protect judicial integrity. Chip in $25
        today and let's send a message they can't ignore!""",
    ]
    
    for sample in samples:
        await manager.add_sample(
            dna.candidate_id,
            sample,
            ContentChannel.EMAIL,
            CommunicationContext.FUNDRAISING
        )
    
    # Set issue talking points
    await manager.set_issue_talking_points(
        dna.candidate_id,
        'judicial_reform',
        [
            "Our courts must uphold the Constitution as written",
            "Judges should interpret law, not make it",
            "Judicial independence protects all North Carolinians",
            "We need experienced, principled judges"
        ]
    )
    
    # Get style guide
    style_guide = manager.get_style_guide(
        dna.candidate_id,
        ContentChannel.EMAIL,
        CommunicationContext.FUNDRAISING
    )
    
    print("\n=== COMMUNICATION DNA STYLE GUIDE ===")
    print(json.dumps(style_guide, indent=2))
    
    # Score some content
    adapter = DNAContentAdapter(manager)
    
    test_content = """I need your help today. I am running for Supreme Court
    and I require donations to win. Please give money now."""
    
    final_content, score = await adapter.adapt_content(
        dna.candidate_id,
        test_content,
        ContentChannel.EMAIL,
        CommunicationContext.FUNDRAISING
    )
    
    print("\n=== AUTHENTICITY SCORE ===")
    print(f"Overall Score: {score.overall_score:.1%}")
    print(f"Tone Match: {score.tone_match:.1%}")
    print(f"Vocabulary Match: {score.vocabulary_match:.1%}")
    print(f"Structure Match: {score.structure_match:.1%}")
    print(f"Phrase Match: {score.phrase_match:.1%}")
    
    if score.issues:
        print("\nIssues Found:")
        for issue in score.issues:
            print(f"  - {issue}")
    
    if score.suggestions:
        print("\nSuggestions:")
        for suggestion in score.suggestions:
            print(f"  - {suggestion}")
    
    if score.improved_content:
        print("\n=== IMPROVED CONTENT ===")
        print(score.improved_content)
    
    # Generate prompt prefix for AI
    prompt_prefix = adapter.create_prompt_prefix(
        dna.candidate_id,
        ContentChannel.RVM,
        CommunicationContext.VOTER_OUTREACH
    )
    
    print("\n=== AI PROMPT PREFIX FOR RVM ===")
    print(prompt_prefix)


if __name__ == '__main__':
    asyncio.run(main())
