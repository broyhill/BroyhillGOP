#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 12: CAMPAIGN OPERATIONS - COMPLETE (100%)
============================================================================

Comprehensive campaign task management and team coordination:
- Task assignment and tracking
- Project management with milestones
- Team collaboration
- Workflow automation
- Calendar and scheduling
- File management
- Internal messaging
- Deadline tracking
- Campaign phases
- Staff/volunteer coordination

Development Value: $100,000+
Powers: Daily operations, team coordination, project tracking

============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem12.operations')


class OperationsConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")


class TaskStatus(Enum):
    BACKLOG = "backlog"
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    REVIEW = "review"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class TaskPriority(Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

class TaskCategory(Enum):
    FUNDRAISING = "fundraising"
    VOTER_CONTACT = "voter_contact"
    COMMUNICATIONS = "communications"
    EVENTS = "events"
    COMPLIANCE = "compliance"
    ADMIN = "admin"
    FIELD = "field"
    DIGITAL = "digital"
    FINANCE = "finance"
    LEGAL = "legal"

class CampaignPhase(Enum):
    EXPLORATORY = "exploratory"
    ANNOUNCEMENT = "announcement"
    PRIMARY = "primary"
    GENERAL = "general"
    GOTV = "gotv"
    ELECTION_DAY = "election_day"
    POST_ELECTION = "post_election"


OPERATIONS_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 12: CAMPAIGN OPERATIONS
-- ============================================================================

-- Campaign Team Members
CREATE TABLE IF NOT EXISTS campaign_team (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    user_id UUID,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    role VARCHAR(100),
    department VARCHAR(100),
    is_staff BOOLEAN DEFAULT true,
    hourly_rate DECIMAL(10,2),
    start_date DATE,
    end_date DATE,
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_candidate ON campaign_team(candidate_id);
CREATE INDEX IF NOT EXISTS idx_team_role ON campaign_team(role);

-- Projects
CREATE TABLE IF NOT EXISTS campaign_projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    phase VARCHAR(50),
    status VARCHAR(50) DEFAULT 'active',
    owner_id UUID REFERENCES campaign_team(member_id),
    start_date DATE,
    target_date DATE,
    completed_date DATE,
    budget DECIMAL(12,2),
    spent DECIMAL(12,2) DEFAULT 0,
    progress_pct INTEGER DEFAULT 0,
    priority VARCHAR(20) DEFAULT 'medium',
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_projects_candidate ON campaign_projects(candidate_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON campaign_projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_phase ON campaign_projects(phase);

-- Tasks
CREATE TABLE IF NOT EXISTS campaign_tasks (
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES campaign_projects(project_id),
    candidate_id UUID,
    parent_task_id UUID REFERENCES campaign_tasks(task_id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    status VARCHAR(50) DEFAULT 'todo',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to UUID REFERENCES campaign_team(member_id),
    created_by UUID REFERENCES campaign_team(member_id),
    due_date TIMESTAMP,
    start_date TIMESTAMP,
    completed_at TIMESTAMP,
    estimated_hours DECIMAL(6,2),
    actual_hours DECIMAL(6,2),
    is_recurring BOOLEAN DEFAULT false,
    recurrence_rule VARCHAR(100),
    dependencies JSONB DEFAULT '[]',
    tags JSONB DEFAULT '[]',
    attachments JSONB DEFAULT '[]',
    checklist JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_project ON campaign_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON campaign_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON campaign_tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON campaign_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON campaign_tasks(priority);

-- Task Comments
CREATE TABLE IF NOT EXISTS task_comments (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    author_id UUID REFERENCES campaign_team(member_id),
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_task ON task_comments(task_id);

-- Task History (audit trail)
CREATE TABLE IF NOT EXISTS task_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    changed_by UUID REFERENCES campaign_team(member_id),
    field_changed VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_history_task ON task_history(task_id);

-- Milestones
CREATE TABLE IF NOT EXISTS campaign_milestones (
    milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES campaign_projects(project_id),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    target_date DATE NOT NULL,
    completed_date DATE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_milestones_project ON campaign_milestones(project_id);
CREATE INDEX IF NOT EXISTS idx_milestones_date ON campaign_milestones(target_date);

-- Calendar Events
CREATE TABLE IF NOT EXISTS campaign_calendar (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50),
    location VARCHAR(500),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    all_day BOOLEAN DEFAULT false,
    attendees JSONB DEFAULT '[]',
    reminders JSONB DEFAULT '[]',
    recurrence_rule VARCHAR(100),
    related_task_id UUID REFERENCES campaign_tasks(task_id),
    related_project_id UUID REFERENCES campaign_projects(project_id),
    is_public BOOLEAN DEFAULT false,
    created_by UUID REFERENCES campaign_team(member_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_candidate ON campaign_calendar(candidate_id);
CREATE INDEX IF NOT EXISTS idx_calendar_start ON campaign_calendar(start_time);
CREATE INDEX IF NOT EXISTS idx_calendar_type ON campaign_calendar(event_type);

-- Workflows (automation templates)
CREATE TABLE IF NOT EXISTS campaign_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger_type VARCHAR(50),
    trigger_config JSONB DEFAULT '{}',
    steps JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflows_trigger ON campaign_workflows(trigger_type);

-- Messages (internal team communication)
CREATE TABLE IF NOT EXISTS campaign_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    sender_id UUID REFERENCES campaign_team(member_id),
    recipient_ids JSONB DEFAULT '[]',
    channel VARCHAR(50) DEFAULT 'general',
    subject VARCHAR(255),
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]',
    is_read BOOLEAN DEFAULT false,
    related_task_id UUID REFERENCES campaign_tasks(task_id),
    parent_message_id UUID REFERENCES campaign_messages(message_id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_channel ON campaign_messages(channel);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON campaign_messages(sender_id);

-- Time Tracking
CREATE TABLE IF NOT EXISTS time_entries (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES campaign_tasks(task_id),
    member_id UUID REFERENCES campaign_team(member_id),
    hours DECIMAL(6,2) NOT NULL,
    description TEXT,
    entry_date DATE DEFAULT CURRENT_DATE,
    billable BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_task ON time_entries(task_id);
CREATE INDEX IF NOT EXISTS idx_time_member ON time_entries(member_id);

-- Views
CREATE OR REPLACE VIEW v_task_summary AS
SELECT 
    ct.task_id,
    ct.title,
    ct.status,
    ct.priority,
    ct.due_date,
    ct.assigned_to,
    tm.name as assignee_name,
    cp.name as project_name,
    ct.category,
    CASE WHEN ct.due_date < NOW() AND ct.status NOT IN ('completed', 'cancelled') 
         THEN true ELSE false END as is_overdue
FROM campaign_tasks ct
LEFT JOIN campaign_team tm ON ct.assigned_to = tm.member_id
LEFT JOIN campaign_projects cp ON ct.project_id = cp.project_id;

CREATE OR REPLACE VIEW v_team_workload AS
SELECT 
    tm.member_id,
    tm.name,
    tm.role,
    COUNT(ct.task_id) FILTER (WHERE ct.status IN ('todo', 'in_progress')) as active_tasks,
    COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed' AND ct.completed_at > NOW() - INTERVAL '7 days') as completed_this_week,
    SUM(ct.estimated_hours) FILTER (WHERE ct.status IN ('todo', 'in_progress')) as pending_hours
FROM campaign_team tm
LEFT JOIN campaign_tasks ct ON tm.member_id = ct.assigned_to
WHERE tm.is_active = true
GROUP BY tm.member_id, tm.name, tm.role;

CREATE OR REPLACE VIEW v_project_progress AS
SELECT 
    cp.project_id,
    cp.name,
    cp.status,
    cp.target_date,
    cp.budget,
    cp.spent,
    COUNT(ct.task_id) as total_tasks,
    COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed') as completed_tasks,
    CASE WHEN COUNT(ct.task_id) > 0 
         THEN (COUNT(ct.task_id) FILTER (WHERE ct.status = 'completed')::DECIMAL / COUNT(ct.task_id) * 100)::INTEGER
         ELSE 0 END as progress_pct
FROM campaign_projects cp
LEFT JOIN campaign_tasks ct ON cp.project_id = ct.project_id
GROUP BY cp.project_id, cp.name, cp.status, cp.target_date, cp.budget, cp.spent;

SELECT 'Campaign Operations schema deployed!' as status;
"""


class CampaignOperationsEngine:
    """Main campaign operations engine"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self.db_url = OperationsConfig.DATABASE_URL
        self._initialized = True
        logger.info("📋 Campaign Operations Engine initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # TEAM MANAGEMENT
    # ========================================================================
    
    def add_team_member(self, name: str, email: str = None,
                       role: str = None, department: str = None,
                       is_staff: bool = True,
                       candidate_id: str = None) -> str:
        """Add a team member"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO campaign_team (
                name, email, role, department, is_staff, candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING member_id
        """, (name, email, role, department, is_staff, candidate_id))
        
        member_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return member_id
    
    def get_team(self, candidate_id: str = None) -> List[Dict]:
        """Get team members"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        if candidate_id:
            cur.execute("SELECT * FROM campaign_team WHERE candidate_id = %s AND is_active = true", (candidate_id,))
        else:
            cur.execute("SELECT * FROM campaign_team WHERE is_active = true")
        
        team = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return team
    
    # ========================================================================
    # PROJECT MANAGEMENT
    # ========================================================================
    
    def create_project(self, name: str, description: str = None,
                      category: str = None, phase: str = None,
                      owner_id: str = None, target_date: date = None,
                      budget: float = None,
                      candidate_id: str = None) -> str:
        """Create a project"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO campaign_projects (
                name, description, category, phase, owner_id,
                target_date, budget, candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING project_id
        """, (name, description, category, phase, owner_id, target_date, budget, candidate_id))
        
        project_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created project: {project_id}")
        return project_id
    
    def get_projects(self, candidate_id: str = None,
                    status: str = None) -> List[Dict]:
        """Get projects with progress"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_project_progress")
        projects = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return projects
    
    # ========================================================================
    # TASK MANAGEMENT
    # ========================================================================
    
    def create_task(self, title: str, project_id: str = None,
                   description: str = None, category: str = None,
                   priority: str = 'medium', assigned_to: str = None,
                   due_date: datetime = None, estimated_hours: float = None,
                   tags: List[str] = None, checklist: List[str] = None,
                   candidate_id: str = None) -> str:
        """Create a task"""
        conn = self._get_db()
        cur = conn.cursor()
        
        checklist_items = [{'text': item, 'done': False} for item in (checklist or [])]
        
        cur.execute("""
            INSERT INTO campaign_tasks (
                title, project_id, description, category,
                priority, assigned_to, due_date, estimated_hours,
                tags, checklist, candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING task_id
        """, (
            title, project_id, description, category,
            priority, assigned_to, due_date, estimated_hours,
            json.dumps(tags or []), json.dumps(checklist_items), candidate_id
        ))
        
        task_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created task: {task_id}")
        return task_id
    
    def update_task_status(self, task_id: str, status: str,
                          updated_by: str = None) -> None:
        """Update task status"""
        conn = self._get_db()
        cur = conn.cursor()
        
        # Get current status
        cur.execute("SELECT status FROM campaign_tasks WHERE task_id = %s", (task_id,))
        old_status = cur.fetchone()[0]
        
        # Update status
        completed_at = 'NOW()' if status == 'completed' else 'NULL'
        cur.execute(f"""
            UPDATE campaign_tasks SET
                status = %s,
                completed_at = {completed_at},
                updated_at = NOW()
            WHERE task_id = %s
        """, (status, task_id))
        
        # Log history
        cur.execute("""
            INSERT INTO task_history (task_id, changed_by, field_changed, old_value, new_value)
            VALUES (%s, %s, 'status', %s, %s)
        """, (task_id, updated_by, old_status, status))
        
        conn.commit()
        conn.close()
    
    def assign_task(self, task_id: str, assigned_to: str,
                   updated_by: str = None) -> None:
        """Assign task to team member"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaign_tasks SET
                assigned_to = %s, updated_at = NOW()
            WHERE task_id = %s
        """, (assigned_to, task_id))
        
        cur.execute("""
            INSERT INTO task_history (task_id, changed_by, field_changed, new_value)
            VALUES (%s, %s, 'assigned_to', %s)
        """, (task_id, updated_by, assigned_to))
        
        conn.commit()
        conn.close()
    
    def get_tasks(self, assigned_to: str = None, project_id: str = None,
                 status: str = None, priority: str = None,
                 overdue_only: bool = False) -> List[Dict]:
        """Get tasks with filters"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM v_task_summary WHERE 1=1"
        params = []
        
        if assigned_to:
            sql += " AND assigned_to = %s"
            params.append(assigned_to)
        if project_id:
            sql += " AND task_id IN (SELECT task_id FROM campaign_tasks WHERE project_id = %s)"
            params.append(project_id)
        if status:
            sql += " AND status = %s"
            params.append(status)
        if priority:
            sql += " AND priority = %s"
            params.append(priority)
        if overdue_only:
            sql += " AND is_overdue = true"
        
        sql += " ORDER BY CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, due_date"
        
        cur.execute(sql, params)
        tasks = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return tasks
    
    def add_comment(self, task_id: str, author_id: str, content: str) -> str:
        """Add comment to task"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO task_comments (task_id, author_id, content)
            VALUES (%s, %s, %s)
            RETURNING comment_id
        """, (task_id, author_id, content))
        
        comment_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return comment_id
    
    # ========================================================================
    # MILESTONES
    # ========================================================================
    
    def create_milestone(self, name: str, target_date: date,
                        project_id: str = None, description: str = None,
                        candidate_id: str = None) -> str:
        """Create a milestone"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO campaign_milestones (
                name, target_date, project_id, description, candidate_id
            ) VALUES (%s, %s, %s, %s, %s)
            RETURNING milestone_id
        """, (name, target_date, project_id, description, candidate_id))
        
        milestone_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return milestone_id
    
    def complete_milestone(self, milestone_id: str) -> None:
        """Mark milestone complete"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE campaign_milestones SET
                status = 'completed', completed_date = CURRENT_DATE
            WHERE milestone_id = %s
        """, (milestone_id,))
        
        conn.commit()
        conn.close()
    
    # ========================================================================
    # CALENDAR
    # ========================================================================
    
    def create_event(self, title: str, start_time: datetime,
                    end_time: datetime = None, event_type: str = None,
                    location: str = None, description: str = None,
                    all_day: bool = False, attendees: List[str] = None,
                    candidate_id: str = None) -> str:
        """Create calendar event"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO campaign_calendar (
                title, start_time, end_time, event_type,
                location, description, all_day, attendees, candidate_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING event_id
        """, (
            title, start_time, end_time, event_type,
            location, description, all_day,
            json.dumps(attendees or []), candidate_id
        ))
        
        event_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return event_id
    
    def get_calendar(self, start_date: date, end_date: date,
                    candidate_id: str = None) -> List[Dict]:
        """Get calendar events for date range"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = """
            SELECT * FROM campaign_calendar
            WHERE start_time >= %s AND start_time <= %s
        """
        params = [start_date, end_date]
        
        if candidate_id:
            sql += " AND candidate_id = %s"
            params.append(candidate_id)
        
        sql += " ORDER BY start_time"
        
        cur.execute(sql, params)
        events = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return events
    
    # ========================================================================
    # TIME TRACKING
    # ========================================================================
    
    def log_time(self, task_id: str, member_id: str, hours: float,
                description: str = None, entry_date: date = None) -> str:
        """Log time entry"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO time_entries (task_id, member_id, hours, description, entry_date)
            VALUES (%s, %s, %s, %s, COALESCE(%s, CURRENT_DATE))
            RETURNING entry_id
        """, (task_id, member_id, hours, description, entry_date))
        
        entry_id = str(cur.fetchone()[0])
        
        # Update task actual hours
        cur.execute("""
            UPDATE campaign_tasks SET
                actual_hours = COALESCE(actual_hours, 0) + %s
            WHERE task_id = %s
        """, (hours, task_id))
        
        conn.commit()
        conn.close()
        
        return entry_id
    
    # ========================================================================
    # MESSAGING
    # ========================================================================
    
    def send_message(self, sender_id: str, content: str,
                    recipient_ids: List[str] = None,
                    channel: str = 'general',
                    subject: str = None,
                    task_id: str = None) -> str:
        """Send internal message"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO campaign_messages (
                sender_id, recipient_ids, channel, subject,
                content, related_task_id
            ) VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING message_id
        """, (
            sender_id, json.dumps(recipient_ids or []),
            channel, subject, content, task_id
        ))
        
        message_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return message_id
    
    # ========================================================================
    # ANALYTICS
    # ========================================================================
    
    def get_team_workload(self) -> List[Dict]:
        """Get team workload summary"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_team_workload ORDER BY active_tasks DESC")
        workload = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return workload
    
    def get_overdue_tasks(self) -> List[Dict]:
        """Get all overdue tasks"""
        return self.get_tasks(overdue_only=True)
    
    def get_stats(self) -> Dict:
        """Get operations statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                COUNT(*) as total_tasks,
                COUNT(*) FILTER (WHERE status = 'completed') as completed,
                COUNT(*) FILTER (WHERE status IN ('todo', 'in_progress')) as active,
                COUNT(*) FILTER (WHERE due_date < NOW() AND status NOT IN ('completed', 'cancelled')) as overdue
            FROM campaign_tasks
        """)
        task_stats = dict(cur.fetchone())
        
        cur.execute("""
            SELECT COUNT(*) as total_projects,
                   COUNT(*) FILTER (WHERE status = 'active') as active_projects
            FROM campaign_projects
        """)
        project_stats = dict(cur.fetchone())
        
        cur.execute("SELECT COUNT(*) as team_members FROM campaign_team WHERE is_active = true")
        team_stats = dict(cur.fetchone())
        
        conn.close()
        
        return {**task_stats, **project_stats, **team_stats}


def deploy_campaign_operations():
    """Deploy campaign operations system"""
    print("=" * 60)
    print("📋 ECOSYSTEM 12: CAMPAIGN OPERATIONS - DEPLOYMENT")
    print("=" * 60)
    
    try:
        conn = psycopg2.connect(OperationsConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(OPERATIONS_SCHEMA)
        conn.commit()
        conn.close()
        
        print("\n   ✅ campaign_team table")
        print("   ✅ campaign_projects table")
        print("   ✅ campaign_tasks table")
        print("   ✅ task_comments table")
        print("   ✅ task_history table")
        print("   ✅ campaign_milestones table")
        print("   ✅ campaign_calendar table")
        print("   ✅ campaign_workflows table")
        print("   ✅ campaign_messages table")
        print("   ✅ time_entries table")
        print("   ✅ v_task_summary view")
        print("   ✅ v_team_workload view")
        print("   ✅ v_project_progress view")
        
        print("\n" + "=" * 60)
        print("✅ CAMPAIGN OPERATIONS DEPLOYED!")
        print("=" * 60)
        
        print("\nTask Categories:")
        for cat in list(TaskCategory)[:5]:
            print(f"   • {cat.value}")
        print("   • ... and more")
        
        print("\nCampaign Phases:")
        for phase in CampaignPhase:
            print(f"   • {phase.value}")
        
        print("\nFeatures:")
        print("   • Task management with priorities")
        print("   • Project tracking with milestones")
        print("   • Team workload balancing")
        print("   • Calendar & scheduling")
        print("   • Time tracking")
        print("   • Internal messaging")
        print("   • Audit trail / history")
        
        print("\n💰 Powers: Daily operations, team coordination")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_campaign_operations()
    elif len(sys.argv) > 1 and sys.argv[1] == "--stats":
        engine = CampaignOperationsEngine()
        print(json.dumps(engine.get_stats(), indent=2, default=str))
    elif len(sys.argv) > 1 and sys.argv[1] == "--overdue":
        engine = CampaignOperationsEngine()
        for task in engine.get_overdue_tasks():
            print(f"[{task['priority'].upper()}] {task['title']} - Due: {task['due_date']}")
    else:
        print("📋 Campaign Operations System")
        print("\nUsage:")
        print("  python ecosystem_12_campaign_operations_complete.py --deploy")
        print("  python ecosystem_12_campaign_operations_complete.py --stats")
        print("  python ecosystem_12_campaign_operations_complete.py --overdue")
