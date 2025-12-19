#!/usr/bin/env python3
"""
============================================================================
NEXUS PERSONA ENGINE
============================================================================
Extends E19 PersonalizationEngine with advanced voice matching

INTEGRATIONS:
- E7 Issue Tracking: Candidate-specific issue vocabulary
- E13 AI Hub: Claude-powered content generation
- E19 Social Media Manager: Existing approval workflow
- E20 Intelligence Brain: Trigger control
- E48 Communication DNA: Voice profiles

FEATURES:
- Deep voice signature analysis
- Issue vocabulary mapping from E7
- Platform-specific variations
- ML learning from approval patterns
- Persona match scoring

============================================================================
"""

import os
import json
import uuid
import logging
import hashlib
import re
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from collections import Counter
from enum import Enum

import psycopg2
from psycopg2.extras import RealDictCursor, Json

# Optional: Anthropic for AI generation
try:
    from anthropic import Anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('nexus.persona')


# ============================================================================
# CONFIGURATION
# ============================================================================

class NexusPersonaConfig:
    """NEXUS Persona Engine configuration"""
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
    
    # Model selection
    ANALYSIS_MODEL = "claude-sonnet-4-20250514"
    GENERATION_MODEL = "claude-sonnet-4-20250514"
    
    # Persona thresholds
    MIN_TRAINING_POSTS = 20
    HIGH_CONFIDENCE_THRESHOLD = 75
    MIN_PERSONA_MATCH = 60
    
    # Approval learning
    LEARN_FROM_APPROVALS = True
    LEARN_FROM_EDITS = True
    LEARN_FROM_REJECTIONS = True


# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class VoiceSignature:
    """Multi-dimensional voice profile"""
    formality: float = 5.0       # 1-10: casual to formal
    warmth: float = 5.0          # 1-10: cold to warm
    directness: float = 5.0      # 1-10: indirect to direct
    emotion_intensity: float = 5.0  # 1-10: subdued to intense
    humor_frequency: float = 0.0    # 0-1: frequency of humor
    
    def to_dict(self) -> Dict:
        return {
            'formality': self.formality,
            'warmth': self.warmth,
            'directness': self.directness,
            'emotion_intensity': self.emotion_intensity,
            'humor_frequency': self.humor_frequency
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'VoiceSignature':
        return cls(
            formality=data.get('formality', 5.0),
            warmth=data.get('warmth', 5.0),
            directness=data.get('directness', 5.0),
            emotion_intensity=data.get('emotion_intensity', 5.0),
            humor_frequency=data.get('humor_frequency', 0.0)
        )


@dataclass
class IssueVocabulary:
    """Candidate-specific language for an issue"""
    issue_code: str
    issue_name: str
    preferred_terms: List[str] = field(default_factory=list)
    banned_terms: List[str] = field(default_factory=list)
    talking_points: List[str] = field(default_factory=list)
    emotional_tone: str = "neutral"
    intensity_level: int = 5
    sample_phrases: List[str] = field(default_factory=list)


@dataclass
class PlatformVariation:
    """Platform-specific style adjustments"""
    platform: str
    max_length: int
    hashtag_count: int
    emoji_adjustment: float  # Multiplier for emoji frequency
    tone_adjustment: Dict[str, float] = field(default_factory=dict)
    format_rules: List[str] = field(default_factory=list)


@dataclass
class DraftResult:
    """Generated draft with metadata"""
    option: int
    text: str
    persona_score: float
    confidence: float
    features_used: Dict[str, Any]
    platform_optimized: bool = False


# ============================================================================
# NEXUS PERSONA ENGINE
# ============================================================================

class NexusPersonaEngine:
    """
    Extended PersonalizationEngine with NEXUS intelligence
    
    Integrates with existing E19 workflow while adding:
    - E7 issue vocabulary
    - Enhanced voice signatures
    - ML learning from approvals
    - Platform variations
    """
    
    def __init__(self, db_url: str = None, api_key: str = None):
        self.db_url = db_url or NexusPersonaConfig.DATABASE_URL
        self.api_key = api_key or NexusPersonaConfig.ANTHROPIC_API_KEY
        
        if HAS_ANTHROPIC and self.api_key:
            self.claude = Anthropic(api_key=self.api_key)
        else:
            self.claude = None
        
        logger.info("🎨 NEXUS Persona Engine initialized")
        logger.info("   Integrations: E7, E13, E19, E20, E48")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # VOICE SIGNATURE ANALYSIS
    # ========================================================================
    
    def analyze_voice_signature(self, candidate_id: str) -> VoiceSignature:
        """
        Deep analysis of candidate's voice from existing posts
        Returns multi-dimensional VoiceSignature
        """
        logger.info(f"📊 Analyzing voice signature for {candidate_id}")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get published posts
        cur.execute("""
            SELECT caption, platform, posted_at, engagement_score,
                   approval_method, nexus_persona_match
            FROM social_posts
            WHERE candidate_id = %s
            AND status = 'published'
            ORDER BY posted_at DESC
            LIMIT 200
        """, (candidate_id,))
        
        posts = cur.fetchall()
        conn.close()
        
        if not posts:
            logger.warning(f"   No posts found, using default signature")
            return VoiceSignature()
        
        all_text = ' '.join([p['caption'] for p in posts if p['caption']])
        
        # Calculate each dimension
        formality = self._calculate_formality(posts)
        warmth = self._calculate_warmth(posts)
        directness = self._calculate_directness(posts)
        emotion_intensity = self._calculate_emotion_intensity(posts)
        humor_frequency = self._calculate_humor_frequency(posts)
        
        signature = VoiceSignature(
            formality=formality,
            warmth=warmth,
            directness=directness,
            emotion_intensity=emotion_intensity,
            humor_frequency=humor_frequency
        )
        
        logger.info(f"   Voice signature: F={formality:.1f} W={warmth:.1f} "
                   f"D={directness:.1f} E={emotion_intensity:.1f} H={humor_frequency:.2f}")
        
        return signature
    
    def _calculate_formality(self, posts: List[Dict]) -> float:
        """Calculate formality level (1-10)"""
        informal_markers = ['gonna', 'wanna', 'gotta', 'y\'all', 'folks', 'hey', 'wow', 'lol']
        formal_markers = ['therefore', 'furthermore', 'regarding', 'pursuant', 'hereby']
        
        informal_count = 0
        formal_count = 0
        
        for post in posts:
            text = post['caption'].lower() if post['caption'] else ''
            informal_count += sum(1 for m in informal_markers if m in text)
            formal_count += sum(1 for m in formal_markers if m in text)
        
        # More informal = lower score
        if informal_count + formal_count == 0:
            return 5.0
        
        ratio = formal_count / (informal_count + formal_count + 1)
        return min(10, max(1, 3 + ratio * 7))
    
    def _calculate_warmth(self, posts: List[Dict]) -> float:
        """Calculate warmth level (1-10)"""
        warm_markers = ['thank', 'grateful', 'love', 'appreciate', 'blessed', 
                       'friend', 'family', 'together', 'proud', 'honored']
        cold_markers = ['must', 'demand', 'require', 'failure', 'unacceptable']
        
        warm_count = 0
        cold_count = 0
        
        for post in posts:
            text = post['caption'].lower() if post['caption'] else ''
            warm_count += sum(1 for m in warm_markers if m in text)
            cold_count += sum(1 for m in cold_markers if m in text)
        
        if warm_count + cold_count == 0:
            return 5.0
        
        ratio = warm_count / (warm_count + cold_count + 1)
        return min(10, max(1, 2 + ratio * 8))
    
    def _calculate_directness(self, posts: List[Dict]) -> float:
        """Calculate directness level (1-10)"""
        direct_markers = ['I will', 'We must', 'I\'m going to', 'Let\'s', 
                         'Join me', 'Vote for', 'Support', 'Fight']
        indirect_markers = ['perhaps', 'maybe', 'might', 'could potentially',
                           'it seems', 'some say']
        
        direct_count = 0
        indirect_count = 0
        
        for post in posts:
            text = post['caption'] if post['caption'] else ''
            direct_count += sum(1 for m in direct_markers if m.lower() in text.lower())
            indirect_count += sum(1 for m in indirect_markers if m.lower() in text.lower())
        
        if direct_count + indirect_count == 0:
            return 5.0
        
        ratio = direct_count / (direct_count + indirect_count + 1)
        return min(10, max(1, 2 + ratio * 8))
    
    def _calculate_emotion_intensity(self, posts: List[Dict]) -> float:
        """Calculate emotional intensity (1-10)"""
        # Count exclamation points, caps words, emotional words
        exclamation_count = 0
        caps_count = 0
        intense_words = ['amazing', 'incredible', 'outrageous', 'unbelievable',
                        'devastating', 'critical', 'urgent', 'crisis']
        intense_count = 0
        
        for post in posts:
            text = post['caption'] if post['caption'] else ''
            exclamation_count += text.count('!')
            caps_count += len([w for w in text.split() if w.isupper() and len(w) > 2])
            intense_count += sum(1 for w in intense_words if w in text.lower())
        
        total_posts = len(posts) or 1
        intensity_score = (exclamation_count / total_posts * 2 + 
                          caps_count / total_posts * 1.5 +
                          intense_count / total_posts * 2)
        
        return min(10, max(1, 3 + intensity_score))
    
    def _calculate_humor_frequency(self, posts: List[Dict]) -> float:
        """Calculate humor frequency (0-1)"""
        humor_markers = ['😂', '🤣', 'lol', 'haha', 'joke', '😄', '😆']
        
        humor_posts = 0
        for post in posts:
            text = post['caption'] if post['caption'] else ''
            if any(m in text.lower() for m in humor_markers):
                humor_posts += 1
        
        return humor_posts / len(posts) if posts else 0.0
    
    # ========================================================================
    # ISSUE VOCABULARY (E7 Integration)
    # ========================================================================
    
    def build_issue_vocabulary(self, candidate_id: str) -> Dict[str, IssueVocabulary]:
        """
        Build candidate-specific vocabulary for each E7 issue
        """
        logger.info(f"📚 Building issue vocabulary for {candidate_id}")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get issues from E7 (assuming issues table exists)
        cur.execute("""
            SELECT DISTINCT issue_code, issue_name, talking_points, keywords
            FROM issues
            WHERE is_active = TRUE
            ORDER BY issue_code
        """)
        issues = cur.fetchall()
        
        # Get candidate's posts
        cur.execute("""
            SELECT caption, engagement_score
            FROM social_posts
            WHERE candidate_id = %s AND status = 'published'
        """, (candidate_id,))
        posts = cur.fetchall()
        
        vocabulary = {}
        
        for issue in issues:
            keywords = issue.get('keywords', []) or []
            if isinstance(keywords, str):
                keywords = json.loads(keywords) if keywords else []
            
            # Find posts mentioning this issue
            relevant_posts = []
            for post in posts:
                text = post['caption'].lower() if post['caption'] else ''
                if any(kw.lower() in text for kw in keywords):
                    relevant_posts.append(post)
            
            if relevant_posts:
                # Extract candidate's preferred terms
                preferred_terms = self._extract_issue_terms(relevant_posts, keywords)
                sample_phrases = self._extract_issue_phrases(relevant_posts, keywords)
                emotional_tone = self._detect_issue_tone(relevant_posts)
                
                vocab = IssueVocabulary(
                    issue_code=issue['issue_code'],
                    issue_name=issue['issue_name'],
                    preferred_terms=preferred_terms,
                    talking_points=issue.get('talking_points', []) or [],
                    emotional_tone=emotional_tone,
                    sample_phrases=sample_phrases[:5]
                )
                vocabulary[issue['issue_code']] = vocab
                
                # Store in database
                self._save_issue_mapping(candidate_id, vocab, cur)
        
        conn.commit()
        conn.close()
        
        logger.info(f"   Built vocabulary for {len(vocabulary)} issues")
        return vocabulary
    
    def _extract_issue_terms(self, posts: List[Dict], keywords: List[str]) -> List[str]:
        """Extract terms candidate uses for this issue"""
        word_counts = Counter()
        
        for post in posts:
            text = post['caption'] if post['caption'] else ''
            words = re.findall(r'\b\w+\b', text.lower())
            
            # Count words near keywords
            for i, word in enumerate(words):
                if word in [k.lower() for k in keywords]:
                    # Get surrounding words
                    context = words[max(0, i-3):i+4]
                    for w in context:
                        if len(w) > 3 and w not in ['that', 'this', 'with', 'from', 'have']:
                            word_counts[w] += 1
        
        return [w for w, _ in word_counts.most_common(10)]
    
    def _extract_issue_phrases(self, posts: List[Dict], keywords: List[str]) -> List[str]:
        """Extract phrases candidate uses for this issue"""
        phrases = []
        
        for post in posts:
            text = post['caption'] if post['caption'] else ''
            sentences = re.split(r'[.!?]', text)
            
            for sentence in sentences:
                if any(kw.lower() in sentence.lower() for kw in keywords):
                    clean = sentence.strip()
                    if 10 < len(clean) < 200:
                        phrases.append(clean)
        
        return phrases[:10]
    
    def _detect_issue_tone(self, posts: List[Dict]) -> str:
        """Detect emotional tone for issue"""
        tones = {
            'passionate': ['fight', 'must', 'critical', 'urgent', '!'],
            'compassionate': ['families', 'children', 'help', 'support', 'care'],
            'factual': ['data', 'shows', 'evidence', 'research', 'studies'],
            'angry': ['outrageous', 'unacceptable', 'failed', 'disgrace', 'shame'],
            'hopeful': ['future', 'better', 'together', 'opportunity', 'can']
        }
        
        tone_scores = {tone: 0 for tone in tones}
        
        for post in posts:
            text = post['caption'].lower() if post['caption'] else ''
            for tone, markers in tones.items():
                tone_scores[tone] += sum(1 for m in markers if m in text)
        
        return max(tone_scores, key=tone_scores.get) if any(tone_scores.values()) else 'neutral'
    
    def _save_issue_mapping(self, candidate_id: str, vocab: IssueVocabulary, cur):
        """Save issue vocabulary mapping to database"""
        cur.execute("""
            INSERT INTO nexus_persona_issue_mapping 
            (candidate_id, issue_code, issue_name, preferred_terms, talking_points_used,
             emotional_tone, sample_phrases)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (candidate_id, issue_code) 
            DO UPDATE SET
                preferred_terms = EXCLUDED.preferred_terms,
                emotional_tone = EXCLUDED.emotional_tone,
                sample_phrases = EXCLUDED.sample_phrases,
                updated_at = NOW()
        """, (
            candidate_id,
            vocab.issue_code,
            vocab.issue_name,
            Json(vocab.preferred_terms),
            Json(vocab.talking_points),
            vocab.emotional_tone,
            Json(vocab.sample_phrases)
        ))
    
    # ========================================================================
    # PLATFORM VARIATIONS
    # ========================================================================
    
    def analyze_platform_variations(self, candidate_id: str) -> Dict[str, PlatformVariation]:
        """
        Analyze how candidate's style varies by platform
        """
        logger.info(f"📱 Analyzing platform variations for {candidate_id}")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT platform, 
                   AVG(LENGTH(caption)) as avg_length,
                   AVG(ARRAY_LENGTH(STRING_TO_ARRAY(caption, '#'), 1) - 1) as avg_hashtags,
                   AVG(engagement_score) as avg_engagement
            FROM social_posts
            WHERE candidate_id = %s AND status = 'published'
            GROUP BY platform
        """, (candidate_id,))
        
        platform_stats = cur.fetchall()
        conn.close()
        
        variations = {}
        
        # Default platform configs
        platform_defaults = {
            'facebook': {'max_length': 500, 'hashtag_count': 3},
            'twitter': {'max_length': 280, 'hashtag_count': 2},
            'instagram': {'max_length': 300, 'hashtag_count': 10},
            'linkedin': {'max_length': 700, 'hashtag_count': 3}
        }
        
        for stat in platform_stats:
            platform = stat['platform']
            defaults = platform_defaults.get(platform, {'max_length': 500, 'hashtag_count': 3})
            
            variations[platform] = PlatformVariation(
                platform=platform,
                max_length=int(stat['avg_length'] * 1.2) if stat['avg_length'] else defaults['max_length'],
                hashtag_count=int(stat['avg_hashtags']) if stat['avg_hashtags'] else defaults['hashtag_count'],
                emoji_adjustment=1.0
            )
        
        logger.info(f"   Analyzed {len(variations)} platforms")
        return variations
    
    # ========================================================================
    # ENHANCED PROFILE UPDATE
    # ========================================================================
    
    def enhance_style_profile(self, candidate_id: str) -> Dict[str, Any]:
        """
        Enhance existing E19 candidate_style_profiles with NEXUS intelligence
        """
        logger.info(f"🔄 Enhancing style profile for {candidate_id}")
        
        # Analyze components
        voice_signature = self.analyze_voice_signature(candidate_id)
        issue_vocabulary = self.build_issue_vocabulary(candidate_id)
        platform_variations = self.analyze_platform_variations(candidate_id)
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get training post count
        cur.execute("""
            SELECT COUNT(*) as count FROM social_posts
            WHERE candidate_id = %s AND status = 'published'
        """, (candidate_id,))
        training_count = cur.fetchone()['count']
        
        # Calculate ML confidence based on sample size
        if training_count >= 100:
            ml_confidence = 90.0
        elif training_count >= 50:
            ml_confidence = 75.0
        elif training_count >= 20:
            ml_confidence = 60.0
        else:
            ml_confidence = 40.0
        
        # Update candidate_style_profiles with NEXUS columns
        cur.execute("""
            UPDATE candidate_style_profiles
            SET 
                nexus_voice_signature = %s,
                nexus_issue_vocabulary = %s,
                nexus_platform_variations = %s,
                nexus_training_posts_count = %s,
                nexus_last_trained = NOW(),
                nexus_ml_confidence = %s,
                updated_at = NOW()
            WHERE candidate_id = %s
        """, (
            Json(voice_signature.to_dict()),
            Json({k: {
                'preferred_terms': v.preferred_terms,
                'emotional_tone': v.emotional_tone,
                'sample_phrases': v.sample_phrases
            } for k, v in issue_vocabulary.items()}),
            Json({k: {
                'max_length': v.max_length,
                'hashtag_count': v.hashtag_count,
                'emoji_adjustment': v.emoji_adjustment
            } for k, v in platform_variations.items()}),
            training_count,
            ml_confidence,
            candidate_id
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"   Profile enhanced: {training_count} samples, {ml_confidence:.0f}% confidence")
        
        return {
            'candidate_id': candidate_id,
            'voice_signature': voice_signature.to_dict(),
            'issue_count': len(issue_vocabulary),
            'platform_count': len(platform_variations),
            'training_count': training_count,
            'ml_confidence': ml_confidence
        }
    
    # ========================================================================
    # DRAFT GENERATION (Follows E19 Protocol)
    # ========================================================================
    
    def generate_drafts(self, candidate_id: str, event: Dict, count: int = 3) -> List[DraftResult]:
        """
        Generate draft posts for E19 approval workflow
        
        Returns 3 options as per existing protocol
        """
        logger.info(f"✍️ Generating {count} drafts for {candidate_id}")
        
        # Load enhanced profile
        profile = self._load_enhanced_profile(candidate_id)
        
        if not profile:
            logger.warning(f"   No profile found, enhancing now...")
            self.enhance_style_profile(candidate_id)
            profile = self._load_enhanced_profile(candidate_id)
        
        drafts = []
        
        for i in range(count):
            # Generate with variation
            draft_text = self._generate_single_draft(profile, event, variation=i)
            
            # Calculate persona match score
            persona_score = self._calculate_persona_score(draft_text, profile)
            
            # Add human touches if high confidence
            if profile.get('nexus_ml_confidence', 0) >= 70:
                draft_text = self._add_human_touches(draft_text, profile)
            
            drafts.append(DraftResult(
                option=i + 1,
                text=draft_text,
                persona_score=persona_score,
                confidence=profile.get('nexus_ml_confidence', 50),
                features_used={
                    'voice_signature': True,
                    'issue_vocabulary': event.get('issue_code') in (profile.get('nexus_issue_vocabulary') or {}),
                    'platform_optimized': True
                }
            ))
        
        # Sort by persona score (best first)
        drafts.sort(key=lambda x: x.persona_score, reverse=True)
        
        # Re-number after sort
        for i, draft in enumerate(drafts):
            draft.option = i + 1
        
        logger.info(f"   Generated drafts with scores: {[f'{d.persona_score:.0f}' for d in drafts]}")
        
        return drafts
    
    def _load_enhanced_profile(self, candidate_id: str) -> Optional[Dict]:
        """Load enhanced profile from database"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT csp.*, 
                   c.first_name, c.last_name, c.office_sought
            FROM candidate_style_profiles csp
            JOIN candidates c ON csp.candidate_id = c.candidate_id
            WHERE csp.candidate_id = %s
        """, (candidate_id,))
        
        profile = cur.fetchone()
        conn.close()
        
        return dict(profile) if profile else None
    
    def _generate_single_draft(self, profile: Dict, event: Dict, variation: int) -> str:
        """Generate a single draft variation"""
        
        if self.claude:
            return self._generate_with_claude(profile, event, variation)
        else:
            return self._generate_template_based(profile, event, variation)
    
    def _generate_with_claude(self, profile: Dict, event: Dict, variation: int) -> str:
        """Generate draft using Claude API via E13 AI Hub"""
        
        # Build prompt with persona details
        voice_sig = profile.get('nexus_voice_signature', {})
        common_phrases = profile.get('common_phrases', []) or []
        
        variation_instructions = {
            0: "Make it direct and action-oriented",
            1: "Make it more personal and story-driven", 
            2: "Make it factual with a call to action"
        }
        
        prompt = f"""Generate a social media post for a political candidate.

CANDIDATE: {profile.get('first_name', '')} {profile.get('last_name', '')}
OFFICE: {profile.get('office_sought', '')}

EVENT TO RESPOND TO:
{event.get('title', '')}
{event.get('summary', '')}

CANDIDATE'S VOICE PROFILE:
- Formality level: {voice_sig.get('formality', 5)}/10
- Warmth level: {voice_sig.get('warmth', 5)}/10  
- Directness: {voice_sig.get('directness', 5)}/10
- Emotional intensity: {voice_sig.get('emotion_intensity', 5)}/10

CANDIDATE'S COMMON PHRASES: {', '.join(common_phrases[:5]) if common_phrases else 'None available'}

STYLE NOTES:
- Average sentence length: {profile.get('avg_sentence_length', 15)} words
- Uses emojis: {profile.get('uses_emojis', False)}
- Uses exclamations: {profile.get('uses_exclamations_pct', 0.3) > 0.3}

VARIATION: {variation_instructions.get(variation, '')}

Generate ONLY the post text, no explanations. Keep under 280 characters for Twitter compatibility.
Match the candidate's voice as closely as possible."""

        try:
            response = self.claude.messages.create(
                model=NexusPersonaConfig.GENERATION_MODEL,
                max_tokens=500,
                messages=[{"role": "user", "content": prompt}]
            )
            return response.content[0].text.strip()
        except Exception as e:
            logger.error(f"Claude API error: {e}")
            return self._generate_template_based(profile, event, variation)
    
    def _generate_template_based(self, profile: Dict, event: Dict, variation: int) -> str:
        """Fallback template-based generation"""
        
        first_name = profile.get('first_name', 'I')
        opening_lines = profile.get('opening_lines', []) or ['']
        closing_lines = profile.get('closing_lines', []) or ['']
        
        templates = [
            f"{opening_lines[0] if opening_lines else 'Folks,'} {event.get('title', '')}. "
            f"This is why I'm fighting for NC families. {closing_lines[0] if closing_lines else ''}",
            
            f"Just learned about {event.get('title', '')}. "
            f"As your representative, I'm committed to addressing this. Together, we can make a difference!",
            
            f"{event.get('title', '')} - this matters to every family in our district. "
            f"I'm {first_name}, and I approve this message because your voice deserves to be heard."
        ]
        
        return templates[variation % len(templates)]
    
    def _calculate_persona_score(self, text: str, profile: Dict) -> float:
        """Calculate how well text matches candidate's persona"""
        score = 50.0  # Base score
        
        # Check common phrases
        common_phrases = profile.get('common_phrases', []) or []
        phrase_matches = sum(1 for p in common_phrases if p.lower() in text.lower())
        score += min(phrase_matches * 5, 15)
        
        # Check signature words
        signature_words = profile.get('signature_words', []) or []
        word_matches = sum(1 for w in signature_words if w.lower() in text.lower())
        score += min(word_matches * 3, 10)
        
        # Check length alignment
        avg_length = profile.get('avg_post_length', 200)
        if avg_length:
            length_diff = abs(len(text) - avg_length)
            if length_diff < 50:
                score += 10
            elif length_diff < 100:
                score += 5
        
        # Check emoji usage alignment
        uses_emojis = profile.get('uses_emojis', False)
        has_emojis = bool(re.search(r'[😀-🙏🇦-🇿]', text))
        if uses_emojis == has_emojis:
            score += 5
        
        # Check exclamation alignment
        excl_pct = profile.get('uses_exclamations_pct', 0.5)
        has_excl = '!' in text
        if (excl_pct > 0.3) == has_excl:
            score += 5
        
        # Check voice signature alignment
        voice_sig = profile.get('nexus_voice_signature', {})
        if voice_sig:
            # High warmth profile should have warm words
            if voice_sig.get('warmth', 5) > 7:
                warm_words = ['thank', 'grateful', 'together', 'family']
                if any(w in text.lower() for w in warm_words):
                    score += 5
            
            # High directness should have calls to action
            if voice_sig.get('directness', 5) > 7:
                direct_words = ['join', 'vote', 'support', 'donate', 'act']
                if any(w in text.lower() for w in direct_words):
                    score += 5
        
        return min(100, max(0, score))
    
    def _add_human_touches(self, text: str, profile: Dict) -> str:
        """Add subtle human imperfections to avoid AI detection"""
        
        # Only apply if confidence is high enough
        import random
        
        # Occasionally add common filler words the candidate uses
        opening_lines = profile.get('opening_lines', [])
        if opening_lines and random.random() < 0.3:
            opener = random.choice(opening_lines)
            if opener and not text.startswith(opener):
                text = f"{opener} {text}"
        
        # Match emoji style
        favorite_emojis = profile.get('favorite_emojis', [])
        if favorite_emojis and profile.get('uses_emojis', False):
            if not re.search(r'[😀-🙏🇦-🇿]', text) and random.random() < 0.4:
                text = f"{text} {random.choice(favorite_emojis)}"
        
        return text
    
    # ========================================================================
    # APPROVAL LEARNING (ML Feedback Loop)
    # ========================================================================
    
    def learn_from_approval(self, approval_request_id: str):
        """
        Learn from candidate's approval decision to improve future drafts
        """
        logger.info(f"📖 Learning from approval {approval_request_id}")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get approval request details
        cur.execute("""
            SELECT sar.*, sp.caption as final_text, sp.engagement_score
            FROM social_approval_requests sar
            LEFT JOIN social_posts sp ON sar.approval_request_id = sp.approval_request_id
            WHERE sar.approval_request_id = %s
        """, (approval_request_id,))
        
        approval = cur.fetchone()
        
        if not approval:
            logger.warning(f"   Approval request not found")
            conn.close()
            return
        
        candidate_id = approval['candidate_id']
        outcome = approval['status']
        selected_option = approval.get('selected_option')
        draft_posts = approval.get('draft_posts', [])
        final_post = approval.get('final_post', {})
        response_text = approval.get('response_text', '')
        
        # Analyze what we can learn
        learning = {
            'outcome': outcome,
            'selected_option': selected_option,
            'patterns_identified': [],
            'preferences_updated': []
        }
        
        if outcome == 'approved' and selected_option:
            # Learn which option style was preferred
            if draft_posts and len(draft_posts) >= selected_option:
                preferred_draft = draft_posts[selected_option - 1]
                learning['patterns_identified'].append({
                    'type': 'preferred_style',
                    'option': selected_option,
                    'features': self._extract_text_features(preferred_draft.get('text', ''))
                })
        
        elif outcome == 'edited':
            # Learn from the edits
            original = draft_posts[0] if draft_posts else {}
            edited = response_text or final_post.get('caption', '')
            
            if original and edited:
                edit_analysis = self._analyze_edits(
                    original.get('text', ''),
                    edited
                )
                learning['edit_analysis'] = edit_analysis
                learning['patterns_identified'].append({
                    'type': 'edit_preference',
                    'changes': edit_analysis
                })
        
        elif outcome == 'rejected':
            # Learn what to avoid
            if draft_posts:
                for draft in draft_posts:
                    features = self._extract_text_features(draft.get('text', ''))
                    learning['patterns_identified'].append({
                        'type': 'rejected_features',
                        'features': features
                    })
        
        # Save learning to database
        cur.execute("""
            INSERT INTO nexus_approval_learning
            (candidate_id, approval_request_id, outcome, selected_option,
             patterns_identified, applied_to_profile)
            VALUES (%s, %s, %s, %s, %s, FALSE)
        """, (
            candidate_id,
            approval_request_id,
            outcome,
            selected_option,
            Json(learning['patterns_identified'])
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"   Learned: {outcome}, patterns: {len(learning['patterns_identified'])}")
    
    def _extract_text_features(self, text: str) -> Dict:
        """Extract features from text for learning"""
        return {
            'length': len(text),
            'word_count': len(text.split()),
            'has_exclamation': '!' in text,
            'has_question': '?' in text,
            'has_emoji': bool(re.search(r'[😀-🙏]', text)),
            'hashtag_count': text.count('#'),
            'sentence_count': len(re.split(r'[.!?]', text))
        }
    
    def _analyze_edits(self, original: str, edited: str) -> Dict:
        """Analyze what changed between original and edited version"""
        original_words = set(original.lower().split())
        edited_words = set(edited.lower().split())
        
        return {
            'words_added': list(edited_words - original_words)[:10],
            'words_removed': list(original_words - edited_words)[:10],
            'length_change': len(edited) - len(original),
            'significant_rewrite': len(edited_words & original_words) < len(original_words) * 0.5
        }
    
    # ========================================================================
    # HELPER: CREATE APPROVAL REQUEST (E19 Integration)
    # ========================================================================
    
    def create_approval_request(self, candidate_id: str, event_id: str, 
                                platform: str = 'facebook') -> str:
        """
        Create social_approval_requests entry following E19 protocol
        
        Returns approval_request_id
        """
        logger.info(f"📝 Creating approval request for {candidate_id}")
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get event details
        cur.execute("""
            SELECT * FROM intelligence_brain_events WHERE event_id = %s
        """, (event_id,))
        event = cur.fetchone()
        
        if not event:
            conn.close()
            raise ValueError(f"Event {event_id} not found")
        
        # Generate 3 drafts
        drafts = self.generate_drafts(candidate_id, dict(event), count=3)
        
        # Calculate average persona score
        avg_persona_score = sum(d.persona_score for d in drafts) / len(drafts)
        avg_confidence = sum(d.confidence for d in drafts) / len(drafts)
        
        # Get candidate's auto-approve deadline (default 11 PM)
        deadline = datetime.now().replace(hour=23, minute=0, second=0)
        if datetime.now().hour >= 23:
            deadline += timedelta(days=1)
        
        # Create approval request
        approval_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO social_approval_requests
            (approval_request_id, candidate_id, event_id, draft_posts, status,
             auto_approve_deadline, nexus_trigger_type, nexus_persona_score, nexus_confidence)
            VALUES (%s, %s, %s, %s, 'pending', %s, %s, %s, %s)
            RETURNING approval_request_id
        """, (
            approval_id,
            candidate_id,
            event_id,
            Json([{
                'option': d.option,
                'text': d.text,
                'persona_score': d.persona_score,
                'platform': platform
            } for d in drafts]),
            deadline,
            'nexus_generated',
            avg_persona_score,
            avg_confidence
        ))
        
        # Create brain trigger record
        cur.execute("""
            INSERT INTO nexus_brain_triggers
            (trigger_type, source_table, source_record_id, brain_decision, brain_score,
             action_type, approval_request_id, decided_at)
            VALUES ('social_post', 'intelligence_brain_events', %s, 'go', %s,
                    'create_approval', %s, NOW())
        """, (event_id, int(avg_persona_score), approval_id))
        
        conn.commit()
        conn.close()
        
        logger.info(f"   Created approval request {approval_id}")
        logger.info(f"   Persona scores: {[f'{d.persona_score:.0f}' for d in drafts]}")
        
        return approval_id


# ============================================================================
# STANDALONE EXECUTION
# ============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("NEXUS PERSONA ENGINE")
    print("Extends E19 PersonalizationEngine with advanced voice matching")
    print("=" * 70)
    
    engine = NexusPersonaEngine()
    
    # Example usage
    print("\nExample: Enhance candidate profile")
    print("  engine.enhance_style_profile('candidate-uuid')")
    
    print("\nExample: Generate drafts for approval")
    print("  drafts = engine.generate_drafts('candidate-uuid', event_dict)")
    
    print("\nExample: Create approval request (E19 protocol)")
    print("  approval_id = engine.create_approval_request('candidate-uuid', 'event-uuid')")
    
    print("\nExample: Learn from approval decision")
    print("  engine.learn_from_approval('approval-request-uuid')")
