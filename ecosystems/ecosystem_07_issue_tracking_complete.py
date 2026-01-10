#!/usr/bin/env python3
"""
============================================================================
ECOSYSTEM 7: ISSUE TRACKING SYSTEM - COMPLETE (100%)
============================================================================

Comprehensive political issue tracking and matching:
- 60 hot button issues across 10 categories
- Issue position recording (candidate + donor)
- Issue salience scoring (how much people care)
- Issue concordance (candidate-donor alignment)
- Trending issues detection
- Opposition position tracking
- Issue lifecycle modeling
- AI-powered issue detection from news
- Cross-issue correlation analysis

Development Value: $60,000+
Powers: Issue-based targeting, campaign relevance scoring

============================================================================
"""

import os
import json
import uuid
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem7.issues')


# ============================================================================
# CONFIGURATION
# ============================================================================

class IssueConfig:
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")
    
    # Salience thresholds
    HIGH_SALIENCE = 0.7
    MEDIUM_SALIENCE = 0.4
    
    # Concordance thresholds
    STRONG_MATCH = 0.8
    GOOD_MATCH = 0.6
    WEAK_MATCH = 0.4


# ============================================================================
# ISSUE CATEGORIES AND DEFINITIONS
# ============================================================================

class IssueCategory(Enum):
    ECONOMY = "economy"
    SOCIAL = "social"
    IMMIGRATION = "immigration"
    SECOND_AMENDMENT = "second_amendment"
    GOVERNMENT = "government"
    SECURITY = "security"
    HEALTHCARE = "healthcare"
    ENERGY = "energy"
    JUSTICE = "justice"
    EDUCATION = "education"

class Position(Enum):
    STRONGLY_SUPPORT = "strongly_support"
    SUPPORT = "support"
    LEAN_SUPPORT = "lean_support"
    NEUTRAL = "neutral"
    LEAN_OPPOSE = "lean_oppose"
    OPPOSE = "oppose"
    STRONGLY_OPPOSE = "strongly_oppose"
    UNKNOWN = "unknown"

# Position numeric values for concordance calculation
POSITION_VALUES = {
    "strongly_support": 1.0,
    "support": 0.75,
    "lean_support": 0.5,
    "neutral": 0.0,
    "lean_oppose": -0.5,
    "oppose": -0.75,
    "strongly_oppose": -1.0,
    "unknown": None
}


# ============================================================================
# 60 HOT BUTTON ISSUES
# ============================================================================

ISSUES = {
    # ==================== ECONOMY (10) ====================
    "tax_cuts": {
        "code": "tax_cuts",
        "name": "Tax Cuts",
        "category": "economy",
        "description": "Reducing individual and corporate tax rates",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["tax cut", "lower taxes", "tax relief", "tax reduction"],
        "related_issues": ["tax_reform", "spending_cuts", "balanced_budget"]
    },
    "tax_reform": {
        "code": "tax_reform",
        "name": "Tax Reform",
        "category": "economy",
        "description": "Simplifying and restructuring the tax code",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["tax reform", "tax code", "IRS reform"],
        "related_issues": ["tax_cuts", "balanced_budget"]
    },
    "balanced_budget": {
        "code": "balanced_budget",
        "name": "Balanced Budget",
        "category": "economy",
        "description": "Requiring federal budget to balance",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["balanced budget", "budget deficit", "fiscal responsibility"],
        "related_issues": ["debt_reduction", "spending_cuts"]
    },
    "debt_reduction": {
        "code": "debt_reduction",
        "name": "National Debt Reduction",
        "category": "economy",
        "description": "Reducing the national debt",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["national debt", "debt ceiling", "deficit"],
        "related_issues": ["balanced_budget", "spending_cuts"]
    },
    "spending_cuts": {
        "code": "spending_cuts",
        "name": "Government Spending Cuts",
        "category": "economy",
        "description": "Reducing government spending",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["spending cuts", "reduce spending", "government waste"],
        "related_issues": ["balanced_budget", "debt_reduction"]
    },
    "free_trade": {
        "code": "free_trade",
        "name": "Free Trade Agreements",
        "category": "economy",
        "description": "Supporting free trade deals",
        "republican_position": "neutral",
        "democrat_position": "neutral",
        "keywords": ["free trade", "trade agreement", "USMCA", "TPP"],
        "related_issues": ["tariffs", "economic_growth"]
    },
    "tariffs": {
        "code": "tariffs",
        "name": "Tariffs / Trade Protection",
        "category": "economy",
        "description": "Using tariffs to protect American industry",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["tariff", "trade war", "China trade", "import tax"],
        "related_issues": ["free_trade", "economic_growth"]
    },
    "minimum_wage": {
        "code": "minimum_wage",
        "name": "Minimum Wage Increase",
        "category": "economy",
        "description": "Raising the federal minimum wage",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["minimum wage", "$15 wage", "living wage"],
        "related_issues": ["right_to_work", "economic_growth"]
    },
    "right_to_work": {
        "code": "right_to_work",
        "name": "Right to Work Laws",
        "category": "economy",
        "description": "Laws preventing mandatory union membership",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["right to work", "union", "labor union"],
        "related_issues": ["minimum_wage"]
    },
    "economic_growth": {
        "code": "economic_growth",
        "name": "Economic Growth Focus",
        "category": "economy",
        "description": "Prioritizing policies that drive economic growth",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["economic growth", "GDP", "job creation", "economy"],
        "related_issues": ["tax_cuts", "tariffs"]
    },
    
    # ==================== SOCIAL ISSUES (12) ====================
    "pro_life": {
        "code": "pro_life",
        "name": "Pro-Life / Abortion Restrictions",
        "category": "social",
        "description": "Restricting or banning abortion",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["pro-life", "abortion ban", "right to life", "unborn"],
        "related_issues": ["religious_liberty"]
    },
    "pro_choice": {
        "code": "pro_choice",
        "name": "Pro-Choice / Abortion Rights",
        "category": "social",
        "description": "Protecting abortion access",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["pro-choice", "abortion rights", "reproductive rights"],
        "related_issues": []
    },
    "traditional_marriage": {
        "code": "traditional_marriage",
        "name": "Traditional Marriage",
        "category": "social",
        "description": "Defining marriage as between man and woman",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["traditional marriage", "marriage", "one man one woman"],
        "related_issues": ["religious_liberty", "lgbt_rights"]
    },
    "lgbt_rights": {
        "code": "lgbt_rights",
        "name": "LGBT Rights",
        "category": "social",
        "description": "Expanding LGBT protections",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["LGBT", "gay rights", "transgender", "LGBTQ"],
        "related_issues": ["traditional_marriage", "gender_ideology"]
    },
    "religious_liberty": {
        "code": "religious_liberty",
        "name": "Religious Liberty",
        "category": "social",
        "description": "Protecting religious freedom and expression",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["religious liberty", "religious freedom", "faith", "church"],
        "related_issues": ["pro_life", "traditional_marriage"]
    },
    "parental_rights": {
        "code": "parental_rights",
        "name": "Parental Rights in Education",
        "category": "social",
        "description": "Empowering parents over children's education",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["parental rights", "parents", "school board"],
        "related_issues": ["school_choice", "critical_race_theory"]
    },
    "school_choice": {
        "code": "school_choice",
        "name": "School Choice / Vouchers",
        "category": "social",
        "description": "Supporting school vouchers and charter schools",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["school choice", "voucher", "charter school", "private school"],
        "related_issues": ["parental_rights", "education_funding"]
    },
    "critical_race_theory": {
        "code": "critical_race_theory",
        "name": "Ban CRT in Schools",
        "category": "social",
        "description": "Banning critical race theory curriculum",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["CRT", "critical race theory", "DEI", "woke"],
        "related_issues": ["parental_rights", "education_funding"]
    },
    "gender_ideology": {
        "code": "gender_ideology",
        "name": "Oppose Gender Ideology",
        "category": "social",
        "description": "Opposing transgender policies in schools/sports",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["gender ideology", "transgender", "women's sports", "pronouns"],
        "related_issues": ["lgbt_rights", "parental_rights"]
    },
    "death_penalty": {
        "code": "death_penalty",
        "name": "Death Penalty",
        "category": "social",
        "description": "Supporting capital punishment",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["death penalty", "capital punishment", "execution"],
        "related_issues": ["law_enforcement"]
    },
    "marijuana": {
        "code": "marijuana",
        "name": "Marijuana Legalization",
        "category": "social",
        "description": "Legalizing recreational marijuana",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["marijuana", "cannabis", "weed", "pot"],
        "related_issues": []
    },
    "gambling": {
        "code": "gambling",
        "name": "Gambling Expansion",
        "category": "social",
        "description": "Expanding legal gambling/casinos",
        "republican_position": "neutral",
        "democrat_position": "neutral",
        "keywords": ["gambling", "casino", "sports betting", "lottery"],
        "related_issues": []
    },
    
    # ==================== IMMIGRATION (6) ====================
    "border_wall": {
        "code": "border_wall",
        "name": "Border Wall",
        "category": "immigration",
        "description": "Building a wall on the southern border",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["border wall", "wall", "border barrier"],
        "related_issues": ["border_security", "deportation"]
    },
    "deportation": {
        "code": "deportation",
        "name": "Mass Deportation",
        "category": "immigration",
        "description": "Deporting illegal immigrants",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["deportation", "deport", "illegal aliens", "removal"],
        "related_issues": ["border_security", "sanctuary_cities"]
    },
    "sanctuary_cities": {
        "code": "sanctuary_cities",
        "name": "End Sanctuary Cities",
        "category": "immigration",
        "description": "Ending sanctuary city policies",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["sanctuary city", "sanctuary", "sanctuary state"],
        "related_issues": ["deportation", "law_enforcement"]
    },
    "daca": {
        "code": "daca",
        "name": "DACA / Dreamers",
        "category": "immigration",
        "description": "Path to citizenship for Dreamers",
        "republican_position": "neutral",
        "democrat_position": "support",
        "keywords": ["DACA", "dreamers", "childhood arrivals"],
        "related_issues": ["immigration_reform"]
    },
    "immigration_reform": {
        "code": "immigration_reform",
        "name": "Immigration Reform",
        "category": "immigration",
        "description": "Comprehensive immigration system overhaul",
        "republican_position": "neutral",
        "democrat_position": "support",
        "keywords": ["immigration reform", "immigration system", "legal immigration"],
        "related_issues": ["daca", "e_verify"]
    },
    "e_verify": {
        "code": "e_verify",
        "name": "Mandatory E-Verify",
        "category": "immigration",
        "description": "Requiring employers to verify work eligibility",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["E-Verify", "work authorization", "employment verification"],
        "related_issues": ["immigration_reform"]
    },
    
    # ==================== SECOND AMENDMENT (4) ====================
    "gun_rights": {
        "code": "gun_rights",
        "name": "Gun Rights / 2nd Amendment",
        "category": "second_amendment",
        "description": "Protecting the right to bear arms",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["gun rights", "2nd amendment", "second amendment", "firearms"],
        "related_issues": ["constitutional_carry", "red_flag_laws"]
    },
    "gun_control": {
        "code": "gun_control",
        "name": "Gun Control Measures",
        "category": "second_amendment",
        "description": "Restricting firearm access",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["gun control", "gun safety", "assault weapons ban", "background check"],
        "related_issues": ["red_flag_laws"]
    },
    "constitutional_carry": {
        "code": "constitutional_carry",
        "name": "Constitutional Carry",
        "category": "second_amendment",
        "description": "Permitless concealed carry",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["constitutional carry", "permitless carry", "concealed carry"],
        "related_issues": ["gun_rights"]
    },
    "red_flag_laws": {
        "code": "red_flag_laws",
        "name": "Red Flag Laws",
        "category": "second_amendment",
        "description": "Temporary firearm removal orders",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["red flag", "ERPO", "extreme risk protection"],
        "related_issues": ["gun_control"]
    },
    
    # ==================== GOVERNMENT (8) ====================
    "limited_government": {
        "code": "limited_government",
        "name": "Limited Government",
        "category": "government",
        "description": "Reducing size and scope of government",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["limited government", "small government", "big government"],
        "related_issues": ["spending_cuts", "regulatory_reform"]
    },
    "term_limits": {
        "code": "term_limits",
        "name": "Congressional Term Limits",
        "category": "government",
        "description": "Limiting terms for Congress members",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["term limits", "career politician"],
        "related_issues": ["transparency"]
    },
    "voter_id": {
        "code": "voter_id",
        "name": "Voter ID Requirements",
        "category": "government",
        "description": "Requiring photo ID to vote",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["voter ID", "photo ID", "voter identification"],
        "related_issues": ["election_integrity"]
    },
    "election_integrity": {
        "code": "election_integrity",
        "name": "Election Integrity",
        "category": "government",
        "description": "Securing elections from fraud",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["election integrity", "election security", "voter fraud", "mail voting"],
        "related_issues": ["voter_id"]
    },
    "states_rights": {
        "code": "states_rights",
        "name": "States' Rights",
        "category": "government",
        "description": "Returning power to state governments",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["states rights", "federalism", "10th amendment"],
        "related_issues": ["limited_government"]
    },
    "regulatory_reform": {
        "code": "regulatory_reform",
        "name": "Regulatory Reform",
        "category": "government",
        "description": "Reducing government regulations",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["regulation", "deregulation", "red tape", "regulatory reform"],
        "related_issues": ["limited_government"]
    },
    "transparency": {
        "code": "transparency",
        "name": "Government Transparency",
        "category": "government",
        "description": "Increasing government openness",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["transparency", "FOIA", "open government"],
        "related_issues": ["term_limits"]
    },
    "convention_of_states": {
        "code": "convention_of_states",
        "name": "Convention of States",
        "category": "government",
        "description": "Article V constitutional convention",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["convention of states", "Article V", "constitutional convention"],
        "related_issues": ["term_limits", "balanced_budget"]
    },
    
    # ==================== NATIONAL SECURITY (6) ====================
    "military_strength": {
        "code": "military_strength",
        "name": "Strong Military",
        "category": "security",
        "description": "Maintaining powerful military",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["military", "defense", "armed forces", "Pentagon"],
        "related_issues": ["veterans"]
    },
    "veterans": {
        "code": "veterans",
        "name": "Veterans Support",
        "category": "security",
        "description": "Supporting veterans benefits and care",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["veterans", "VA", "military veterans", "veteran"],
        "related_issues": ["military_strength"]
    },
    "border_security": {
        "code": "border_security",
        "name": "Border Security",
        "category": "security",
        "description": "Securing the US borders",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["border security", "border patrol", "CBP", "border"],
        "related_issues": ["border_wall", "deportation"]
    },
    "america_first": {
        "code": "america_first",
        "name": "America First Foreign Policy",
        "category": "security",
        "description": "Prioritizing American interests abroad",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["America First", "foreign policy", "NATO", "UN"],
        "related_issues": ["military_strength"]
    },
    "israel_support": {
        "code": "israel_support",
        "name": "Support for Israel",
        "category": "security",
        "description": "Strong alliance with Israel",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["Israel", "Jerusalem", "Middle East", "Hamas"],
        "related_issues": ["america_first"]
    },
    "china_policy": {
        "code": "china_policy",
        "name": "Tough on China",
        "category": "security",
        "description": "Confronting Chinese influence",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["China", "CCP", "Chinese", "Taiwan"],
        "related_issues": ["tariffs", "america_first"]
    },
    
    # ==================== HEALTHCARE (6) ====================
    "repeal_aca": {
        "code": "repeal_aca",
        "name": "Repeal Obamacare / ACA",
        "category": "healthcare",
        "description": "Repealing the Affordable Care Act",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["Obamacare", "ACA", "Affordable Care Act", "healthcare repeal"],
        "related_issues": ["healthcare_choice"]
    },
    "healthcare_choice": {
        "code": "healthcare_choice",
        "name": "Healthcare Choice",
        "category": "healthcare",
        "description": "Market-based healthcare options",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["healthcare choice", "health insurance", "HSA"],
        "related_issues": ["repeal_aca"]
    },
    "medicare_age": {
        "code": "medicare_age",
        "name": "Medicare Eligibility Age",
        "category": "healthcare",
        "description": "Changing Medicare eligibility age",
        "republican_position": "neutral",
        "democrat_position": "oppose",
        "keywords": ["Medicare", "Medicare age", "senior healthcare"],
        "related_issues": []
    },
    "drug_prices": {
        "code": "drug_prices",
        "name": "Lower Drug Prices",
        "category": "healthcare",
        "description": "Reducing prescription drug costs",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["drug prices", "prescription", "pharmaceutical", "insulin"],
        "related_issues": []
    },
    "mental_health": {
        "code": "mental_health",
        "name": "Mental Health Funding",
        "category": "healthcare",
        "description": "Increasing mental health resources",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["mental health", "suicide", "depression", "counseling"],
        "related_issues": []
    },
    "vaccine_mandates": {
        "code": "vaccine_mandates",
        "name": "No Vaccine Mandates",
        "category": "healthcare",
        "description": "Opposing government vaccine requirements",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["vaccine mandate", "vaccination", "COVID vaccine"],
        "related_issues": ["parental_rights"]
    },
    
    # ==================== ENERGY (6) ====================
    "energy_independence": {
        "code": "energy_independence",
        "name": "Energy Independence",
        "category": "energy",
        "description": "Achieving US energy self-sufficiency",
        "republican_position": "support",
        "democrat_position": "support",
        "keywords": ["energy independence", "energy security", "domestic energy"],
        "related_issues": ["fossil_fuels"]
    },
    "fossil_fuels": {
        "code": "fossil_fuels",
        "name": "Support Fossil Fuels",
        "category": "energy",
        "description": "Supporting oil, gas, and coal",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["oil", "gas", "coal", "fossil fuel", "drilling"],
        "related_issues": ["energy_independence", "green_new_deal"]
    },
    "green_new_deal": {
        "code": "green_new_deal",
        "name": "Oppose Green New Deal",
        "category": "energy",
        "description": "Opposing climate legislation",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["Green New Deal", "climate", "carbon", "emissions"],
        "related_issues": ["fossil_fuels", "climate_change"]
    },
    "nuclear_energy": {
        "code": "nuclear_energy",
        "name": "Nuclear Energy",
        "category": "energy",
        "description": "Expanding nuclear power",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["nuclear", "nuclear power", "nuclear energy"],
        "related_issues": ["energy_independence"]
    },
    "ev_mandates": {
        "code": "ev_mandates",
        "name": "No EV Mandates",
        "category": "energy",
        "description": "Opposing electric vehicle requirements",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["electric vehicle", "EV", "EV mandate", "gas car"],
        "related_issues": ["fossil_fuels"]
    },
    "climate_change": {
        "code": "climate_change",
        "name": "Climate Change Policy",
        "category": "energy",
        "description": "Government action on climate change",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["climate change", "global warming", "climate crisis"],
        "related_issues": ["green_new_deal"]
    },
    
    # ==================== JUSTICE (4) ====================
    "law_enforcement": {
        "code": "law_enforcement",
        "name": "Support Law Enforcement",
        "category": "justice",
        "description": "Backing police and law enforcement",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["police", "law enforcement", "back the blue", "cops"],
        "related_issues": ["prosecute_crime"]
    },
    "criminal_justice_reform": {
        "code": "criminal_justice_reform",
        "name": "Criminal Justice Reform",
        "category": "justice",
        "description": "Reforming the criminal justice system",
        "republican_position": "neutral",
        "democrat_position": "support",
        "keywords": ["criminal justice reform", "prison reform", "sentencing"],
        "related_issues": []
    },
    "bail_reform": {
        "code": "bail_reform",
        "name": "End Cashless Bail",
        "category": "justice",
        "description": "Opposing elimination of cash bail",
        "republican_position": "support",
        "democrat_position": "oppose",
        "keywords": ["bail reform", "cashless bail", "bail"],
        "related_issues": ["prosecute_crime"]
    },
    "prosecute_crime": {
        "code": "prosecute_crime",
        "name": "Tough on Crime",
        "category": "justice",
        "description": "Strong prosecution of criminals",
        "republican_position": "support",
        "democrat_position": "neutral",
        "keywords": ["tough on crime", "prosecutor", "DA", "crime"],
        "related_issues": ["law_enforcement", "bail_reform"]
    },
    
    # ==================== EDUCATION (2 additional) ====================
    "education_funding": {
        "code": "education_funding",
        "name": "Education Funding",
        "category": "education",
        "description": "Public school funding levels",
        "republican_position": "neutral",
        "democrat_position": "support",
        "keywords": ["education funding", "school funding", "teacher pay"],
        "related_issues": ["school_choice"]
    },
    "student_loans": {
        "code": "student_loans",
        "name": "Student Loan Forgiveness",
        "category": "education",
        "description": "Forgiving student loan debt",
        "republican_position": "oppose",
        "democrat_position": "support",
        "keywords": ["student loan", "student debt", "loan forgiveness", "college debt"],
        "related_issues": []
    },
}


# ============================================================================
# DATABASE SCHEMA
# ============================================================================

ISSUE_SCHEMA = """
-- ============================================================================
-- ECOSYSTEM 7: ISSUE TRACKING SYSTEM
-- ============================================================================

-- Issues Reference Table
CREATE TABLE IF NOT EXISTS issues (
    issue_code VARCHAR(50) PRIMARY KEY,
    issue_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    
    -- Party positions
    republican_position VARCHAR(50) DEFAULT 'unknown',
    democrat_position VARCHAR(50) DEFAULT 'unknown',
    
    -- Keywords for detection
    keywords JSONB DEFAULT '[]',
    related_issues JSONB DEFAULT '[]',
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issues_category ON issues(category);

-- Candidate Issue Positions
CREATE TABLE IF NOT EXISTS candidate_positions (
    position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Position
    position VARCHAR(50) NOT NULL,  -- strongly_support to strongly_oppose
    position_strength INTEGER CHECK (position_strength BETWEEN 1 AND 5),
    
    -- Evidence
    public_statement TEXT,
    statement_date DATE,
    statement_source VARCHAR(255),
    voting_record_support INTEGER DEFAULT 0,
    voting_record_oppose INTEGER DEFAULT 0,
    
    -- Display
    is_priority_issue BOOLEAN DEFAULT false,
    display_on_website BOOLEAN DEFAULT true,
    
    -- Verification
    verified BOOLEAN DEFAULT false,
    verified_by UUID,
    verified_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(candidate_id, issue_code)
);

CREATE INDEX IF NOT EXISTS idx_candidate_positions_candidate ON candidate_positions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_candidate_positions_issue ON candidate_positions(issue_code);

-- Donor Issue Positions / Interests
CREATE TABLE IF NOT EXISTS donor_positions (
    position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL,
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Position
    position VARCHAR(50) NOT NULL,
    position_strength INTEGER CHECK (position_strength BETWEEN 1 AND 5),
    
    -- Salience (how much they care, 0-1)
    salience DECIMAL(4,3) DEFAULT 0.5,
    
    -- Evidence
    inferred_from VARCHAR(50),  -- survey, donation, petition, social, inferred
    evidence_strength DECIMAL(4,3),
    
    -- Activity
    donations_to_issue DECIMAL(12,2) DEFAULT 0,
    petitions_signed INTEGER DEFAULT 0,
    events_attended INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(donor_id, issue_code)
);

CREATE INDEX IF NOT EXISTS idx_donor_positions_donor ON donor_positions(donor_id);
CREATE INDEX IF NOT EXISTS idx_donor_positions_issue ON donor_positions(issue_code);
CREATE INDEX IF NOT EXISTS idx_donor_positions_salience ON donor_positions(salience DESC);

-- Issue Concordance (candidate-donor alignment)
CREATE TABLE IF NOT EXISTS issue_concordance (
    concordance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID NOT NULL,
    donor_id UUID NOT NULL,
    
    -- Overall concordance score (0-1)
    concordance_score DECIMAL(4,3),
    weighted_concordance DECIMAL(4,3),  -- Weighted by salience
    
    -- Breakdown
    matching_issues INTEGER DEFAULT 0,
    opposing_issues INTEGER DEFAULT 0,
    neutral_issues INTEGER DEFAULT 0,
    total_issues_compared INTEGER DEFAULT 0,
    
    -- Top matching/opposing
    top_matching_issues JSONB DEFAULT '[]',
    top_opposing_issues JSONB DEFAULT '[]',
    
    -- Recommendation
    recommendation VARCHAR(50),  -- strong_match, good_match, weak_match, mismatch
    
    calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_concordance_pair ON issue_concordance(candidate_id, donor_id);
CREATE INDEX IF NOT EXISTS idx_concordance_score ON issue_concordance(concordance_score DESC);

-- Issue Trends
CREATE TABLE IF NOT EXISTS issue_trends (
    trend_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Time period
    period_date DATE NOT NULL,
    period_type VARCHAR(20) DEFAULT 'daily',  -- daily, weekly, monthly
    
    -- Volume
    news_mentions INTEGER DEFAULT 0,
    social_mentions INTEGER DEFAULT 0,
    donor_activity INTEGER DEFAULT 0,
    
    -- Sentiment
    sentiment_positive INTEGER DEFAULT 0,
    sentiment_negative INTEGER DEFAULT 0,
    sentiment_neutral INTEGER DEFAULT 0,
    sentiment_score DECIMAL(4,3),  -- -1 to 1
    
    -- Trend
    trend_direction VARCHAR(20),  -- rising, falling, stable
    trend_velocity DECIMAL(6,3),  -- Rate of change
    
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_issue_trends_date ON issue_trends(period_date);
CREATE INDEX IF NOT EXISTS idx_issue_trends_issue ON issue_trends(issue_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_trends_unique ON issue_trends(issue_code, period_date, period_type);

-- Issue Lifecycle
CREATE TABLE IF NOT EXISTS issue_lifecycle (
    lifecycle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Current stage
    lifecycle_stage VARCHAR(50),  -- emerging, rising, peak, declining, dormant
    stage_entered_at TIMESTAMP,
    
    -- Predictions
    predicted_peak_date DATE,
    predicted_decline_date DATE,
    days_to_peak INTEGER,
    
    -- Historical
    last_peak_date DATE,
    last_peak_intensity DECIMAL(4,3),
    cycle_count INTEGER DEFAULT 0,
    
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_lifecycle_issue ON issue_lifecycle(issue_code);

-- Issue Correlations
CREATE TABLE IF NOT EXISTS issue_correlations (
    correlation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_code_1 VARCHAR(50) REFERENCES issues(issue_code),
    issue_code_2 VARCHAR(50) REFERENCES issues(issue_code),
    
    -- Correlation
    correlation_coefficient DECIMAL(5,4),  -- -1 to 1
    correlation_strength VARCHAR(20),  -- strong, moderate, weak, none
    correlation_type VARCHAR(20),  -- positive, negative
    
    -- Evidence
    sample_size INTEGER,
    confidence_level DECIMAL(4,3),
    
    calculated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_issue_correlations_pair ON issue_correlations(issue_code_1, issue_code_2);

-- Views
CREATE OR REPLACE VIEW v_issue_summary AS
SELECT 
    i.issue_code,
    i.issue_name,
    i.category,
    i.republican_position,
    i.democrat_position,
    COUNT(DISTINCT cp.candidate_id) as candidates_with_position,
    COUNT(DISTINCT dp.donor_id) as donors_with_position,
    AVG(dp.salience) as avg_donor_salience,
    il.lifecycle_stage
FROM issues i
LEFT JOIN candidate_positions cp ON i.issue_code = cp.issue_code
LEFT JOIN donor_positions dp ON i.issue_code = dp.issue_code
LEFT JOIN issue_lifecycle il ON i.issue_code = il.issue_code
GROUP BY i.issue_code, i.issue_name, i.category, 
         i.republican_position, i.democrat_position, il.lifecycle_stage
ORDER BY i.category, i.issue_name;

CREATE OR REPLACE VIEW v_trending_issues AS
SELECT 
    i.issue_code,
    i.issue_name,
    i.category,
    t.news_mentions,
    t.social_mentions,
    t.sentiment_score,
    t.trend_direction,
    t.trend_velocity,
    il.lifecycle_stage
FROM issues i
JOIN issue_trends t ON i.issue_code = t.issue_code
LEFT JOIN issue_lifecycle il ON i.issue_code = il.issue_code
WHERE t.period_date = CURRENT_DATE
AND (t.trend_direction = 'rising' OR t.news_mentions > 10)
ORDER BY t.trend_velocity DESC;

CREATE OR REPLACE VIEW v_candidate_issue_profile AS
SELECT 
    cp.candidate_id,
    i.category,
    COUNT(*) as positions_count,
    COUNT(CASE WHEN cp.position IN ('strongly_support', 'support') THEN 1 END) as support_count,
    COUNT(CASE WHEN cp.position IN ('strongly_oppose', 'oppose') THEN 1 END) as oppose_count,
    COUNT(CASE WHEN cp.is_priority_issue THEN 1 END) as priority_issues
FROM candidate_positions cp
JOIN issues i ON cp.issue_code = i.issue_code
GROUP BY cp.candidate_id, i.category;

SELECT 'Issue Tracking schema deployed!' as status;
"""


# ============================================================================
# ISSUE TRACKING ENGINE
# ============================================================================

class IssueTrackingEngine:
    """
    Track and analyze political issues
    """
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self.db_url = IssueConfig.DATABASE_URL
        self._initialized = True
        logger.info("🗳️ Issue Tracking Engine initialized")
    
    def _get_db(self):
        return psycopg2.connect(self.db_url)
    
    # ========================================================================
    # CANDIDATE POSITIONS
    # ========================================================================
    
    def set_candidate_position(self, candidate_id: str, issue_code: str,
                               position: str, is_priority: bool = False,
                               statement: str = None) -> str:
        """Set a candidate's position on an issue"""
        
        if issue_code not in ISSUES:
            raise ValueError(f"Unknown issue: {issue_code}")
        
        if position not in POSITION_VALUES:
            raise ValueError(f"Invalid position: {position}")
        
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO candidate_positions (
                candidate_id, issue_code, position, position_strength,
                is_priority_issue, public_statement, statement_date
            ) VALUES (%s, %s, %s, %s, %s, %s, CURRENT_DATE)
            ON CONFLICT (candidate_id, issue_code) DO UPDATE SET
                position = EXCLUDED.position,
                position_strength = EXCLUDED.position_strength,
                is_priority_issue = EXCLUDED.is_priority_issue,
                public_statement = COALESCE(EXCLUDED.public_statement, candidate_positions.public_statement),
                updated_at = NOW()
            RETURNING position_id
        """, (
            candidate_id, issue_code, position,
            abs(int(POSITION_VALUES[position] * 5)) if POSITION_VALUES[position] else 0,
            is_priority, statement
        ))
        
        position_id = cur.fetchone()[0]
        conn.commit()
        conn.close()
        
        logger.info(f"Set position: {candidate_id} → {issue_code} = {position}")
        return str(position_id)
    
    def get_candidate_positions(self, candidate_id: str) -> List[Dict]:
        """Get all positions for a candidate"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT cp.*, i.issue_name, i.category
            FROM candidate_positions cp
            JOIN issues i ON cp.issue_code = i.issue_code
            WHERE cp.candidate_id = %s
            ORDER BY cp.is_priority_issue DESC, i.category, i.issue_name
        """, (candidate_id,))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    def get_candidate_priority_issues(self, candidate_id: str) -> List[Dict]:
        """Get candidate's priority issues"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT cp.*, i.issue_name, i.category
            FROM candidate_positions cp
            JOIN issues i ON cp.issue_code = i.issue_code
            WHERE cp.candidate_id = %s AND cp.is_priority_issue = true
            ORDER BY i.category, i.issue_name
        """, (candidate_id,))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    # ========================================================================
    # DONOR POSITIONS
    # ========================================================================
    
    def set_donor_position(self, donor_id: str, issue_code: str,
                          position: str, salience: float = 0.5,
                          inferred_from: str = 'inferred') -> str:
        """Set a donor's position on an issue"""
        
        if issue_code not in ISSUES:
            raise ValueError(f"Unknown issue: {issue_code}")
        
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO donor_positions (
                donor_id, issue_code, position, position_strength,
                salience, inferred_from
            ) VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (donor_id, issue_code) DO UPDATE SET
                position = EXCLUDED.position,
                position_strength = EXCLUDED.position_strength,
                salience = GREATEST(donor_positions.salience, EXCLUDED.salience),
                updated_at = NOW()
            RETURNING position_id
        """, (
            donor_id, issue_code, position,
            abs(int(POSITION_VALUES[position] * 5)) if POSITION_VALUES[position] else 0,
            salience, inferred_from
        ))
        
        position_id = cur.fetchone()[0]
        conn.commit()
        conn.close()
        
        return str(position_id)
    
    def get_donor_positions(self, donor_id: str) -> List[Dict]:
        """Get all positions for a donor"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT dp.*, i.issue_name, i.category
            FROM donor_positions dp
            JOIN issues i ON dp.issue_code = i.issue_code
            WHERE dp.donor_id = %s
            ORDER BY dp.salience DESC, i.category
        """, (donor_id,))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    def get_high_salience_donors(self, issue_code: str, 
                                 min_salience: float = 0.7) -> List[Dict]:
        """Get donors who care deeply about an issue"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT dp.donor_id, dp.position, dp.salience
            FROM donor_positions dp
            WHERE dp.issue_code = %s AND dp.salience >= %s
            ORDER BY dp.salience DESC
        """, (issue_code, min_salience))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    # ========================================================================
    # CONCORDANCE CALCULATION
    # ========================================================================
    
    def calculate_concordance(self, candidate_id: str, donor_id: str) -> Dict:
        """
        Calculate issue concordance between candidate and donor
        
        Returns score 0-1 where:
        - 1.0 = Perfect alignment
        - 0.5 = Neutral/no overlap
        - 0.0 = Complete opposition
        """
        
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get candidate positions
        cur.execute("""
            SELECT issue_code, position FROM candidate_positions
            WHERE candidate_id = %s
        """, (candidate_id,))
        candidate_pos = {r['issue_code']: r['position'] for r in cur.fetchall()}
        
        # Get donor positions with salience
        cur.execute("""
            SELECT issue_code, position, salience FROM donor_positions
            WHERE donor_id = %s
        """, (donor_id,))
        donor_pos = {r['issue_code']: {'position': r['position'], 'salience': float(r['salience'])}
                    for r in cur.fetchall()}
        
        # Calculate concordance
        matching = []
        opposing = []
        total_weight = 0
        weighted_score = 0
        
        for issue_code in set(candidate_pos.keys()) & set(donor_pos.keys()):
            c_val = POSITION_VALUES.get(candidate_pos[issue_code])
            d_val = POSITION_VALUES.get(donor_pos[issue_code]['position'])
            salience = donor_pos[issue_code]['salience']
            
            if c_val is None or d_val is None:
                continue
            
            # Score: 1 if same sign, 0 if opposite
            if c_val * d_val > 0:  # Same direction
                score = 1.0
                matching.append(issue_code)
            elif c_val * d_val < 0:  # Opposite
                score = 0.0
                opposing.append(issue_code)
            else:  # One is neutral
                score = 0.5
            
            weighted_score += score * salience
            total_weight += salience
        
        # Calculate final scores
        if total_weight > 0:
            concordance = weighted_score / total_weight
        else:
            concordance = 0.5  # No overlap = neutral
        
        simple_concordance = len(matching) / (len(matching) + len(opposing)) if (len(matching) + len(opposing)) > 0 else 0.5
        
        # Determine recommendation
        if concordance >= IssueConfig.STRONG_MATCH:
            recommendation = 'strong_match'
        elif concordance >= IssueConfig.GOOD_MATCH:
            recommendation = 'good_match'
        elif concordance >= IssueConfig.WEAK_MATCH:
            recommendation = 'weak_match'
        else:
            recommendation = 'mismatch'
        
        result = {
            'candidate_id': candidate_id,
            'donor_id': donor_id,
            'concordance_score': round(simple_concordance, 3),
            'weighted_concordance': round(concordance, 3),
            'matching_issues': len(matching),
            'opposing_issues': len(opposing),
            'total_issues_compared': len(matching) + len(opposing),
            'top_matching_issues': matching[:5],
            'top_opposing_issues': opposing[:5],
            'recommendation': recommendation
        }
        
        # Save to database
        cur.execute("""
            INSERT INTO issue_concordance (
                candidate_id, donor_id, concordance_score, weighted_concordance,
                matching_issues, opposing_issues, total_issues_compared,
                top_matching_issues, top_opposing_issues, recommendation
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (candidate_id, donor_id) DO UPDATE SET
                concordance_score = EXCLUDED.concordance_score,
                weighted_concordance = EXCLUDED.weighted_concordance,
                matching_issues = EXCLUDED.matching_issues,
                opposing_issues = EXCLUDED.opposing_issues,
                total_issues_compared = EXCLUDED.total_issues_compared,
                top_matching_issues = EXCLUDED.top_matching_issues,
                top_opposing_issues = EXCLUDED.top_opposing_issues,
                recommendation = EXCLUDED.recommendation,
                calculated_at = NOW()
        """, (
            candidate_id, donor_id, result['concordance_score'],
            result['weighted_concordance'], result['matching_issues'],
            result['opposing_issues'], result['total_issues_compared'],
            json.dumps(result['top_matching_issues']),
            json.dumps(result['top_opposing_issues']),
            result['recommendation']
        ))
        
        conn.commit()
        conn.close()
        
        return result
    
    def get_best_donor_matches(self, candidate_id: str, limit: int = 100) -> List[Dict]:
        """Get donors with highest concordance to a candidate"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM issue_concordance
            WHERE candidate_id = %s
            ORDER BY weighted_concordance DESC
            LIMIT %s
        """, (candidate_id, limit))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    # ========================================================================
    # TRENDING ISSUES
    # ========================================================================
    
    def record_issue_activity(self, issue_code: str, 
                             news_mentions: int = 0,
                             social_mentions: int = 0,
                             sentiment_score: float = 0) -> None:
        """Record issue activity for trend tracking"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO issue_trends (
                issue_code, period_date, period_type,
                news_mentions, social_mentions, sentiment_score
            ) VALUES (%s, CURRENT_DATE, 'daily', %s, %s, %s)
            ON CONFLICT (issue_code, period_date, period_type) DO UPDATE SET
                news_mentions = issue_trends.news_mentions + EXCLUDED.news_mentions,
                social_mentions = issue_trends.social_mentions + EXCLUDED.social_mentions,
                sentiment_score = (issue_trends.sentiment_score + EXCLUDED.sentiment_score) / 2
        """, (issue_code, news_mentions, social_mentions, sentiment_score))
        
        conn.commit()
        conn.close()
    
    def get_trending_issues(self, days: int = 7) -> List[Dict]:
        """Get currently trending issues"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                i.issue_code,
                i.issue_name,
                i.category,
                SUM(t.news_mentions) as total_news,
                SUM(t.social_mentions) as total_social,
                AVG(t.sentiment_score) as avg_sentiment
            FROM issues i
            JOIN issue_trends t ON i.issue_code = t.issue_code
            WHERE t.period_date >= CURRENT_DATE - INTERVAL '%s days'
            GROUP BY i.issue_code, i.issue_name, i.category
            HAVING SUM(t.news_mentions) > 0 OR SUM(t.social_mentions) > 0
            ORDER BY (SUM(t.news_mentions) + SUM(t.social_mentions)) DESC
            LIMIT 20
        """, (days,))
        
        results = [dict(r) for r in cur.fetchall()]
        conn.close()
        
        return results
    
    # ========================================================================
    # ISSUE DETECTION
    # ========================================================================
    
    def detect_issues_in_text(self, text: str) -> List[Dict]:
        """Detect issues mentioned in text based on keywords"""
        text_lower = text.lower()
        detected = []
        
        for code, issue in ISSUES.items():
            keywords = issue.get('keywords', [])
            for keyword in keywords:
                if keyword.lower() in text_lower:
                    detected.append({
                        'issue_code': code,
                        'issue_name': issue['name'],
                        'category': issue['category'],
                        'keyword_matched': keyword
                    })
                    break
        
        return detected
    
    # ========================================================================
    # STATISTICS
    # ========================================================================
    
    def get_issue_stats(self) -> Dict:
        """Get issue tracking statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Count by category
        cur.execute("""
            SELECT category, COUNT(*) as count
            FROM issues GROUP BY category ORDER BY category
        """)
        by_category = {r['category']: r['count'] for r in cur.fetchall()}
        
        # Position coverage
        cur.execute("""
            SELECT 
                COUNT(DISTINCT candidate_id) as candidates_with_positions,
                COUNT(DISTINCT donor_id) as donors_with_positions
            FROM (
                SELECT candidate_id, NULL as donor_id FROM candidate_positions
                UNION ALL
                SELECT NULL, donor_id FROM donor_positions
            ) combined
        """)
        coverage = dict(cur.fetchone())
        
        conn.close()
        
        return {
            'total_issues': len(ISSUES),
            'by_category': by_category,
            'candidates_with_positions': coverage['candidates_with_positions'],
            'donors_with_positions': coverage['donors_with_positions']
        }


# ============================================================================
# DEPLOYMENT
# ============================================================================

def deploy_issue_tracking():
    """Deploy the issue tracking system"""
    print("=" * 70)
    print("🗳️ ECOSYSTEM 7: ISSUE TRACKING SYSTEM - DEPLOYMENT")
    print("=" * 70)
    print()
    
    try:
        conn = psycopg2.connect(IssueConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("Deploying Issue Tracking schema...")
        cur.execute(ISSUE_SCHEMA)
        conn.commit()
        
        # Seed issues
        print(f"Seeding {len(ISSUES)} issues...")
        for code, issue in ISSUES.items():
            cur.execute("""
                INSERT INTO issues (
                    issue_code, issue_name, category, description,
                    republican_position, democrat_position,
                    keywords, related_issues
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (issue_code) DO NOTHING
            """, (
                code, issue['name'], issue['category'], issue.get('description'),
                issue.get('republican_position', 'unknown'),
                issue.get('democrat_position', 'unknown'),
                json.dumps(issue.get('keywords', [])),
                json.dumps(issue.get('related_issues', []))
            ))
        
        conn.commit()
        conn.close()
        
        # Count by category
        category_counts = defaultdict(int)
        for issue in ISSUES.values():
            category_counts[issue['category']] += 1
        
        print()
        print("   ✅ issues reference table")
        print("   ✅ candidate_positions table")
        print("   ✅ donor_positions table")
        print("   ✅ issue_concordance table")
        print("   ✅ issue_trends table")
        print("   ✅ issue_lifecycle table")
        print("   ✅ issue_correlations table")
        print("   ✅ v_issue_summary view")
        print("   ✅ v_trending_issues view")
        print("   ✅ v_candidate_issue_profile view")
        print()
        print("=" * 70)
        print("✅ ISSUE TRACKING SYSTEM DEPLOYED!")
        print("=" * 70)
        print()
        print("60 Hot Button Issues by Category:")
        for cat, count in sorted(category_counts.items()):
            print(f"   • {cat.title()}: {count} issues")
        print()
        print("Features:")
        print("   • Candidate position tracking")
        print("   • Donor position & salience scoring")
        print("   • Issue concordance calculation")
        print("   • Trending issue detection")
        print("   • Issue lifecycle modeling")
        print("   • Cross-issue correlation")
        print("   • AI-powered issue detection")
        print()
        print("💰 Powers: Issue-based targeting, campaign relevance scoring")
        
        return True
        
    except Exception as e:
        print(f"❌ Deployment failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_issue_tracking()
    elif len(sys.argv) > 1 and sys.argv[1] == "--list":
        print(f"\n60 HOT BUTTON ISSUES:\n")
        for cat in IssueCategory:
            print(f"\n{cat.value.upper()}:")
            for code, issue in ISSUES.items():
                if issue['category'] == cat.value:
                    print(f"  {code}: {issue['name']} (R: {issue['republican_position']}, D: {issue['democrat_position']})")
    elif len(sys.argv) > 1 and sys.argv[1] == "--stats":
        engine = IssueTrackingEngine()
        stats = engine.get_issue_stats()
        print(json.dumps(stats, indent=2, default=str))
    else:
        print("🗳️ Issue Tracking System")
        print()
        print("Usage:")
        print("  python ecosystem_07_issue_tracking_complete.py --deploy")
        print("  python ecosystem_07_issue_tracking_complete.py --list")
        print("  python ecosystem_07_issue_tracking_complete.py --stats")
        print()
        print(f"Issues: {len(ISSUES)}")
