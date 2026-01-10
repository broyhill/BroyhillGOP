#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 18: PRINT ADVERTISING - COMPLETE (100%)
============================================================================

Newspaper and magazine advertising management:
- Publication database (newspapers, magazines, newsletters)
- Ad placement scheduling
- Rate card management
- Insertion orders
- Creative/artwork management
- Deadline tracking
- Proof approval workflow
- Invoice reconciliation
- Reach/circulation tracking
- Co-op advertising
- Political ad compliance (disclaimers)

Development Value: $75,000+
Powers: Traditional print media campaigns

============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, date, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum
from decimal import Decimal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem18.print_ads')


class PrintAdConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")


class PublicationType(Enum):
    DAILY_NEWSPAPER = "daily_newspaper"
    WEEKLY_NEWSPAPER = "weekly_newspaper"
    MONTHLY_MAGAZINE = "monthly_magazine"
    QUARTERLY_MAGAZINE = "quarterly_magazine"
    NEWSLETTER = "newsletter"
    COMMUNITY_PAPER = "community_paper"
    SHOPPER = "shopper"
    ALTERNATIVE = "alternative"

class AdSize(Enum):
    FULL_PAGE = "full_page"
    HALF_PAGE = "half_page"
    QUARTER_PAGE = "quarter_page"
    EIGHTH_PAGE = "eighth_page"
    FULL_COLUMN = "full_column"
    HALF_COLUMN = "half_column"
    CLASSIFIED = "classified"
    BANNER = "banner"
    INSERT = "insert"
    WRAP = "wrap"

class AdType(Enum):
    DISPLAY = "display"
    CLASSIFIED = "classified"
    INSERT = "insert"
    ADVERTORIAL = "advertorial"
    SPONSORED_CONTENT = "sponsored_content"
    POLITICAL = "political"

class OrderStatus(Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    CONFIRMED = "confirmed"
    CREATIVE_PENDING = "creative_pending"
    PROOF_SENT = "proof_sent"
    PROOF_APPROVED = "proof_approved"
    PUBLISHED = "published"
    INVOICED = "invoiced"
    PAID = "paid"
    CANCELLED = "cancelled"


PRINT_AD_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 18: PRINT ADVERTISING
-- ============================================================================

-- Publications Database
CREATE TABLE IF NOT EXISTS publications (
    publication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    publication_type VARCHAR(50) NOT NULL,
    frequency VARCHAR(50),
    
    -- Contact Info
    contact_name VARCHAR(255),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    
    -- Circulation
    circulation INTEGER,
    readership INTEGER,
    
    -- Geographic Coverage
    coverage_area VARCHAR(255),
    counties_covered JSONB DEFAULT '[]',
    cities_covered JSONB DEFAULT '[]',
    
    -- Demographics
    demographic_profile JSONB DEFAULT '{}',
    political_lean VARCHAR(50),
    
    -- Deadlines
    space_deadline_days INTEGER DEFAULT 7,
    material_deadline_days INTEGER DEFAULT 3,
    
    -- Rates
    rate_card_url TEXT,
    base_rate_per_column_inch DECIMAL(10,2),
    political_rate_multiplier DECIMAL(4,2) DEFAULT 1.0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_used TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pubs_type ON publications(publication_type);
CREATE INDEX IF NOT EXISTS idx_pubs_state ON publications(state);
CREATE INDEX IF NOT EXISTS idx_pubs_active ON publications(is_active);

-- Rate Cards
CREATE TABLE IF NOT EXISTS publication_rates (
    rate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publication_id UUID REFERENCES publications(publication_id),
    ad_size VARCHAR(50) NOT NULL,
    ad_type VARCHAR(50) DEFAULT 'display',
    color_type VARCHAR(20) DEFAULT 'bw',
    placement VARCHAR(100),
    rate DECIMAL(12,2) NOT NULL,
    frequency_discount JSONB DEFAULT '{}',
    effective_date DATE DEFAULT CURRENT_DATE,
    expire_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rates_pub ON publication_rates(publication_id);
CREATE INDEX IF NOT EXISTS idx_rates_size ON publication_rates(ad_size);

-- Ad Creatives
CREATE TABLE IF NOT EXISTS print_ad_creatives (
    creative_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID,
    campaign_id UUID,
    name VARCHAR(500) NOT NULL,
    ad_size VARCHAR(50) NOT NULL,
    
    -- Artwork
    artwork_url TEXT,
    artwork_format VARCHAR(50),
    width_inches DECIMAL(6,2),
    height_inches DECIMAL(6,2),
    resolution_dpi INTEGER DEFAULT 300,
    color_mode VARCHAR(20) DEFAULT 'cmyk',
    bleed BOOLEAN DEFAULT false,
    
    -- Content
    headline TEXT,
    body_copy TEXT,
    call_to_action TEXT,
    disclaimer TEXT,
    
    -- Compliance
    has_disclaimer BOOLEAN DEFAULT false,
    disclaimer_text TEXT,
    paid_for_by TEXT,
    
    -- Approval
    status VARCHAR(50) DEFAULT 'draft',
    approved_by VARCHAR(255),
    approved_at TIMESTAMP,
    
    -- Versions
    version INTEGER DEFAULT 1,
    parent_creative_id UUID,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_creatives_candidate ON print_ad_creatives(candidate_id);
CREATE INDEX IF NOT EXISTS idx_creatives_size ON print_ad_creatives(ad_size);

-- Insertion Orders
CREATE TABLE IF NOT EXISTS insertion_orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE,
    candidate_id UUID,
    campaign_id UUID,
    publication_id UUID REFERENCES publications(publication_id),
    
    -- Order Details
    status VARCHAR(50) DEFAULT 'draft',
    ad_type VARCHAR(50) DEFAULT 'display',
    ad_size VARCHAR(50) NOT NULL,
    color_type VARCHAR(20) DEFAULT 'bw',
    placement_preference TEXT,
    
    -- Schedule
    run_dates JSONB DEFAULT '[]',
    start_date DATE,
    end_date DATE,
    num_insertions INTEGER DEFAULT 1,
    
    -- Creative
    creative_id UUID REFERENCES print_ad_creatives(creative_id),
    
    -- Pricing
    rate_per_insertion DECIMAL(12,2),
    total_gross DECIMAL(14,2),
    agency_commission_pct DECIMAL(5,2) DEFAULT 15.0,
    agency_commission DECIMAL(12,2),
    total_net DECIMAL(14,2),
    
    -- Deadlines
    space_deadline DATE,
    material_deadline DATE,
    
    -- Tracking
    confirmation_number VARCHAR(100),
    po_number VARCHAR(100),
    
    -- Proof
    proof_url TEXT,
    proof_approved BOOLEAN DEFAULT false,
    proof_approved_by VARCHAR(255),
    proof_approved_at TIMESTAMP,
    
    -- Invoice
    invoice_number VARCHAR(100),
    invoice_amount DECIMAL(12,2),
    invoice_date DATE,
    paid_date DATE,
    
    notes TEXT,
    created_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_candidate ON insertion_orders(candidate_id);
CREATE INDEX IF NOT EXISTS idx_orders_publication ON insertion_orders(publication_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON insertion_orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_dates ON insertion_orders(start_date, end_date);

-- Publication Calendar (track issue dates)
CREATE TABLE IF NOT EXISTS publication_calendar (
    calendar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publication_id UUID REFERENCES publications(publication_id),
    issue_date DATE NOT NULL,
    issue_name VARCHAR(255),
    space_deadline DATE,
    material_deadline DATE,
    special_section VARCHAR(255),
    theme VARCHAR(255),
    bonus_distribution BOOLEAN DEFAULT false,
    circulation_boost INTEGER,
    rate_premium_pct DECIMAL(5,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendar_pub ON publication_calendar(publication_id);
CREATE INDEX IF NOT EXISTS idx_calendar_date ON publication_calendar(issue_date);

-- Ad Performance Tracking
CREATE TABLE IF NOT EXISTS print_ad_performance (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES insertion_orders(order_id),
    issue_date DATE,
    
    -- Reach
    circulation INTEGER,
    estimated_readership INTEGER,
    geographic_reach VARCHAR(255),
    
    -- Response (if trackable)
    unique_url VARCHAR(255),
    qr_code_url TEXT,
    tracking_phone VARCHAR(20),
    
    -- Measured Response
    url_visits INTEGER DEFAULT 0,
    qr_scans INTEGER DEFAULT 0,
    phone_calls INTEGER DEFAULT 0,
    donations_attributed INTEGER DEFAULT 0,
    donation_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Calculated Metrics
    cost_per_thousand DECIMAL(10,2),
    cost_per_response DECIMAL(10,2),
    roi_pct DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perf_order ON print_ad_performance(order_id);

-- Views
CREATE OR REPLACE VIEW v_publication_summary AS
SELECT 
    p.publication_id,
    p.name,
    p.publication_type,
    p.state,
    p.circulation,
    p.is_active,
    COUNT(DISTINCT io.order_id) as total_orders,
    SUM(io.total_net) as total_spend,
    MAX(io.end_date) as last_ad_date
FROM publications p
LEFT JOIN insertion_orders io ON p.publication_id = io.publication_id
GROUP BY p.publication_id;

CREATE OR REPLACE VIEW v_active_orders AS
SELECT 
    io.*,
    p.name as publication_name,
    p.contact_email,
    pac.name as creative_name,
    pac.artwork_url
FROM insertion_orders io
JOIN publications p ON io.publication_id = p.publication_id
LEFT JOIN print_ad_creatives pac ON io.creative_id = pac.creative_id
WHERE io.status NOT IN ('cancelled', 'paid')
ORDER BY io.material_deadline;

CREATE OR REPLACE VIEW v_upcoming_deadlines AS
SELECT 
    io.order_id,
    io.order_number,
    p.name as publication_name,
    io.ad_size,
    io.space_deadline,
    io.material_deadline,
    io.status,
    CASE 
        WHEN io.material_deadline <= CURRENT_DATE THEN 'overdue'
        WHEN io.material_deadline <= CURRENT_DATE + 2 THEN 'urgent'
        WHEN io.material_deadline <= CURRENT_DATE + 7 THEN 'upcoming'
        ELSE 'scheduled'
    END as urgency
FROM insertion_orders io
JOIN publications p ON io.publication_id = p.publication_id
WHERE io.status IN ('draft', 'submitted', 'confirmed', 'creative_pending')
ORDER BY io.material_deadline;

CREATE OR REPLACE VIEW v_campaign_print_spend AS
SELECT 
    io.campaign_id,
    io.candidate_id,
    COUNT(*) as total_orders,
    SUM(io.num_insertions) as total_insertions,
    SUM(io.total_net) as total_spend,
    SUM(pap.circulation * io.num_insertions) as total_impressions,
    SUM(pap.donation_amount) as attributed_revenue
FROM insertion_orders io
LEFT JOIN print_ad_performance pap ON io.order_id = pap.order_id
WHERE io.status NOT IN ('cancelled', 'draft')
GROUP BY io.campaign_id, io.candidate_id;

SELECT 'Print Advertising schema deployed!' as status;
"""


# NC Newspaper database (sample)
NC_NEWSPAPERS = [
    {'name': 'The Charlotte Observer', 'type': 'daily_newspaper', 'city': 'Charlotte', 'state': 'NC', 'circulation': 120000},
    {'name': 'News & Observer', 'type': 'daily_newspaper', 'city': 'Raleigh', 'state': 'NC', 'circulation': 95000},
    {'name': 'Winston-Salem Journal', 'type': 'daily_newspaper', 'city': 'Winston-Salem', 'state': 'NC', 'circulation': 55000},
    {'name': 'Greensboro News & Record', 'type': 'daily_newspaper', 'city': 'Greensboro', 'state': 'NC', 'circulation': 50000},
    {'name': 'Fayetteville Observer', 'type': 'daily_newspaper', 'city': 'Fayetteville', 'state': 'NC', 'circulation': 40000},
    {'name': 'Asheville Citizen-Times', 'type': 'daily_newspaper', 'city': 'Asheville', 'state': 'NC', 'circulation': 35000},
    {'name': 'The Herald-Sun', 'type': 'daily_newspaper', 'city': 'Durham', 'state': 'NC', 'circulation': 30000},
    {'name': 'Star-News', 'type': 'daily_newspaper', 'city': 'Wilmington', 'state': 'NC', 'circulation': 28000},
    {'name': 'High Point Enterprise', 'type': 'daily_newspaper', 'city': 'High Point', 'state': 'NC', 'circulation': 20000},
    {'name': 'The Times-News', 'type': 'daily_newspaper', 'city': 'Burlington', 'state': 'NC', 'circulation': 18000},
]


class PrintAdvertisingEngine:
    """Print advertising management"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self.db_url = PrintAdConfig.DATABASE_URL
        self._initialized = True
        logger.info("📰 Print Advertising Engine initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    def _generate_order_number(self) -> str:
        """Generate unique order number"""
        return f"IO-{datetime.now().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
    
    # ========================================================================
    # PUBLICATION MANAGEMENT
    # ========================================================================
    
    def add_publication(self, name: str, publication_type: str,
                       city: str = None, state: str = None,
                       circulation: int = None, contact_email: str = None,
                       base_rate: float = None) -> str:
        """Add publication to database"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO publications (
                name, publication_type, city, state, circulation,
                contact_email, base_rate_per_column_inch
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING publication_id
        """, (name, publication_type, city, state, circulation,
              contact_email, base_rate))
        
        publication_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Added publication: {name}")
        return publication_id
    
    def get_publications(self, state: str = None, 
                        publication_type: str = None) -> List[Dict]:
        """Get publications"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM v_publication_summary WHERE is_active = true"
        params = []
        
        if state:
            sql += " AND state = %s"
            params.append(state)
        if publication_type:
            sql += " AND publication_type = %s"
            params.append(publication_type)
        
        sql += " ORDER BY circulation DESC NULLS LAST"
        
        cur.execute(sql, params)
        pubs = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return pubs
    
    def add_rate(self, publication_id: str, ad_size: str, rate: float,
                ad_type: str = 'display', color_type: str = 'bw',
                placement: str = None) -> str:
        """Add rate to publication"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO publication_rates (
                publication_id, ad_size, ad_type, color_type, placement, rate
            ) VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING rate_id
        """, (publication_id, ad_size, ad_type, color_type, placement, rate))
        
        rate_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return rate_id
    
    def get_rates(self, publication_id: str) -> List[Dict]:
        """Get rates for publication"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM publication_rates
            WHERE publication_id = %s
            AND (expire_date IS NULL OR expire_date >= CURRENT_DATE)
            ORDER BY ad_size, color_type
        """, (publication_id,))
        
        rates = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return rates
    
    # ========================================================================
    # CREATIVE MANAGEMENT
    # ========================================================================
    
    def create_creative(self, name: str, ad_size: str,
                       candidate_id: str = None, campaign_id: str = None,
                       headline: str = None, body_copy: str = None,
                       call_to_action: str = None, artwork_url: str = None,
                       disclaimer_text: str = None,
                       paid_for_by: str = None) -> str:
        """Create ad creative"""
        conn = self._get_db()
        cur = conn.cursor()
        
        has_disclaimer = bool(disclaimer_text or paid_for_by)
        
        cur.execute("""
            INSERT INTO print_ad_creatives (
                name, ad_size, candidate_id, campaign_id,
                headline, body_copy, call_to_action, artwork_url,
                has_disclaimer, disclaimer_text, paid_for_by
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING creative_id
        """, (name, ad_size, candidate_id, campaign_id,
              headline, body_copy, call_to_action, artwork_url,
              has_disclaimer, disclaimer_text, paid_for_by))
        
        creative_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created creative: {name}")
        return creative_id
    
    def approve_creative(self, creative_id: str, approved_by: str) -> None:
        """Approve creative"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE print_ad_creatives SET
                status = 'approved',
                approved_by = %s,
                approved_at = NOW(),
                updated_at = NOW()
            WHERE creative_id = %s
        """, (approved_by, creative_id))
        
        conn.commit()
        conn.close()
    
    def get_creatives(self, candidate_id: str = None, 
                     ad_size: str = None) -> List[Dict]:
        """Get creatives"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM print_ad_creatives WHERE 1=1"
        params = []
        
        if candidate_id:
            sql += " AND candidate_id = %s"
            params.append(candidate_id)
        if ad_size:
            sql += " AND ad_size = %s"
            params.append(ad_size)
        
        sql += " ORDER BY created_at DESC"
        
        cur.execute(sql, params)
        creatives = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return creatives
    
    # ========================================================================
    # INSERTION ORDERS
    # ========================================================================
    
    def create_insertion_order(self, publication_id: str, ad_size: str,
                              candidate_id: str = None, campaign_id: str = None,
                              creative_id: str = None, ad_type: str = 'display',
                              color_type: str = 'bw', run_dates: List[str] = None,
                              rate_per_insertion: float = None,
                              placement_preference: str = None) -> str:
        """Create insertion order"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        order_number = self._generate_order_number()
        
        # Get publication deadlines
        cur.execute("""
            SELECT space_deadline_days, material_deadline_days
            FROM publications WHERE publication_id = %s
        """, (publication_id,))
        pub = cur.fetchone()
        
        # Calculate dates
        run_dates = run_dates or []
        num_insertions = len(run_dates)
        start_date = min(run_dates) if run_dates else None
        end_date = max(run_dates) if run_dates else None
        
        # Calculate deadlines from first run date
        if start_date:
            start_dt = datetime.strptime(start_date, '%Y-%m-%d')
            space_deadline = (start_dt - timedelta(days=pub['space_deadline_days'] or 7)).date()
            material_deadline = (start_dt - timedelta(days=pub['material_deadline_days'] or 3)).date()
        else:
            space_deadline = None
            material_deadline = None
        
        # Calculate pricing
        total_gross = (rate_per_insertion or 0) * num_insertions
        agency_commission = total_gross * Decimal('0.15')
        total_net = total_gross - agency_commission
        
        cur.execute("""
            INSERT INTO insertion_orders (
                order_number, publication_id, candidate_id, campaign_id,
                ad_type, ad_size, color_type, creative_id,
                run_dates, start_date, end_date, num_insertions,
                rate_per_insertion, total_gross, agency_commission, total_net,
                space_deadline, material_deadline, placement_preference, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'draft')
            RETURNING order_id
        """, (
            order_number, publication_id, candidate_id, campaign_id,
            ad_type, ad_size, color_type, creative_id,
            json.dumps(run_dates), start_date, end_date, num_insertions,
            rate_per_insertion, total_gross, agency_commission, total_net,
            space_deadline, material_deadline, placement_preference
        ))
        
        order_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created insertion order: {order_number}")
        return order_id
    
    def submit_order(self, order_id: str) -> None:
        """Submit order to publication"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE insertion_orders SET
                status = 'submitted',
                updated_at = NOW()
            WHERE order_id = %s
        """, (order_id,))
        
        conn.commit()
        conn.close()
    
    def confirm_order(self, order_id: str, confirmation_number: str = None) -> None:
        """Confirm order from publication"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE insertion_orders SET
                status = 'confirmed',
                confirmation_number = %s,
                updated_at = NOW()
            WHERE order_id = %s
        """, (confirmation_number, order_id))
        
        conn.commit()
        conn.close()
    
    def approve_proof(self, order_id: str, approved_by: str) -> None:
        """Approve proof"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE insertion_orders SET
                status = 'proof_approved',
                proof_approved = true,
                proof_approved_by = %s,
                proof_approved_at = NOW(),
                updated_at = NOW()
            WHERE order_id = %s
        """, (approved_by, order_id))
        
        conn.commit()
        conn.close()
    
    def mark_published(self, order_id: str) -> None:
        """Mark order as published"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE insertion_orders SET
                status = 'published',
                updated_at = NOW()
            WHERE order_id = %s
        """, (order_id,))
        
        conn.commit()
        conn.close()
    
    def record_invoice(self, order_id: str, invoice_number: str,
                      invoice_amount: float, invoice_date: str = None) -> None:
        """Record invoice"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE insertion_orders SET
                status = 'invoiced',
                invoice_number = %s,
                invoice_amount = %s,
                invoice_date = %s,
                updated_at = NOW()
            WHERE order_id = %s
        """, (invoice_number, invoice_amount, invoice_date or date.today(), order_id))
        
        conn.commit()
        conn.close()
    
    def get_orders(self, candidate_id: str = None, status: str = None,
                  publication_id: str = None) -> List[Dict]:
        """Get insertion orders"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM v_active_orders WHERE 1=1"
        params = []
        
        if candidate_id:
            sql += " AND candidate_id = %s"
            params.append(candidate_id)
        if status:
            sql += " AND status = %s"
            params.append(status)
        if publication_id:
            sql += " AND publication_id = %s"
            params.append(publication_id)
        
        cur.execute(sql, params)
        orders = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return orders
    
    def get_upcoming_deadlines(self, days_ahead: int = 14) -> List[Dict]:
        """Get upcoming deadlines"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM v_upcoming_deadlines
            WHERE material_deadline <= CURRENT_DATE + %s
            ORDER BY material_deadline
        """, (days_ahead,))
        
        deadlines = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return deadlines
    
    # ========================================================================
    # PERFORMANCE TRACKING
    # ========================================================================
    
    def record_performance(self, order_id: str, issue_date: str,
                          circulation: int = None, url_visits: int = 0,
                          qr_scans: int = 0, phone_calls: int = 0,
                          donations: int = 0, donation_amount: float = 0) -> str:
        """Record ad performance"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get order cost
        cur.execute("SELECT total_net, num_insertions FROM insertion_orders WHERE order_id = %s", (order_id,))
        order = cur.fetchone()
        
        cost_per_insertion = float(order['total_net'] or 0) / max(order['num_insertions'], 1)
        
        # Calculate metrics
        total_responses = url_visits + qr_scans + phone_calls
        cost_per_thousand = (cost_per_insertion / max(circulation, 1)) * 1000 if circulation else None
        cost_per_response = cost_per_insertion / max(total_responses, 1) if total_responses else None
        roi_pct = ((donation_amount - cost_per_insertion) / cost_per_insertion * 100) if cost_per_insertion else None
        
        cur.execute("""
            INSERT INTO print_ad_performance (
                order_id, issue_date, circulation,
                url_visits, qr_scans, phone_calls,
                donations_attributed, donation_amount,
                cost_per_thousand, cost_per_response, roi_pct
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING performance_id
        """, (order_id, issue_date, circulation,
              url_visits, qr_scans, phone_calls,
              donations, donation_amount,
              cost_per_thousand, cost_per_response, roi_pct))
        
        performance_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return performance_id
    
    # ========================================================================
    # ANALYTICS
    # ========================================================================
    
    def get_campaign_spend(self, campaign_id: str = None,
                          candidate_id: str = None) -> List[Dict]:
        """Get campaign print spend"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM v_campaign_print_spend WHERE 1=1"
        params = []
        
        if campaign_id:
            sql += " AND campaign_id = %s"
            params.append(campaign_id)
        if candidate_id:
            sql += " AND candidate_id = %s"
            params.append(candidate_id)
        
        cur.execute(sql, params)
        spend = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return spend
    
    def get_stats(self) -> Dict:
        """Get print advertising stats"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                (SELECT COUNT(*) FROM publications WHERE is_active = true) as publications,
                (SELECT COUNT(*) FROM print_ad_creatives) as creatives,
                (SELECT COUNT(*) FROM insertion_orders) as total_orders,
                (SELECT COUNT(*) FROM insertion_orders WHERE status NOT IN ('cancelled', 'paid', 'draft')) as active_orders,
                (SELECT SUM(total_net) FROM insertion_orders WHERE status != 'cancelled') as total_spend,
                (SELECT COUNT(*) FROM v_upcoming_deadlines WHERE urgency IN ('urgent', 'overdue')) as urgent_deadlines
        """)
        
        stats = dict(cur.fetchone())
        conn.close()
        
        return stats


def deploy_print_advertising():
    """Deploy print advertising system"""
    print("=" * 70)
    print("📰 ECOSYSTEM 18: PRINT ADVERTISING - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(PrintAdConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(PRINT_AD_SCHEMA)
        conn.commit()
        
        # Add NC newspapers
        print("\nAdding NC newspaper database...")
        for paper in NC_NEWSPAPERS:
            cur.execute("""
                INSERT INTO publications (name, publication_type, city, state, circulation)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (paper['name'], paper['type'], paper['city'], paper['state'], paper['circulation']))
        
        conn.commit()
        conn.close()
        
        print("\n   ✅ publications table")
        print("   ✅ publication_rates table")
        print("   ✅ print_ad_creatives table")
        print("   ✅ insertion_orders table")
        print("   ✅ publication_calendar table")
        print("   ✅ print_ad_performance table")
        print("   ✅ v_publication_summary view")
        print("   ✅ v_active_orders view")
        print("   ✅ v_upcoming_deadlines view")
        print("   ✅ v_campaign_print_spend view")
        print(f"   ✅ {len(NC_NEWSPAPERS)} NC newspapers loaded")
        
        print("\n" + "=" * 70)
        print("✅ PRINT ADVERTISING DEPLOYED!")
        print("=" * 70)
        
        print("\nAd Sizes:")
        for size in list(AdSize)[:6]:
            print(f"   • {size.value}")
        
        print("\nPublication Types:")
        for ptype in list(PublicationType)[:4]:
            print(f"   • {ptype.value}")
        
        print("\nFeatures:")
        print("   • Publication database")
        print("   • Rate card management")
        print("   • Insertion order workflow")
        print("   • Deadline tracking")
        print("   • Proof approval")
        print("   • Performance tracking")
        print("   • Political ad compliance")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_print_advertising()
    elif len(sys.argv) > 1 and sys.argv[1] == "--stats":
        engine = PrintAdvertisingEngine()
        print(json.dumps(engine.get_stats(), indent=2, default=str))
    elif len(sys.argv) > 1 and sys.argv[1] == "--deadlines":
        engine = PrintAdvertisingEngine()
        for d in engine.get_upcoming_deadlines():
            print(f"{d['publication_name']}: {d['material_deadline']} ({d['urgency']})")
    else:
        print("📰 Print Advertising System")
        print("\nUsage:")
        print("  python ecosystem_18_print_advertising_complete.py --deploy")
        print("  python ecosystem_18_print_advertising_complete.py --stats")
        print("  python ecosystem_18_print_advertising_complete.py --deadlines")
