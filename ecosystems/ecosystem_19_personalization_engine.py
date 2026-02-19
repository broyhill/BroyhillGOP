import logging
import os

# === LOGGING CONFIGURATION (Auto-added by repair tool) ===
log_level = os.getenv('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)
# === END LOGGING ===

# ecosystem_19_personalization_engine.py
# BROYHILLGOP - AI Content Personalization Engine
# ECOSYSTEM 19: Social Media Manager - Voice Matching Component
# Learns each candidate's unique voice, style, and patterns

"""
ECOSYSTEM 19: PERSONALIZATION ENGINE
====================================
Part of Social Media Manager subsystem
Makes AI-generated content indistinguishable from candidate's own writing

INTEGRATIONS:
- E0 DataHub: Stores voice profiles
- E13 AI Hub: Claude API for analysis and generation
- E19 Social Media Manager: Provides voice-matched content

KEY FEATURES:
- Analyzes 100+ existing posts per candidate
- Learns vocabulary, tone, emoji patterns
- Adds "human imperfections" to avoid AI detection
- Updates profiles monthly for accuracy
"""

import asyncio
import psycopg2
from anthropic import Anthropic
from datetime import datetime
import json
import re
from typing import Dict, List, Optional
import random
from collections import Counter

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 19PersonalizationEngineError(Exception):
    """Base exception for this ecosystem"""
    pass

class 19PersonalizationEngineValidationError(19PersonalizationEngineError):
    """Validation error in this ecosystem"""
    pass

class 19PersonalizationEngineDatabaseError(19PersonalizationEngineError):
    """Database error in this ecosystem"""
    pass

class 19PersonalizationEngineAPIError(19PersonalizationEngineError):
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
class 19PersonalizationEngineError(Exception):
    """Base exception for this ecosystem"""
    pass

class 19PersonalizationEngineValidationError(19PersonalizationEngineError):
    """Validation error in this ecosystem"""
    pass

class 19PersonalizationEngineDatabaseError(19PersonalizationEngineError):
    """Database error in this ecosystem"""
    pass

class 19PersonalizationEngineAPIError(19PersonalizationEngineError):
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



class PersonalizationEngine:
    """
    Learn and replicate each candidate's unique writing style
    
    Makes AI-generated content indistinguishable from candidate's own posts
    """
    
    def __init__(self, db_config, claude_api_key):
        # Database (E0 DataHub)
        self.db = psycopg2.connect(**db_config)
        
        # AI (E13 AI Hub)
        self.claude = Anthropic(api_key=claude_api_key)
        
        print("🎨 Ecosystem 19: Personalization Engine - Initialized")
        print("🔗 Connected to: E0 DataHub, E13 AI Hub\n")
    
    def analyze_candidate_voice(self, candidate_id: str) -> dict:
        """
        Deep analysis of candidate's existing social media posts
        
        Returns comprehensive style profile
        """
        
        print(f"📊 Analyzing voice for candidate: {candidate_id}")
        
        # Get last 100 posts from candidate
        cur = self.db.cursor()
        cur.execute("""
            SELECT caption, platform, posted_at, engagement_score
            FROM social_posts
            WHERE candidate_id = %s
            AND status = 'published'
            ORDER BY posted_at DESC
            LIMIT 100
        """, (candidate_id,))
        
        posts = cur.fetchall()
        
        if not posts:
            print("   ⚠️ No existing posts found, using default profile")
            return self.create_default_profile(candidate_id)
        
        print(f"   📝 Analyzing {len(posts)} posts...")
        
        # Extract patterns
        all_text = ' '.join([post[0] for post in posts])
        
        style_profile = {
            'candidate_id': candidate_id,
            'analyzed_at': datetime.now().isoformat(),
            'sample_size': len(posts),
            
            # WRITING PATTERNS
            'sentence_structure': self.analyze_sentence_structure(posts),
            'paragraph_length': self.analyze_paragraph_length(posts),
            'punctuation_style': self.analyze_punctuation(all_text),
            'capitalization_patterns': self.analyze_caps(all_text),
            
            # VOCABULARY
            'common_phrases': self.extract_common_phrases(posts),
            'signature_words': self.extract_signature_words(all_text),
            'opening_lines': self.extract_opening_patterns(posts),
            'closing_lines': self.extract_closing_patterns(posts),
            
            # EMOTIONAL TONE
            'primary_emotions': self.detect_primary_emotions(posts),
            'intensity_level': self.measure_intensity(all_text),
            'formality_level': self.measure_formality(all_text),
            
            # FORMATTING
            'emoji_usage': self.analyze_emoji_usage(all_text),
            'hashtag_patterns': self.analyze_hashtag_usage(posts),
            'link_placement': self.analyze_link_placement(posts),
            'emphasis_style': self.analyze_emphasis(all_text),
            
            # CONTENT THEMES
            'favorite_topics': self.extract_favorite_topics(posts),
            'typical_cta': self.extract_cta_patterns(posts),
            'personal_references': self.extract_personal_refs(all_text),
            
            # TIMING
            'preferred_post_times': self.analyze_post_times(posts),
            'post_frequency': self.calculate_frequency(posts)
        }
        
        # Store profile in E0 DataHub
        self.save_voice_profile(candidate_id, style_profile)
        
        print(f"   ✅ Voice profile complete")
        print(f"      Common phrases: {len(style_profile['common_phrases'])}")
        print(f"      Emoji usage: {style_profile['emoji_usage'].get('uses_emojis', False)}")
        print(f"      Formality: {style_profile['formality_level']}/10")
        
        return style_profile
    
    def analyze_sentence_structure(self, posts: List) -> dict:
        """Analyze how candidate structures sentences"""
        
        all_sentences = []
        for post in posts:
            sentences = re.split(r'[.!?]+', post[0])
            all_sentences.extend([s.strip() for s in sentences if s.strip()])
        
        if not all_sentences:
            return {
                'avg_length': 15,
                'uses_fragments': False,
                'uses_questions': 0.3,
                'uses_exclamations': 0.5
            }
        
        return {
            'avg_length': sum(len(s.split()) for s in all_sentences) / len(all_sentences),
            'uses_fragments': sum(1 for s in all_sentences if len(s.split()) <= 3) > len(all_sentences) * 0.1,
            'uses_questions': sum(1 for post in posts if '?' in post[0]) / len(posts),
            'uses_exclamations': sum(1 for post in posts if '!' in post[0]) / len(posts)
        }
    
    def analyze_paragraph_length(self, posts: List) -> dict:
        """Analyze paragraph structure"""
        
        lengths = []
        for post in posts:
            paragraphs = post[0].split('\n\n')
            lengths.extend([len(p.split()) for p in paragraphs if p.strip()])
        
        if not lengths:
            return {'avg_words': 30, 'max_words': 50}
        
        return {
            'avg_words': sum(lengths) / len(lengths),
            'max_words': max(lengths)
        }
    
    def analyze_punctuation(self, text: str) -> dict:
        """Analyze punctuation patterns"""
        return {
            'exclamation_freq': text.count('!') / max(len(text.split()), 1),
            'question_freq': text.count('?') / max(len(text.split()), 1),
            'ellipsis_freq': text.count('...') / max(len(text.split()), 1),
            'uses_oxford_comma': ', and' in text.lower()
        }
    
    def analyze_caps(self, text: str) -> dict:
        """Analyze capitalization patterns"""
        words = text.split()
        caps_words = [w for w in words if w.isupper() and len(w) > 2]
        
        return {
            'uses_all_caps': len(caps_words) > 5,
            'all_caps_frequency': len(caps_words) / max(len(words), 1),
            'common_caps_words': [w for w, _ in Counter(caps_words).most_common(5)]
        }
    
    def analyze_emoji_usage(self, text: str) -> dict:
        """Learn emoji patterns"""
        
        emoji_pattern = re.compile("[" 
            u"\U0001F600-\U0001F64F"
            u"\U0001F300-\U0001F5FF"
            u"\U0001F680-\U0001F6FF"
            u"\U0001F1E0-\U0001F1FF"
            "]+", flags=re.UNICODE)
        
        emojis = emoji_pattern.findall(text)
        
        if not emojis:
            return {'uses_emojis': False}
        
        emoji_freq = Counter(emojis)
        
        return {
            'uses_emojis': True,
            'frequency': len(emojis) / max(len(text.split('\n\n')), 1),
            'favorite_emojis': [e for e, _ in emoji_freq.most_common(5)],
            'placement': self.detect_emoji_placement(text)
        }
    
    def detect_emoji_placement(self, text: str) -> str:
        """Detect where emojis typically appear"""
        lines = text.split('\n')
        end_count = 0
        inline_count = 0
        
        emoji_pattern = re.compile("[" 
            u"\U0001F600-\U0001F64F"
            u"\U0001F300-\U0001F5FF"
            u"\U0001F680-\U0001F6FF"
            u"\U0001F1E0-\U0001F1FF"
            "]+", flags=re.UNICODE)
        
        for line in lines:
            if emoji_pattern.search(line):
                if emoji_pattern.search(line[-5:]):
                    end_count += 1
                else:
                    inline_count += 1
        
        if end_count > inline_count:
            return 'end'
        elif inline_count > end_count:
            return 'inline'
        return 'both'
    
    def extract_common_phrases(self, posts: List) -> List[str]:
        """Extract signature phrases candidate uses repeatedly"""
        
        all_text = ' '.join([post[0] for post in posts]).lower()
        words = all_text.split()
        phrases = []
        
        for length in [2, 3, 4, 5]:
            for i in range(len(words) - length):
                phrase = ' '.join(words[i:i+length])
                if all_text.count(phrase) >= 3:
                    if phrase not in phrases:
                        phrases.append(phrase)
        
        return phrases[:20]
    
    def extract_signature_words(self, text: str) -> List[str]:
        """Extract unique vocabulary"""
        words = re.findall(r'\b[a-z]{4,}\b', text.lower())
        freq = Counter(words)
        
        # Filter out common words
        common = {'that', 'this', 'with', 'have', 'from', 'they', 'will', 'your', 'about', 'more'}
        
        return [w for w, _ in freq.most_common(30) if w not in common][:15]
    
    def extract_opening_patterns(self, posts: List) -> List[str]:
        """How does candidate typically start posts?"""
        
        openings = []
        for post in posts:
            first_sentence = post[0].split('.')[0].strip()
            if len(first_sentence.split()) <= 10:
                openings.append(first_sentence)
        
        return [o for o, _ in Counter(openings).most_common(10)]
    
    def extract_closing_patterns(self, posts: List) -> List[str]:
        """How does candidate typically end posts?"""
        
        closings = []
        for post in posts:
            sentences = [s.strip() for s in post[0].split('.') if s.strip()]
            if sentences:
                last = sentences[-1]
                if len(last.split()) <= 15:
                    closings.append(last)
        
        return [c for c, _ in Counter(closings).most_common(10)]
    
    def detect_primary_emotions(self, posts: List) -> List[str]:
        """Detect emotional tone"""
        
        emotion_keywords = {
            'determined': ['fight', 'must', 'will', 'stand', 'demand'],
            'hopeful': ['together', 'future', 'hope', 'better', 'believe'],
            'urgent': ['now', 'today', 'immediately', 'critical', 'urgent'],
            'outraged': ['unacceptable', 'outrage', 'disgusting', 'wrong', 'scandal'],
            'proud': ['proud', 'honor', 'privilege', 'grateful', 'blessed']
        }
        
        all_text = ' '.join([post[0] for post in posts]).lower()
        
        emotion_scores = {}
        for emotion, keywords in emotion_keywords.items():
            score = sum(all_text.count(kw) for kw in keywords)
            emotion_scores[emotion] = score
        
        sorted_emotions = sorted(emotion_scores.items(), key=lambda x: x[1], reverse=True)
        return [e for e, _ in sorted_emotions[:3]]
    
    def measure_intensity(self, text: str) -> int:
        """Measure emotional intensity (1-10)"""
        
        intensity_markers = ['!', '!!', 'MUST', 'NOW', 'URGENT', 'CRITICAL']
        score = sum(text.count(m) for m in intensity_markers)
        
        return min(10, max(1, score // 5 + 5))
    
    def measure_formality(self, text: str) -> int:
        """Measure formality level (1-10)"""
        
        informal_markers = ["i'm", "we're", "you're", "can't", "won't", "folks", "gonna", "wanna"]
        formal_markers = ["therefore", "furthermore", "consequently", "regarding", "pursuant"]
        
        informal_count = sum(text.lower().count(m) for m in informal_markers)
        formal_count = sum(text.lower().count(m) for m in formal_markers)
        
        if formal_count > informal_count:
            return min(10, 7 + formal_count)
        else:
            return max(1, 5 - informal_count)
    
    def analyze_hashtag_usage(self, posts: List) -> dict:
        """Analyze hashtag patterns"""
        
        hashtag_counts = []
        all_hashtags = []
        
        for post in posts:
            hashtags = re.findall(r'#\w+', post[0])
            hashtag_counts.append(len(hashtags))
            all_hashtags.extend(hashtags)
        
        if not hashtag_counts:
            return {'avg_count': 3, 'placement': 'end', 'typical_hashtags': []}
        
        return {
            'avg_count': sum(hashtag_counts) / len(hashtag_counts),
            'placement': 'end',  # Most common
            'typical_hashtags': [h for h, _ in Counter(all_hashtags).most_common(10)]
        }
    
    def analyze_link_placement(self, posts: List) -> dict:
        """Analyze how links are placed"""
        return {'typical_position': 'end', 'uses_link_preview': True}
    
    def analyze_emphasis(self, text: str) -> dict:
        """Analyze emphasis style (caps, bold, etc.)"""
        return {
            'uses_caps': bool(re.search(r'\b[A-Z]{3,}\b', text)),
            'uses_bold': '**' in text or '__' in text,
            'emphasis_frequency': len(re.findall(r'\b[A-Z]{3,}\b', text)) / max(len(text.split()), 1)
        }
    
    def extract_favorite_topics(self, posts: List) -> List[str]:
        """Extract commonly discussed topics"""
        
        topic_keywords = {
            'economy': ['jobs', 'economy', 'taxes', 'business', 'inflation'],
            'education': ['school', 'education', 'students', 'teachers', 'parents'],
            'safety': ['crime', 'police', 'safety', 'security', 'border'],
            'healthcare': ['health', 'hospital', 'doctors', 'medicine', 'insurance'],
            'faith': ['god', 'faith', 'church', 'prayer', 'blessed']
        }
        
        all_text = ' '.join([post[0] for post in posts]).lower()
        
        topic_scores = {}
        for topic, keywords in topic_keywords.items():
            score = sum(all_text.count(kw) for kw in keywords)
            topic_scores[topic] = score
        
        return [t for t, _ in sorted(topic_scores.items(), key=lambda x: x[1], reverse=True)[:5]]
    
    def extract_cta_patterns(self, posts: List) -> str:
        """Extract typical call-to-action style"""
        
        cta_patterns = {
            'donate': ['donate', 'chip in', 'contribute', 'give'],
            'volunteer': ['volunteer', 'join us', 'sign up', 'get involved'],
            'share': ['share', 'spread the word', 'tell your friends'],
            'vote': ['vote', 'get out and vote', 'election day']
        }
        
        all_text = ' '.join([post[0] for post in posts]).lower()
        
        cta_scores = {}
        for cta, patterns in cta_patterns.items():
            score = sum(all_text.count(p) for p in patterns)
            cta_scores[cta] = score
        
        top_cta = max(cta_scores.items(), key=lambda x: x[1])[0]
        return f"Primary CTA: {top_cta}"
    
    def extract_personal_refs(self, text: str) -> List[str]:
        """Extract personal references (family, background)"""
        
        refs = []
        personal_keywords = ['my wife', 'my husband', 'my kids', 'my family', 
                           'my father', 'my mother', 'growing up', 'when i was']
        
        for keyword in personal_keywords:
            if keyword in text.lower():
                refs.append(keyword)
        
        return refs
    
    def analyze_post_times(self, posts: List) -> dict:
        """Analyze when candidate typically posts"""
        
        hours = [post[2].hour for post in posts if post[2]]
        
        if not hours:
            return {'peak_hours': [10, 14, 18]}
        
        hour_counts = Counter(hours)
        peak_hours = [h for h, _ in hour_counts.most_common(3)]
        
        return {'peak_hours': peak_hours}
    
    def calculate_frequency(self, posts: List) -> dict:
        """Calculate posting frequency"""
        
        if len(posts) < 2:
            return {'posts_per_week': 3}
        
        dates = [post[2].date() for post in posts if post[2]]
        if len(dates) < 2:
            return {'posts_per_week': 3}
        
        date_range = (max(dates) - min(dates)).days
        posts_per_day = len(posts) / max(date_range, 1)
        
        return {'posts_per_week': round(posts_per_day * 7, 1)}
    
    # ================================================================
    # HUMAN IMPERFECTION ENGINE
    # ================================================================
    
    def add_human_imperfections(self, post: str, style_profile: dict) -> str:
        """
        Make AI-generated content feel MORE human
        (Ironically, perfection looks artificial)
        """
        
        # Apply variations
        post = self.vary_sentence_starts(post, style_profile)
        post = self.randomly_add_contractions(post)
        post = self.add_conversational_elements(post, style_profile)
        
        # Match emoji style
        if style_profile.get('emoji_usage', {}).get('uses_emojis'):
            post = self.add_emojis_matching_style(post, style_profile)
        
        # Match emphasis style
        if style_profile.get('emphasis_style', {}).get('uses_caps'):
            post = self.add_caps_emphasis(post, style_profile)
        
        return post
    
    def vary_sentence_starts(self, post: str, style_profile: dict) -> str:
        """Vary how sentences begin"""
        
        sentences = re.split(r'([.!?]+)', post)
        
        varied = []
        for i, sentence in enumerate(sentences):
            if sentence.strip() and i % 2 == 0:
                if random.random() < 0.3 and style_profile.get('opening_lines'):
                    opener = random.choice(style_profile['opening_lines'])
                    sentence = opener + '. ' + sentence
                varied.append(sentence)
            else:
                varied.append(sentence)
        
        return ''.join(varied)
    
    def randomly_add_contractions(self, post: str) -> str:
        """AI often uses formal forms - humans use contractions"""
        
        contractions = {
            'we are': "we're",
            'I am': "I'm",
            'you are': "you're",
            'it is': "it's",
            'that is': "that's",
            'cannot': "can't",
            'will not': "won't",
            'do not': "don't"
        }
        
        for formal, informal in contractions.items():
            if random.random() < 0.7:
                post = post.replace(formal, informal)
        
        return post
    
    def add_conversational_elements(self, post: str, style_profile: dict) -> str:
        """Add natural conversational markers"""
        
        casual_intros = [
            "Look,", "Listen,", "Folks,", "Here's the thing:",
            "Let me be clear:", "Bottom line:", "Real talk:"
        ]
        
        if style_profile.get('formality_level', 5) < 5:
            if random.random() < 0.4:
                intro = random.choice(casual_intros)
                post = intro + ' ' + post
        
        return post
    
    def add_emojis_matching_style(self, post: str, style_profile: dict) -> str:
        """Add emojis matching candidate's typical usage"""
        
        emoji_prefs = style_profile['emoji_usage']
        favorite_emojis = emoji_prefs.get('favorite_emojis', ['🇺🇸', '🔥', '💪'])
        placement = emoji_prefs.get('placement', 'end')
        
        num_emojis = random.randint(1, 2)
        emojis_to_add = random.sample(favorite_emojis, min(num_emojis, len(favorite_emojis)))
        
        if placement == 'end':
            post += ' ' + ' '.join(emojis_to_add)
        elif placement == 'inline':
            sentences = post.split('.')
            if len(sentences) > 1:
                sentences[0] += f' {emojis_to_add[0]}'
                post = '.'.join(sentences)
        
        return post
    
    def add_caps_emphasis(self, post: str, style_profile: dict) -> str:
        """Add ALL CAPS emphasis like candidate does"""
        
        emphasis_words = ['must', 'need', 'critical', 'urgent', 'now', 'today']
        
        for word in emphasis_words:
            if word in post.lower() and random.random() < 0.5:
                post = re.sub(rf'\b{word}\b', word.upper(), post, flags=re.IGNORECASE)
        
        return post
    
    # ================================================================
    # CONTENT GENERATION
    # ================================================================
    
    async def generate_personalized_post(self, candidate_id: str, topic: dict, 
                                        platform: str = 'facebook') -> str:
        """
        Generate post matching candidate's exact voice
        
        topic = {
            'subject': 'Wake County schools CRT spending',
            'key_points': ['$2.3M spent', 'teachers underpaid', 'parents upset'],
            'desired_action': 'donate',
            'urgency': 'high'
        }
        """
        
        # Get candidate's voice profile
        style_profile = self.get_voice_profile(candidate_id)
        
        if not style_profile:
            style_profile = self.analyze_candidate_voice(candidate_id)
        
        # Get candidate info
        candidate = self.get_candidate(candidate_id)
        
        # Generate post using AI (E13 AI Hub)
        prompt = f"""
        You are {candidate['name']}, running for {candidate['office']}.
        
        Generate a social media post for {platform} about this topic:
        
        Subject: {topic['subject']}
        Key Points: {', '.join(topic.get('key_points', []))}
        Call to Action: {topic.get('desired_action', 'engage')}
        Urgency: {topic.get('urgency', 'medium')}
        
        CRITICAL: Match this exact writing style:
        
        Sentence Structure:
        - Average length: {style_profile.get('sentence_structure', {}).get('avg_length', 15)} words
        - Uses fragments: {style_profile.get('sentence_structure', {}).get('uses_fragments', False)}
        
        Common Phrases (use 2-3 of these):
        {', '.join(style_profile.get('common_phrases', [])[:10])}
        
        Typical Openers:
        {', '.join(style_profile.get('opening_lines', [])[:5])}
        
        Emoji Usage:
        - Uses emojis: {style_profile.get('emoji_usage', {}).get('uses_emojis', True)}
        - Favorites: {', '.join(style_profile.get('emoji_usage', {}).get('favorite_emojis', ['🇺🇸']))}
        
        Formality Level: {style_profile.get('formality_level', 5)}/10
        
        CRITICAL: Write this post EXACTLY as {candidate['name']} would write it.
        This must be indistinguishable from their actual writing.
        
        Write the post now (just the post text, no explanations):
        """
        
        response = self.claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1000,
            messages=[{"role": "user", "content": prompt}]
        )
        
        post = response.content[0].text.strip()
        
        # Add human imperfections
        post = self.add_human_imperfections(post, style_profile)
        
        return post
    
    # ================================================================
    # DATABASE HELPERS
    # ================================================================
    
    def get_voice_profile(self, candidate_id: str) -> Optional[dict]:
        """Load saved voice profile from E0 DataHub"""
        cur = self.db.cursor()
        cur.execute("""
            SELECT profile_data
            FROM candidate_voice_profiles
            WHERE candidate_id = %s
            ORDER BY created_at DESC
            LIMIT 1
        """, (candidate_id,))
        
        result = cur.fetchone()
        return json.loads(result[0]) if result else None
    
    def save_voice_profile(self, candidate_id: str, profile: dict):
        """Save voice profile to E0 DataHub"""
        cur = self.db.cursor()
        cur.execute("""
            INSERT INTO candidate_voice_profiles
            (candidate_id, profile_data, created_at)
            VALUES (%s, %s, NOW())
        """, (candidate_id, json.dumps(profile)))
        self.db.commit()
    
    def create_default_profile(self, candidate_id: str) -> dict:
        """Create default profile for new candidate"""
        candidate = self.get_candidate(candidate_id)
        
        return {
            'candidate_id': candidate_id,
            'sentence_structure': {
                'avg_length': 15,
                'uses_fragments': False,
                'uses_questions': 0.3,
                'uses_exclamations': 0.5
            },
            'emoji_usage': {
                'uses_emojis': True,
                'frequency': 2,
                'favorite_emojis': ['🇺🇸', '🔥', '💪'],
                'placement': 'end'
            },
            'hashtag_patterns': {
                'avg_count': 3,
                'placement': 'end'
            },
            'formality_level': 5,
            'common_phrases': [],
            'opening_lines': [],
            'closing_lines': [],
            'typical_cta': 'Donate $25'
        }
    
    def get_candidate(self, candidate_id: str) -> Optional[dict]:
        """Get candidate info from E0 DataHub"""
        cur = self.db.cursor()
        cur.execute("""
            SELECT candidate_id, name, office, party
            FROM candidates
            WHERE candidate_id = %s
        """, (candidate_id,))
        row = cur.fetchone()
        return {
            'candidate_id': row[0],
            'name': row[1],
            'office': row[2],
            'party': row[3]
        } if row else None


# ================================================================
# EXAMPLE USAGE
# ================================================================

async def example_usage():
    """Example: Generate personalized post"""
    
    DB_CONFIG = {
        'host': 'db.YOUR_PROJECT.supabase.co',
        'database': 'postgres',
        'user': 'postgres',
        'password': 'YOUR_PASSWORD',
        'port': 5432
    }
    
    CLAUDE_API_KEY = "YOUR_CLAUDE_API_KEY"
    
    engine = PersonalizationEngine(DB_CONFIG, CLAUDE_API_KEY)
    
    # Analyze candidate's writing style
    print("Analyzing candidate's writing style...")
    style_profile = engine.analyze_candidate_voice('candidate_001')
    
    # Generate personalized post
    print("\nGenerating personalized post...")
    post = await engine.generate_personalized_post(
        candidate_id='candidate_001',
        topic={
            'subject': 'Wake County schools CRT spending',
            'key_points': ['$2.3M spent', 'teachers underpaid', 'parents upset'],
            'desired_action': 'donate',
            'urgency': 'high'
        },
        platform='facebook'
    )
    
    print(f"✅ Post generated:\n\n{post}")


if __name__ == "__main__":
    asyncio.run(example_usage())
