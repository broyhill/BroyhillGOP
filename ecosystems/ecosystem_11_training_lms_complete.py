#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 11B: TRAINING & LEARNING MANAGEMENT SYSTEM (LMS) - COMPLETE
============================================================================

Comprehensive training platform for volunteers and staff:
- Video lessons and courses
- Interactive quizzes
- Certification tracks
- Progress tracking
- Gamification (badges, points, leaderboards)
- Downloadable resources (scripts, checklists)
- Live webinar integration
- Role-based training paths
- Continuing education

Development Value: $100,000+
Powers: Volunteer onboarding, staff training, certification

Note: Original E11 was Budget Management. This is E11B - Training LMS.
============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem11b.training')


class TrainingConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    VIDEO_HOST = os.getenv("VIDEO_HOST", "vimeo")  # vimeo, youtube, wistia


class CourseCategory(Enum):
    VOLUNTEER_BASICS = "volunteer_basics"
    PHONE_BANKING = "phone_banking"
    CANVASSING = "canvassing"
    EVENT_VOLUNTEER = "event_volunteer"
    DATA_ENTRY = "data_entry"
    GOTV = "gotv"
    FUNDRAISING = "fundraising"
    COMPLIANCE = "compliance"
    MANAGEMENT = "management"
    COMMUNICATIONS = "communications"
    TECHNOLOGY = "technology"
    LEADERSHIP = "leadership"

class ContentType(Enum):
    VIDEO = "video"
    QUIZ = "quiz"
    PDF = "pdf"
    ARTICLE = "article"
    INTERACTIVE = "interactive"
    WEBINAR = "webinar"
    ROLEPLAY = "roleplay"
    CASE_STUDY = "case_study"

class CertificationType(Enum):
    # Volunteer Certifications
    CERTIFIED_PHONE_BANKER = "certified_phone_banker"
    CERTIFIED_CANVASSER = "certified_canvasser"
    CERTIFIED_EVENT_VOLUNTEER = "certified_event_volunteer"
    GOTV_CAPTAIN = "gotv_captain"
    PRECINCT_CAPTAIN = "precinct_captain"
    
    # Staff Certifications
    CERTIFIED_CAMPAIGN_MANAGER = "certified_campaign_manager"
    CERTIFIED_FINANCE_DIRECTOR = "certified_finance_director"
    CERTIFIED_FIELD_DIRECTOR = "certified_field_director"
    FEC_COMPLIANCE_CERTIFIED = "fec_compliance_certified"

class EnrollmentStatus(Enum):
    ENROLLED = "enrolled"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    EXPIRED = "expired"
    DROPPED = "dropped"


TRAINING_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 11B: TRAINING & LEARNING MANAGEMENT SYSTEM
-- ============================================================================

-- Courses
CREATE TABLE IF NOT EXISTS training_courses (
    course_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    difficulty_level VARCHAR(50) DEFAULT 'beginner',
    duration_minutes INTEGER,
    thumbnail_url TEXT,
    instructor_name VARCHAR(255),
    is_required BOOLEAN DEFAULT false,
    required_for_roles JSONB DEFAULT '[]',
    prerequisites JSONB DEFAULT '[]',
    certification_id VARCHAR(100),
    points_value INTEGER DEFAULT 10,
    pass_threshold INTEGER DEFAULT 70,
    is_published BOOLEAN DEFAULT false,
    publish_date TIMESTAMP,
    expire_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_courses_category ON training_courses(category);
CREATE INDEX IF NOT EXISTS idx_courses_published ON training_courses(is_published);

-- Modules (sections within courses)
CREATE TABLE IF NOT EXISTS training_modules (
    module_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES training_courses(course_id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    sequence_order INTEGER NOT NULL,
    duration_minutes INTEGER,
    is_required BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_modules_course ON training_modules(course_id);

-- Content Items (videos, quizzes, PDFs within modules)
CREATE TABLE IF NOT EXISTS training_content (
    content_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES training_modules(module_id),
    title VARCHAR(500) NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    sequence_order INTEGER NOT NULL,
    duration_minutes INTEGER,
    
    -- Video content
    video_url TEXT,
    video_provider VARCHAR(50),
    video_id VARCHAR(255),
    
    -- Quiz content
    quiz_questions JSONB DEFAULT '[]',
    quiz_time_limit_minutes INTEGER,
    quiz_attempts_allowed INTEGER DEFAULT 3,
    
    -- PDF/Article content
    document_url TEXT,
    article_body TEXT,
    
    -- Interactive content
    interactive_url TEXT,
    interactive_config JSONB DEFAULT '{}',
    
    points_value INTEGER DEFAULT 5,
    is_required BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_module ON training_content(module_id);
CREATE INDEX IF NOT EXISTS idx_content_type ON training_content(content_type);

-- User Enrollments
CREATE TABLE IF NOT EXISTS training_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    course_id UUID REFERENCES training_courses(course_id),
    status VARCHAR(50) DEFAULT 'enrolled',
    enrolled_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    progress_pct DECIMAL(5,2) DEFAULT 0,
    current_module_id UUID,
    current_content_id UUID,
    total_time_spent_minutes INTEGER DEFAULT 0,
    quiz_attempts INTEGER DEFAULT 0,
    highest_quiz_score INTEGER,
    points_earned INTEGER DEFAULT 0,
    certificate_issued BOOLEAN DEFAULT false,
    certificate_url TEXT,
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_enrollments_user ON training_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON training_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status ON training_enrollments(status);

-- Content Progress (track each piece of content)
CREATE TABLE IF NOT EXISTS training_progress (
    progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrollment_id UUID REFERENCES training_enrollments(enrollment_id),
    content_id UUID REFERENCES training_content(content_id),
    status VARCHAR(50) DEFAULT 'not_started',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    time_spent_minutes INTEGER DEFAULT 0,
    video_progress_pct DECIMAL(5,2) DEFAULT 0,
    quiz_score INTEGER,
    quiz_answers JSONB DEFAULT '{}',
    attempts INTEGER DEFAULT 0,
    points_earned INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_progress_enrollment ON training_progress(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_progress_content ON training_progress(content_id);

-- Certifications
CREATE TABLE IF NOT EXISTS training_certifications (
    cert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    certification_type VARCHAR(100) NOT NULL,
    course_id UUID REFERENCES training_courses(course_id),
    issued_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    certificate_number VARCHAR(100) UNIQUE,
    certificate_url TEXT,
    score INTEGER,
    is_valid BOOLEAN DEFAULT true,
    renewed_from UUID
);

CREATE INDEX IF NOT EXISTS idx_certs_user ON training_certifications(user_id);
CREATE INDEX IF NOT EXISTS idx_certs_type ON training_certifications(certification_type);

-- Badges & Achievements
CREATE TABLE IF NOT EXISTS training_badges (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon_url TEXT,
    category VARCHAR(100),
    points_required INTEGER,
    courses_required JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_badges (
    user_badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    badge_id UUID REFERENCES training_badges(badge_id),
    earned_at TIMESTAMP DEFAULT NOW(),
    shared_on_social BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_user_badges_user ON user_badges(user_id);

-- Leaderboard
CREATE TABLE IF NOT EXISTS training_leaderboard (
    leaderboard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    total_points INTEGER DEFAULT 0,
    courses_completed INTEGER DEFAULT 0,
    certifications_earned INTEGER DEFAULT 0,
    badges_earned INTEGER DEFAULT 0,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak_days INTEGER DEFAULT 0,
    last_activity_at TIMESTAMP DEFAULT NOW(),
    rank_position INTEGER,
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_user ON training_leaderboard(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_points ON training_leaderboard(total_points DESC);

-- Learning Paths
CREATE TABLE IF NOT EXISTS learning_paths (
    path_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    target_role VARCHAR(100),
    courses JSONB DEFAULT '[]',
    estimated_hours INTEGER,
    certification_awarded VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Webinars/Live Training
CREATE TABLE IF NOT EXISTS training_webinars (
    webinar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    instructor_name VARCHAR(255),
    scheduled_at TIMESTAMP NOT NULL,
    duration_minutes INTEGER DEFAULT 60,
    max_attendees INTEGER,
    webinar_url TEXT,
    webinar_provider VARCHAR(50),
    recording_url TEXT,
    is_recorded BOOLEAN DEFAULT false,
    course_id UUID REFERENCES training_courses(course_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS webinar_registrations (
    registration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webinar_id UUID REFERENCES training_webinars(webinar_id),
    user_id UUID NOT NULL,
    registered_at TIMESTAMP DEFAULT NOW(),
    attended BOOLEAN DEFAULT false,
    attended_minutes INTEGER DEFAULT 0
);

-- Views
CREATE OR REPLACE VIEW v_course_summary AS
SELECT 
    c.course_id,
    c.title,
    c.category,
    c.difficulty_level,
    c.duration_minutes,
    c.points_value,
    c.is_published,
    COUNT(DISTINCT m.module_id) as module_count,
    COUNT(DISTINCT tc.content_id) as content_count,
    COUNT(DISTINCT e.enrollment_id) as enrollments,
    COUNT(DISTINCT e.enrollment_id) FILTER (WHERE e.status = 'completed') as completions
FROM training_courses c
LEFT JOIN training_modules m ON c.course_id = m.course_id
LEFT JOIN training_content tc ON m.module_id = tc.module_id
LEFT JOIN training_enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id;

CREATE OR REPLACE VIEW v_user_progress AS
SELECT 
    e.user_id,
    COUNT(DISTINCT e.course_id) as courses_enrolled,
    COUNT(DISTINCT e.course_id) FILTER (WHERE e.status = 'completed') as courses_completed,
    SUM(e.points_earned) as total_points,
    AVG(e.progress_pct) as avg_progress,
    SUM(e.total_time_spent_minutes) as total_time_minutes
FROM training_enrollments e
GROUP BY e.user_id;

CREATE OR REPLACE VIEW v_leaderboard_top AS
SELECT 
    l.user_id,
    l.total_points,
    l.courses_completed,
    l.certifications_earned,
    l.badges_earned,
    l.current_streak_days,
    ROW_NUMBER() OVER (ORDER BY l.total_points DESC) as rank
FROM training_leaderboard l
ORDER BY total_points DESC
LIMIT 100;

SELECT 'Training LMS schema deployed!' as status;
"""


# Pre-built courses
CORE_COURSES = [
    {
        'title': 'Phone Banking 101',
        'category': 'phone_banking',
        'description': 'Learn the fundamentals of effective phone banking for political campaigns.',
        'duration_minutes': 45,
        'difficulty_level': 'beginner',
        'certification_id': 'certified_phone_banker',
        'points_value': 50,
        'modules': [
            {'title': 'Introduction to Phone Banking', 'duration': 10},
            {'title': 'Reading the Script', 'duration': 10},
            {'title': 'Handling Objections', 'duration': 15},
            {'title': 'Recording Responses', 'duration': 5},
            {'title': 'Final Quiz', 'duration': 5}
        ]
    },
    {
        'title': 'Door Knocking Essentials',
        'category': 'canvassing',
        'description': 'Master the art of canvassing and voter contact at the door.',
        'duration_minutes': 60,
        'difficulty_level': 'beginner',
        'certification_id': 'certified_canvasser',
        'points_value': 75,
        'modules': [
            {'title': 'Canvassing Overview', 'duration': 10},
            {'title': 'Safety First', 'duration': 10},
            {'title': 'The Perfect Pitch', 'duration': 15},
            {'title': 'Using the Canvassing App', 'duration': 10},
            {'title': 'Roleplay Practice', 'duration': 10},
            {'title': 'Final Quiz', 'duration': 5}
        ]
    },
    {
        'title': 'FEC Compliance Fundamentals',
        'category': 'compliance',
        'description': 'Understand federal campaign finance laws and compliance requirements.',
        'duration_minutes': 90,
        'difficulty_level': 'intermediate',
        'certification_id': 'fec_compliance_certified',
        'points_value': 100,
        'modules': [
            {'title': 'FEC Overview', 'duration': 15},
            {'title': 'Contribution Limits', 'duration': 20},
            {'title': 'Prohibited Contributions', 'duration': 15},
            {'title': 'Reporting Requirements', 'duration': 20},
            {'title': 'Disclaimers', 'duration': 10},
            {'title': 'Final Exam', 'duration': 10}
        ]
    },
    {
        'title': 'GOTV Captain Training',
        'category': 'gotv',
        'description': 'Lead your team to victory on Election Day.',
        'duration_minutes': 120,
        'difficulty_level': 'advanced',
        'certification_id': 'gotv_captain',
        'points_value': 150,
        'modules': [
            {'title': 'GOTV Strategy Overview', 'duration': 20},
            {'title': 'Team Leadership', 'duration': 20},
            {'title': 'Voter Targeting', 'duration': 20},
            {'title': 'Day-of Operations', 'duration': 30},
            {'title': 'Problem Solving', 'duration': 15},
            {'title': 'Final Assessment', 'duration': 15}
        ]
    },
    {
        'title': 'Campaign Manager Certification',
        'category': 'management',
        'description': 'Comprehensive training for campaign managers.',
        'duration_minutes': 480,
        'difficulty_level': 'advanced',
        'certification_id': 'certified_campaign_manager',
        'points_value': 500,
        'modules': [
            {'title': 'Campaign Planning', 'duration': 60},
            {'title': 'Budget Management', 'duration': 60},
            {'title': 'Staff and Volunteer Management', 'duration': 60},
            {'title': 'Fundraising Strategy', 'duration': 60},
            {'title': 'Communications and Media', 'duration': 60},
            {'title': 'Field Operations', 'duration': 60},
            {'title': 'GOTV Planning', 'duration': 60},
            {'title': 'Final Exam', 'duration': 60}
        ]
    }
]


class TrainingLMS:
    """Learning Management System"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self.db_url = TrainingConfig.DATABASE_URL
        self._initialized = True
        logger.info("📚 Training LMS initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # COURSE MANAGEMENT
    # ========================================================================
    
    def create_course(self, title: str, category: str, description: str = None,
                     duration_minutes: int = 60, difficulty_level: str = 'beginner',
                     certification_id: str = None, points_value: int = 10,
                     pass_threshold: int = 70) -> str:
        """Create a new course"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO training_courses (
                title, category, description, duration_minutes,
                difficulty_level, certification_id, points_value, pass_threshold
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING course_id
        """, (title, category, description, duration_minutes,
              difficulty_level, certification_id, points_value, pass_threshold))
        
        course_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created course: {course_id} - {title}")
        return course_id
    
    def add_module(self, course_id: str, title: str, sequence_order: int,
                  description: str = None, duration_minutes: int = None) -> str:
        """Add module to course"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO training_modules (course_id, title, sequence_order, description, duration_minutes)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING module_id
        """, (course_id, title, sequence_order, description, duration_minutes))
        
        module_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return module_id
    
    def add_content(self, module_id: str, title: str, content_type: str,
                   sequence_order: int, **kwargs) -> str:
        """Add content to module"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO training_content (
                module_id, title, content_type, sequence_order,
                video_url, video_provider, quiz_questions, document_url,
                article_body, points_value, duration_minutes
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING content_id
        """, (
            module_id, title, content_type, sequence_order,
            kwargs.get('video_url'), kwargs.get('video_provider'),
            json.dumps(kwargs.get('quiz_questions', [])),
            kwargs.get('document_url'), kwargs.get('article_body'),
            kwargs.get('points_value', 5), kwargs.get('duration_minutes')
        ))
        
        content_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return content_id
    
    def publish_course(self, course_id: str) -> None:
        """Publish a course"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE training_courses SET
                is_published = true,
                publish_date = NOW(),
                updated_at = NOW()
            WHERE course_id = %s
        """, (course_id,))
        
        conn.commit()
        conn.close()
    
    def get_courses(self, category: str = None, published_only: bool = True) -> List[Dict]:
        """Get courses"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM v_course_summary WHERE 1=1"
        params = []
        
        if published_only:
            sql += " AND is_published = true"
        if category:
            sql += " AND category = %s"
            params.append(category)
        
        sql += " ORDER BY title"
        
        cur.execute(sql, params)
        courses = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return courses
    
    # ========================================================================
    # ENROLLMENT & PROGRESS
    # ========================================================================
    
    def enroll_user(self, user_id: str, course_id: str) -> str:
        """Enroll user in course"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Check if already enrolled
        cur.execute("""
            SELECT enrollment_id FROM training_enrollments
            WHERE user_id = %s AND course_id = %s AND status != 'dropped'
        """, (user_id, course_id))
        
        existing = cur.fetchone()
        if existing:
            conn.close()
            return str(existing[0])
        
        cur.execute("""
            INSERT INTO training_enrollments (user_id, course_id, status)
            VALUES (%s, %s, 'enrolled')
            RETURNING enrollment_id
        """, (user_id, course_id))
        
        enrollment_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Enrolled user {user_id} in course {course_id}")
        return enrollment_id
    
    def start_content(self, enrollment_id: str, content_id: str) -> str:
        """Start content item"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO training_progress (enrollment_id, content_id, status, started_at)
            VALUES (%s, %s, 'in_progress', NOW())
            ON CONFLICT (enrollment_id, content_id) DO UPDATE SET
                status = 'in_progress',
                started_at = COALESCE(training_progress.started_at, NOW())
            RETURNING progress_id
        """, (enrollment_id, content_id))
        
        progress_id = str(cur.fetchone()[0])
        
        # Update enrollment
        cur.execute("""
            UPDATE training_enrollments SET
                status = 'in_progress',
                started_at = COALESCE(started_at, NOW()),
                current_content_id = %s
            WHERE enrollment_id = %s
        """, (content_id, enrollment_id))
        
        conn.commit()
        conn.close()
        
        return progress_id
    
    def complete_content(self, enrollment_id: str, content_id: str,
                        time_spent_minutes: int = 0, quiz_score: int = None,
                        quiz_answers: Dict = None) -> Dict:
        """Complete content item"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get content points
        cur.execute("SELECT points_value FROM training_content WHERE content_id = %s", (content_id,))
        content = cur.fetchone()
        points = content['points_value'] if content else 5
        
        # Update progress
        cur.execute("""
            UPDATE training_progress SET
                status = 'completed',
                completed_at = NOW(),
                time_spent_minutes = %s,
                quiz_score = %s,
                quiz_answers = %s,
                points_earned = %s,
                attempts = attempts + 1
            WHERE enrollment_id = %s AND content_id = %s
            RETURNING progress_id
        """, (time_spent_minutes, quiz_score, json.dumps(quiz_answers or {}),
              points, enrollment_id, content_id))
        
        # Update enrollment totals
        cur.execute("""
            UPDATE training_enrollments SET
                total_time_spent_minutes = total_time_spent_minutes + %s,
                points_earned = points_earned + %s
            WHERE enrollment_id = %s
        """, (time_spent_minutes, points, enrollment_id))
        
        # Calculate progress percentage
        cur.execute("""
            WITH content_count AS (
                SELECT COUNT(*) as total FROM training_content tc
                JOIN training_modules m ON tc.module_id = m.module_id
                JOIN training_enrollments e ON m.course_id = e.course_id
                WHERE e.enrollment_id = %s
            ),
            completed_count AS (
                SELECT COUNT(*) as completed FROM training_progress
                WHERE enrollment_id = %s AND status = 'completed'
            )
            SELECT 
                (cc.completed::DECIMAL / NULLIF(tc.total, 0) * 100) as progress_pct
            FROM content_count tc, completed_count cc
        """, (enrollment_id, enrollment_id))
        
        progress = cur.fetchone()
        progress_pct = progress['progress_pct'] if progress else 0
        
        cur.execute("""
            UPDATE training_enrollments SET progress_pct = %s WHERE enrollment_id = %s
        """, (progress_pct, enrollment_id))
        
        conn.commit()
        conn.close()
        
        return {'progress_pct': progress_pct, 'points_earned': points}
    
    def complete_course(self, enrollment_id: str, final_score: int = None) -> Dict:
        """Complete course and issue certificate if passed"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get course and enrollment info
        cur.execute("""
            SELECT e.*, c.certification_id, c.pass_threshold, c.title
            FROM training_enrollments e
            JOIN training_courses c ON e.course_id = c.course_id
            WHERE e.enrollment_id = %s
        """, (enrollment_id,))
        
        enrollment = cur.fetchone()
        if not enrollment:
            conn.close()
            return {'error': 'Enrollment not found'}
        
        # Update enrollment
        cur.execute("""
            UPDATE training_enrollments SET
                status = 'completed',
                completed_at = NOW(),
                highest_quiz_score = GREATEST(COALESCE(highest_quiz_score, 0), %s)
            WHERE enrollment_id = %s
        """, (final_score or 0, enrollment_id))
        
        result = {
            'completed': True,
            'score': final_score,
            'passed': (final_score or 0) >= enrollment['pass_threshold']
        }
        
        # Issue certification if passed
        if result['passed'] and enrollment['certification_id']:
            cert_number = f"CERT-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"
            
            cur.execute("""
                INSERT INTO training_certifications (
                    user_id, certification_type, course_id,
                    certificate_number, score
                ) VALUES (%s, %s, %s, %s, %s)
                RETURNING cert_id
            """, (enrollment['user_id'], enrollment['certification_id'],
                  enrollment['course_id'], cert_number, final_score))
            
            cert_id = str(cur.fetchone()[0])
            
            cur.execute("""
                UPDATE training_enrollments SET certificate_issued = true
                WHERE enrollment_id = %s
            """, (enrollment_id,))
            
            result['certification'] = {
                'cert_id': cert_id,
                'cert_number': cert_number,
                'type': enrollment['certification_id']
            }
            
            # Update leaderboard
            cur.execute("""
                UPDATE training_leaderboard SET
                    certifications_earned = certifications_earned + 1,
                    courses_completed = courses_completed + 1,
                    updated_at = NOW()
                WHERE user_id = %s
            """, (enrollment['user_id'],))
        
        conn.commit()
        conn.close()
        
        return result
    
    def get_user_progress(self, user_id: str) -> Dict:
        """Get user's learning progress"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_user_progress WHERE user_id = %s", (user_id,))
        progress = cur.fetchone()
        
        cur.execute("""
            SELECT e.*, c.title as course_title
            FROM training_enrollments e
            JOIN training_courses c ON e.course_id = c.course_id
            WHERE e.user_id = %s
            ORDER BY e.enrolled_at DESC
        """, (user_id,))
        enrollments = [dict(r) for r in cur.fetchall()]
        
        cur.execute("""
            SELECT * FROM training_certifications
            WHERE user_id = %s AND is_valid = true
            ORDER BY issued_at DESC
        """, (user_id,))
        certifications = [dict(r) for r in cur.fetchall()]
        
        conn.close()
        
        return {
            'summary': dict(progress) if progress else {},
            'enrollments': enrollments,
            'certifications': certifications
        }
    
    # ========================================================================
    # BADGES & GAMIFICATION
    # ========================================================================
    
    def award_badge(self, user_id: str, badge_id: str) -> str:
        """Award badge to user"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO user_badges (user_id, badge_id)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING
            RETURNING user_badge_id
        """, (user_id, badge_id))
        
        result = cur.fetchone()
        user_badge_id = str(result[0]) if result else None
        
        if user_badge_id:
            cur.execute("""
                UPDATE training_leaderboard SET
                    badges_earned = badges_earned + 1,
                    updated_at = NOW()
                WHERE user_id = %s
            """, (user_id,))
        
        conn.commit()
        conn.close()
        
        return user_badge_id
    
    def get_leaderboard(self, limit: int = 20) -> List[Dict]:
        """Get leaderboard"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM v_leaderboard_top LIMIT %s
        """, (limit,))
        
        leaderboard = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return leaderboard
    
    def update_streak(self, user_id: str) -> int:
        """Update user's learning streak"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT current_streak_days, longest_streak_days, last_activity_at
            FROM training_leaderboard WHERE user_id = %s
        """, (user_id,))
        
        record = cur.fetchone()
        
        if record:
            last_activity = record['last_activity_at']
            current_streak = record['current_streak_days']
            
            if last_activity:
                days_since = (datetime.now() - last_activity).days
                
                if days_since == 0:
                    # Same day, no change
                    new_streak = current_streak
                elif days_since == 1:
                    # Consecutive day
                    new_streak = current_streak + 1
                else:
                    # Streak broken
                    new_streak = 1
            else:
                new_streak = 1
            
            cur.execute("""
                UPDATE training_leaderboard SET
                    current_streak_days = %s,
                    longest_streak_days = GREATEST(longest_streak_days, %s),
                    last_activity_at = NOW(),
                    updated_at = NOW()
                WHERE user_id = %s
            """, (new_streak, new_streak, user_id))
        else:
            # Create leaderboard entry
            new_streak = 1
            cur.execute("""
                INSERT INTO training_leaderboard (user_id, current_streak_days, longest_streak_days)
                VALUES (%s, 1, 1)
            """, (user_id,))
        
        conn.commit()
        conn.close()
        
        return new_streak
    
    # ========================================================================
    # ANALYTICS
    # ========================================================================
    
    def get_stats(self) -> Dict:
        """Get LMS statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                (SELECT COUNT(*) FROM training_courses WHERE is_published = true) as courses,
                (SELECT COUNT(*) FROM training_enrollments) as enrollments,
                (SELECT COUNT(*) FROM training_enrollments WHERE status = 'completed') as completions,
                (SELECT COUNT(*) FROM training_certifications WHERE is_valid = true) as certifications,
                (SELECT SUM(total_points) FROM training_leaderboard) as total_points_awarded
        """)
        
        stats = dict(cur.fetchone())
        conn.close()
        
        return stats


def deploy_training_lms():
    """Deploy Training LMS"""
    print("=" * 70)
    print("📚 ECOSYSTEM 11B: TRAINING LMS - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(TrainingConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(TRAINING_SCHEMA)
        conn.commit()
        conn.close()
        
        print("\n   ✅ training_courses table")
        print("   ✅ training_modules table")
        print("   ✅ training_content table")
        print("   ✅ training_enrollments table")
        print("   ✅ training_progress table")
        print("   ✅ training_certifications table")
        print("   ✅ training_badges table")
        print("   ✅ user_badges table")
        print("   ✅ training_leaderboard table")
        print("   ✅ learning_paths table")
        print("   ✅ training_webinars table")
        print("   ✅ v_course_summary view")
        print("   ✅ v_user_progress view")
        print("   ✅ v_leaderboard_top view")
        
        print("\n" + "=" * 70)
        print("✅ TRAINING LMS DEPLOYED!")
        print("=" * 70)
        
        print("\n📋 CERTIFICATIONS AVAILABLE:")
        for cert in CertificationType:
            print(f"   • {cert.value}")
        
        print("\n📚 PRE-BUILT COURSES:")
        for course in CORE_COURSES:
            print(f"   • {course['title']} ({course['duration_minutes']} min)")
        
        print("\n🎯 FEATURES:")
        print("   • Video lessons")
        print("   • Interactive quizzes")
        print("   • Certification tracks")
        print("   • Progress tracking")
        print("   • Gamification (badges, points)")
        print("   • Leaderboards")
        print("   • Live webinars")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === ERROR HANDLING (Auto-added by repair tool) ===
import traceback
from functools import wraps

# === CUSTOM EXCEPTIONS (Auto-added by repair tool) ===
class 11TrainingLmsCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 11TrainingLmsCompleteValidationError(11TrainingLmsCompleteError):
    """Validation error in this ecosystem"""
    pass

class 11TrainingLmsCompleteDatabaseError(11TrainingLmsCompleteError):
    """Database error in this ecosystem"""
    pass

class 11TrainingLmsCompleteAPIError(11TrainingLmsCompleteError):
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
class 11TrainingLmsCompleteError(Exception):
    """Base exception for this ecosystem"""
    pass

class 11TrainingLmsCompleteValidationError(11TrainingLmsCompleteError):
    """Validation error in this ecosystem"""
    pass

class 11TrainingLmsCompleteDatabaseError(11TrainingLmsCompleteError):
    """Database error in this ecosystem"""
    pass

class 11TrainingLmsCompleteAPIError(11TrainingLmsCompleteError):
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

    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_training_lms()
    elif len(sys.argv) > 1 and sys.argv[1] == "--stats":
        lms = TrainingLMS()
        print(json.dumps(lms.get_stats(), indent=2, default=str))
    else:
        print("📚 Training LMS")
        print("\nUsage:")
        print("  python ecosystem_11_training_lms_complete.py --deploy")
        print("  python ecosystem_11_training_lms_complete.py --stats")
        print("\nCertifications: Phone Banker, Canvasser, GOTV Captain, Campaign Manager")
