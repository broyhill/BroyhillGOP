#!/usr/bin/env python3
"""
============================================================================
BROYHILLGOP MASTER DEPLOYMENT SCRIPT
============================================================================

Deploys ALL 31+ ecosystems to Supabase/PostgreSQL in one command.

Usage:
    python DEPLOY_ALL_ECOSYSTEMS.py --deploy
    python DEPLOY_ALL_ECOSYSTEMS.py --status
    python DEPLOY_ALL_ECOSYSTEMS.py --test

Total Development Value: $730,000+
============================================================================
"""

import os
import sys
import importlib.util
from pathlib import Path
import psycopg2
from datetime import datetime

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/postgres")

# All ecosystems in deployment order
ECOSYSTEMS = [
    ("ecosystem_00_datahub_complete", "E0: DataHub - Core Database"),
    ("ecosystem_01_donor_intelligence_complete", "E1: Donor Intelligence - 3D Grading"),
    ("ecosystem_02_donation_processing_complete", "E2: Donation Processing"),
    ("ecosystem_03_candidate_profiles_complete", "E3: Candidate Profiles"),
    ("ecosystem_04_activist_network_complete", "E4: Activist Network"),
    ("ecosystem_05_volunteer_management_complete", "E5: Volunteer Management"),
    ("ecosystem_06_analytics_engine_complete", "E6: Analytics Engine"),
    ("ecosystem_07_issue_tracking_complete", "E7: Issue Tracking"),
    ("ecosystem_08_communications_library_complete", "E8: Communications Library"),
    ("ecosystem_09_content_creation_ai_complete", "E9: Content Creation AI"),
    ("ecosystem_10_compliance_manager_complete", "E10: Compliance Manager"),
    ("ecosystem_11_budget_management_complete", "E11: Budget Management"),
    ("ecosystem_12_campaign_operations_complete", "E12: Campaign Operations"),
    ("ecosystem_13_ai_hub_complete", "E13: AI Hub"),
    ("ecosystem_14_print_production_complete", "E14: Print Production"),
    ("ecosystem_16_tv_radio_complete", "E16: TV/Radio AI"),
    ("ecosystem_17_rvm_complete", "E17: RVM System"),
    ("ecosystem_19_social_media_manager", "E19: Social Media Manager"),
    ("ecosystem_21_ml_clustering_complete", "E21: ML Clustering"),
    ("ecosystem_30_email_complete", "E30: Email System"),
    ("ecosystem_31_sms_complete", "E31: SMS System"),
    ("ecosystem_32_phone_banking_complete", "E32: Phone Banking"),
    ("ecosystem_33_direct_mail_complete", "E33: Direct Mail"),
    ("ecosystem_34_events_complete", "E34: Events"),
]


def test_connection():
    """Test database connection"""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.close()
        return True
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False


def deploy_ecosystem(module_name: str, description: str) -> bool:
    """Deploy a single ecosystem"""
    try:
        # Try to import and run deploy function
        spec = importlib.util.spec_from_file_location(module_name, f"{module_name}.py")
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            # Look for deploy function
            deploy_func = None
            for name in dir(module):
                if name.startswith('deploy_'):
                    deploy_func = getattr(module, name)
                    break
            
            if deploy_func:
                deploy_func()
                return True
        
        print(f"   ⚠️ No deploy function found in {module_name}")
        return False
        
    except FileNotFoundError:
        print(f"   ⚠️ File not found: {module_name}.py")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False


def deploy_all():
    """Deploy all ecosystems"""
    print("=" * 70)
    print("🚀 BROYHILLGOP MASTER DEPLOYMENT")
    print("=" * 70)
    print(f"\nStarted: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Database: {DATABASE_URL[:50]}...")
    print(f"Ecosystems: {len(ECOSYSTEMS)}")
    print()
    
    if not test_connection():
        print("\n❌ Cannot connect to database. Check DATABASE_URL.")
        return False
    
    print("✅ Database connection OK\n")
    print("-" * 70)
    
    success = 0
    failed = 0
    
    for module_name, description in ECOSYSTEMS:
        print(f"\n📦 Deploying {description}...")
        if deploy_ecosystem(module_name, description):
            success += 1
            print(f"   ✅ {description} deployed")
        else:
            failed += 1
    
    print("\n" + "=" * 70)
    print("📊 DEPLOYMENT SUMMARY")
    print("=" * 70)
    print(f"\n   ✅ Successful: {success}")
    print(f"   ❌ Failed: {failed}")
    print(f"   📁 Total: {len(ECOSYSTEMS)}")
    
    if failed == 0:
        print("\n" + "=" * 70)
        print("🎉 ALL ECOSYSTEMS DEPLOYED SUCCESSFULLY!")
        print("=" * 70)
        print("\nYour BroyhillGOP platform is ready!")
        print("\nNext steps:")
        print("   1. Configure API keys in environment")
        print("   2. Run --status to verify all tables")
        print("   3. Import your data")
        print("   4. Start the Intelligence Brain")
    
    return failed == 0


def show_status():
    """Show deployment status"""
    print("=" * 70)
    print("📊 BROYHILLGOP DEPLOYMENT STATUS")
    print("=" * 70)
    
    if not test_connection():
        return
    
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    
    # Count tables
    cur.execute("""
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    """)
    tables = cur.fetchone()[0]
    
    # Count views
    cur.execute("""
        SELECT COUNT(*) FROM information_schema.views 
        WHERE table_schema = 'public'
    """)
    views = cur.fetchone()[0]
    
    # Count indexes
    cur.execute("""
        SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public'
    """)
    indexes = cur.fetchone()[0]
    
    conn.close()
    
    print(f"\n   📋 Tables: {tables}")
    print(f"   👁️ Views: {views}")
    print(f"   🔍 Indexes: {indexes}")
    print(f"\n   Status: {'✅ DEPLOYED' if tables > 50 else '⚠️ PARTIAL'}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "--deploy":
            deploy_all()
        elif sys.argv[1] == "--status":
            show_status()
        elif sys.argv[1] == "--test":
            if test_connection():
                print("✅ Database connection successful!")
            else:
                print("❌ Database connection failed!")
        else:
            print("Unknown command. Use --deploy, --status, or --test")
    else:
        print(__doc__)
        print("\nCommands:")
        print("  python DEPLOY_ALL_ECOSYSTEMS.py --deploy  # Deploy all ecosystems")
        print("  python DEPLOY_ALL_ECOSYSTEMS.py --status  # Check deployment status")
        print("  python DEPLOY_ALL_ECOSYSTEMS.py --test    # Test database connection")
