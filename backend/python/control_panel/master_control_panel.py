#!/usr/bin/env python3
"""
================================================================================
MASTER CONTROL PANEL - HIERARCHICAL ECOSYSTEM MANAGEMENT
================================================================================
Comprehensive control panel for ALL 56 ecosystems with:
- 3-5 level deep directory structure per ecosystem
- OFF/ON/TIMER/AI toggles at every feature level
- Manual vs AI control modes
- All panels combined in E00 Intelligence Hub

STRUCTURE EXAMPLE:
E00_Hub/
├── E01_Donor_Intelligence/
│   ├── Data_Ingestion/
│   │   ├── FEC_Import/
│   │   │   ├── auto_sync [OFF|ON|TIMER|AI]
│   │   │   └── schedule [datetime]
│   │   ├── NC_SBoE_Import/
│   │   └── Manual_Upload/
│   ├── Grading_Engine/
│   │   ├── ThreeDGrading/
│   │   │   ├── amount_scoring [OFF|ON|AI]
│   │   │   ├── intensity_scoring [OFF|ON|AI]
│   │   │   └── level_preference [OFF|ON|AI]
│   │   ├── RFM_Analysis/
│   │   └── Auto_Regrade/
│   ├── Predictions/
│   │   ├── Churn_Risk/
│   │   ├── Optimal_Ask/
│   │   └── Best_Channel/
│   └── Grade_Enforcement/
│       ├── Permission_Check/
│       └── Filter_Recipients/

Development Value: \$85,000
================================================================================
"""

import json
import logging
import uuid
import asyncio
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Union
from dataclasses import dataclass, field
from enum import Enum
from collections import defaultdict
import copy

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('master_control_panel')

# ============================================================================
# ENUMS
# ============================================================================

class ToggleState(Enum):
    OFF = 'off'
    ON = 'on'
    TIMER = 'timer'
    AI = 'ai'

class ControlMode(Enum):
    MANUAL = 'manual'
    AI = 'ai'
    HYBRID = 'hybrid'

class ApprovalRequired(Enum):
    NONE = 'none'
    SINGLE = 'single'
    DUAL = 'dual'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class FeatureToggle:
    """Individual feature toggle with state and schedule."""
    feature_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    path: str = ''  # Full path like E01/Data_Ingestion/FEC_Import/auto_sync
    state: ToggleState = ToggleState.OFF
    control_mode: ControlMode = ControlMode.MANUAL
    
    # Timer settings
    timer_start: Optional[datetime] = None
    timer_end: Optional[datetime] = None
    timer_recurring: bool = False
    timer_cron: Optional[str] = None  # Cron expression for recurring
    
    # AI settings
    ai_controlled: bool = False
    ai_can_override: bool = False
    ai_confidence_threshold: float = 0.8
    
    # Approval settings
    approval_required: ApprovalRequired = ApprovalRequired.NONE
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None
    
    # Audit
    last_changed_by: str = ''
    last_changed_at: datetime = field(default_factory=datetime.now)
    change_reason: str = ''

@dataclass
class ControlDirectory:
    """Directory node in the control hierarchy."""
    dir_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    path: str = ''
    parent_path: str = ''
    level: int = 0
    
    # Aggregate state (computed from children)
    aggregate_state: ToggleState = ToggleState.OFF
    
    # Children
    subdirectories: Dict[str, 'ControlDirectory'] = field(default_factory=dict)
    features: Dict[str, FeatureToggle] = field(default_factory=dict)
    
    # Override settings
    force_state: Optional[ToggleState] = None  # Force all children to this state
    
    # Metadata
    description: str = ''
    ecosystem: str = ''

# ============================================================================
# ECOSYSTEM CONTROL STRUCTURES
# ============================================================================

# Complete hierarchy for all 56 ecosystems
ECOSYSTEM_CONTROL_STRUCTURE = {
    'E00': {
        'name': 'Intelligence Hub',
        'directories': {
            'Event_Bus': {
                'Redis_PubSub': ['publish_events', 'subscribe_channels', 'message_routing'],
                'Event_Processing': ['event_queue', 'batch_processing', 'priority_handling'],
                'Cross_Ecosystem': ['broadcast', 'targeted_dispatch', 'response_aggregation']
            },
            'Health_Monitoring': {
                'System_Health': ['database_check', 'redis_check', 'api_check'],
                'Ecosystem_Health': ['heartbeat_monitor', 'failure_detection', 'auto_recovery'],
                'Alerts': ['email_alerts', 'sms_alerts', 'dashboard_alerts']
            },
            'Data_Routing': {
                'Query_Router': ['donor_queries', 'volunteer_queries', 'candidate_queries'],
                'Cache_Management': ['cache_invalidation', 'cache_warming', 'ttl_management']
            },
            'Master_Controls': {
                'Global_Toggles': ['emergency_shutoff', 'maintenance_mode', 'read_only_mode'],
                'AI_Delegation': ['ai_control_level', 'human_approval_required', 'confidence_thresholds']
            }
        }
    },
    'E01': {
        'name': 'Donor Intelligence',
        'directories': {
            'Data_Ingestion': {
                'FEC_Import': ['auto_sync', 'schedule', 'field_mapping', 'deduplication'],
                'NC_SBoE_Import': ['voter_file_sync', 'contribution_sync', 'schedule'],
                'Manual_Upload': ['csv_import', 'validation', 'merge_rules'],
                'API_Integrations': ['actblue_sync', 'winred_sync', 'anedot_sync']
            },
            'Grading_Engine': {
                'ThreeDGrading': ['amount_scoring', 'intensity_scoring', 'level_preference', 'composite_grade'],
                'RFM_Analysis': ['recency_calc', 'frequency_calc', 'monetary_calc', 'segment_assignment'],
                'Auto_Regrade': ['trigger_regrade', 'batch_regrade', 'schedule'],
                'Grade_Rules': ['upgrade_rules', 'downgrade_rules', 'protection_rules']
            },
            'Predictions': {
                'Churn_Risk': ['model_scoring', 'threshold_alerts', 'intervention_triggers'],
                'Optimal_Ask': ['ask_calculation', 'ceiling_detection', 'timing_optimization'],
                'Best_Channel': ['channel_preference', 'response_history', 'fatigue_check'],
                'Lifecycle_Stage': ['stage_detection', 'transition_triggers', 'nurture_assignment']
            },
            'Grade_Enforcement': {
                'Permission_Check': ['action_validation', 'grade_restrictions', 'override_approval'],
                'Filter_Recipients': ['grade_filtering', 'exclusion_rules', 'priority_queuing']
            },
            'Reporting': {
                'Donor_Reports': ['grade_distribution', 'trend_analysis', 'cohort_analysis'],
                'Export': ['csv_export', 'api_export', 'scheduled_reports']
            }
        }
    },
    'E02': {
        'name': 'Donation Processing',
        'directories': {
            'Payment_Processing': {
                'Stripe': ['payment_capture', 'refund_processing', 'subscription_management'],
                'PayPal': ['checkout_integration', 'ipn_handling', 'dispute_management'],
                'ActBlue': ['webhook_processing', 'reconciliation', 'fee_tracking']
            },
            'Compliance': {
                'FEC_Validation': ['contribution_limits', 'occupation_employer', 'foreign_national_check'],
                'Reporting': ['itemized_contributions', 'aggregation_tracking', 'filing_prep']
            },
            'Receipt_Generation': {
                'Auto_Receipt': ['email_receipt', 'pdf_generation', 'template_selection'],
                'Tax_Letters': ['annual_summary', 'on_demand', 'batch_generation']
            },
            'Recurring_Donations': {
                'Subscription_Management': ['create_subscription', 'modify_subscription', 'cancel_subscription'],
                'Failed_Payment': ['retry_logic', 'notification', 'recovery_campaign']
            }
        }
    },
    'E03': {
        'name': 'Candidate Profiles',
        'directories': {
            'Profile_Management': {
                'Basic_Info': ['bio_update', 'photo_management', 'social_links'],
                'Issue_Positions': ['position_tracking', 'talking_points', 'vote_history'],
                'Campaign_Info': ['district_assignment', 'election_cycle', 'party_affiliation']
            },
            'Communication_DNA': {
                'Voice_Profile': ['tone_settings', 'vocabulary', 'style_preferences'],
                'Brand_Assets': ['logos', 'colors', 'fonts', 'templates']
            },
            'Targeting': {
                'Voter_Segments': ['demographic_targeting', 'geographic_targeting', 'issue_targeting'],
                'Priority_Issues': ['issue_ranking', 'talking_point_assignment']
            }
        }
    },
    'E04': {
        'name': 'Activist Network',
        'directories': {
            'Activist_Management': {
                'Registration': ['signup_forms', 'verification', 'onboarding'],
                'Grading': ['engagement_scoring', 'reliability_rating', 'skill_assessment'],
                'Communication': ['mass_messaging', 'targeted_outreach', 'event_invites']
            },
            'Action_Tracking': {
                'Activities': ['canvass_logging', 'phone_calls', 'event_attendance'],
                'Goals': ['weekly_goals', 'campaign_goals', 'leaderboards'],
                'Rewards': ['point_system', 'badges', 'recognition']
            },
            'Team_Structure': {
                'Hierarchy': ['team_leads', 'captains', 'regional_directors'],
                'Assignment': ['territory_assignment', 'shift_scheduling']
            }
        }
    },
    'E05': {
        'name': 'Volunteer Management',
        'directories': {
            'Recruitment': {
                'Signup': ['web_forms', 'event_signup', 'referral_tracking'],
                'Screening': ['background_check', 'skill_survey', 'availability'],
                'Onboarding': ['welcome_sequence', 'training_assignment', 'mentor_pairing']
            },
            'Scheduling': {
                'Shift_Management': ['shift_creation', 'assignment', 'reminders'],
                'Availability': ['availability_tracking', 'conflict_detection', 'swap_requests'],
                'Check_In': ['arrival_logging', 'hour_tracking', 'no_show_handling']
            },
            'Grading': {
                'Performance': ['task_completion', 'reliability_score', 'quality_rating'],
                'Advancement': ['level_progression', 'role_upgrade', 'leadership_track']
            },
            'Communication': {
                'Notifications': ['shift_reminders', 'schedule_changes', 'appreciation'],
                'Mass_Outreach': ['volunteer_blasts', 'opportunity_alerts']
            }
        }
    },
    'E06': {
        'name': 'Analytics Engine',
        'directories': {
            'Data_Collection': {
                'Event_Tracking': ['page_views', 'form_submissions', 'donations', 'email_engagement'],
                'Attribution': ['source_tracking', 'utm_parsing', 'conversion_attribution']
            },
            'Reporting': {
                'Standard_Reports': ['daily_summary', 'weekly_dashboard', 'monthly_review'],
                'Custom_Reports': ['report_builder', 'scheduled_delivery', 'export_formats'],
                'Real_Time': ['live_dashboard', 'alert_triggers', 'anomaly_detection']
            },
            'Predictions': {
                'Forecasting': ['donation_forecast', 'volunteer_forecast', 'turnout_prediction'],
                'Modeling': ['response_models', 'propensity_scores', 'lifetime_value']
            }
        }
    },
    'E07': {
        'name': 'Issue Tracking',
        'directories': {
            'Issue_Management': {
                'Creation': ['issue_entry', 'categorization', 'priority_assignment'],
                'Lifecycle': ['status_tracking', 'escalation', 'resolution'],
                'Assignment': ['auto_assignment', 'workload_balancing', 'expertise_matching']
            },
            'Monitoring': {
                'News_Tracking': ['keyword_monitoring', 'sentiment_analysis', 'alert_triggers'],
                'Social_Listening': ['mention_tracking', 'trend_detection', 'influencer_alerts']
            },
            'Response': {
                'Rapid_Response': ['template_deployment', 'approval_workflow', 'multi_channel'],
                'Talking_Points': ['generation', 'distribution', 'version_control']
            }
        }
    },
    'E08': {
        'name': 'Communications Library',
        'directories': {
            'Template_Management': {
                'Email_Templates': ['creation', 'versioning', 'approval', 'retirement'],
                'SMS_Templates': ['character_optimization', 'link_shortening', 'compliance'],
                'Script_Templates': ['phone_scripts', 'door_scripts', 'rvm_scripts'],
                'Print_Templates': ['mail_pieces', 'flyers', 'door_hangers']
            },
            'Asset_Management': {
                'Images': ['upload', 'tagging', 'optimization', 'usage_tracking'],
                'Videos': ['upload', 'transcoding', 'thumbnail_generation'],
                'Documents': ['storage', 'versioning', 'access_control']
            },
            'Organization': {
                'Categories': ['category_management', 'tagging', 'search_optimization'],
                'Access_Control': ['role_permissions', 'candidate_restrictions']
            }
        }
    },
    'E09': {
        'name': 'Content Creation AI',
        'directories': {
            'Generation': {
                'Email_Content': ['subject_lines', 'body_copy', 'cta_optimization'],
                'Social_Content': ['post_generation', 'hashtag_suggestions', 'image_captions'],
                'Script_Content': ['call_scripts', 'rvm_scripts', 'video_scripts'],
                'Ad_Content': ['headlines', 'descriptions', 'variations']
            },
            'Personalization': {
                'Dynamic_Content': ['merge_fields', 'conditional_blocks', 'audience_variants'],
                'Tone_Matching': ['candidate_voice', 'audience_adaptation', 'formality_level']
            },
            'Optimization': {
                'AB_Generation': ['variant_creation', 'statistical_significance', 'winner_selection'],
                'Performance_Learning': ['feedback_loop', 'model_improvement']
            }
        }
    },
    'E10': {
        'name': 'Compliance Manager',
        'directories': {
            'FEC_Compliance': {
                'Contribution_Limits': ['limit_checking', 'aggregate_tracking', 'alerts'],
                'Donor_Validation': ['occupation_employer', 'foreign_national', 'age_verification'],
                'Filing': ['report_generation', 'amendment_tracking', 'deadline_alerts']
            },
            'Communication_Compliance': {
                'Opt_Out': ['unsubscribe_processing', 'suppression_lists', 'sync'],
                'TCPA': ['consent_tracking', 'calling_hours', 'dnc_check'],
                'CAN_SPAM': ['header_compliance', 'footer_requirements', 'unsubscribe_links']
            },
            'Audit': {
                'Activity_Logging': ['user_actions', 'system_events', 'data_changes'],
                'Reports': ['compliance_reports', 'audit_trail', 'exception_reports']
            }
        }
    },
    'E11': {
        'name': 'Budget Management',
        'directories': {
            'Budget_Planning': {
                'Allocation': ['channel_budgets', 'campaign_budgets', 'reserve_funds'],
                'Forecasting': ['spend_projection', 'revenue_forecast', 'cash_flow']
            },
            'Spend_Tracking': {
                'Real_Time': ['transaction_logging', 'running_totals', 'threshold_alerts'],
                'Reconciliation': ['vendor_matching', 'invoice_processing', 'discrepancy_resolution']
            },
            'Reporting': {
                'Financial_Reports': ['burn_rate', 'roi_analysis', 'variance_reports'],
                'Compliance_Reports': ['fec_disbursements', 'vendor_payments']
            },
            'Controls': {
                'Approval_Workflow': ['spend_approval', 'limit_overrides', 'emergency_funds'],
                'Alerts': ['budget_warnings', 'overspend_alerts', 'reallocation_suggestions']
            }
        }
    },
    'E12': {
        'name': 'Campaign Operations',
        'directories': {
            'Campaign_Management': {
                'Creation': ['campaign_setup', 'goal_setting', 'timeline'],
                'Execution': ['launch', 'monitoring', 'optimization'],
                'Completion': ['wrap_up', 'reporting', 'archival']
            },
            'Multi_Channel': {
                'Coordination': ['channel_sync', 'message_consistency', 'timing_optimization'],
                'Attribution': ['cross_channel_tracking', 'conversion_attribution']
            },
            'Automation': {
                'Triggers': ['event_triggers', 'time_triggers', 'behavior_triggers'],
                'Workflows': ['drip_campaigns', 'nurture_sequences', 'reactivation']
            }
        }
    },
    'E13': {
        'name': 'AI Hub',
        'directories': {
            'Model_Management': {
                'OpenAI': ['api_routing', 'prompt_management', 'cost_tracking'],
                'Anthropic': ['api_routing', 'prompt_management', 'cost_tracking'],
                'Local_Models': ['model_loading', 'inference', 'fine_tuning']
            },
            'Prompt_Engineering': {
                'Templates': ['template_library', 'versioning', 'ab_testing'],
                'Optimization': ['token_optimization', 'response_quality', 'cost_efficiency']
            },
            'Usage_Control': {
                'Rate_Limiting': ['per_candidate', 'per_feature', 'global_limits'],
                'Cost_Management': ['budget_allocation', 'spend_alerts', 'usage_reports']
            }
        }
    },
    'E14': {
        'name': 'Print Production',
        'directories': {
            'Design': {
                'Template_Creation': ['layout_design', 'variable_fields', 'brand_compliance'],
                'Asset_Management': ['image_library', 'font_management', 'color_profiles']
            },
            'Production': {
                'Print_Queue': ['job_submission', 'priority_management', 'status_tracking'],
                'Vendor_Integration': ['api_submission', 'proof_approval', 'delivery_tracking']
            },
            'Inventory': {
                'Stock_Management': ['inventory_levels', 'reorder_triggers', 'usage_tracking'],
                'Distribution': ['shipping', 'delivery_confirmation', 'returns']
            }
        }
    },
    'E15': {
        'name': 'Contact Directory',
        'directories': {
            'Contact_Management': {
                'Import': ['bulk_import', 'deduplication', 'validation'],
                'Update': ['field_updates', 'merge_records', 'data_enrichment'],
                'Export': ['filtered_export', 'format_options', 'scheduling']
            },
            'Organization': {
                'Lists': ['list_creation', 'dynamic_lists', 'list_sync'],
                'Segments': ['segment_builder', 'behavioral_segments', 'predictive_segments'],
                'Tags': ['tag_management', 'auto_tagging', 'tag_cleanup']
            },
            'Data_Quality': {
                'Validation': ['email_validation', 'phone_validation', 'address_validation'],
                'Enrichment': ['demographic_append', 'social_append', 'wealth_screening']
            }
        }
    },
    'E16': {
        'name': 'TV Radio Advertising',
        'directories': {
            'Media_Planning': {
                'Market_Selection': ['market_research', 'audience_targeting', 'budget_allocation'],
                'Schedule_Creation': ['daypart_selection', 'frequency_planning', 'reach_optimization']
            },
            'Creative': {
                'Production': ['script_development', 'recording', 'editing'],
                'Compliance': ['disclaimer_check', 'content_review', 'fcc_compliance']
            },
            'Placement': {
                'Buying': ['rate_negotiation', 'order_submission', 'confirmation'],
                'Trafficking': ['material_delivery', 'rotation_management', 'makegoods']
            },
            'Reporting': {
                'Performance': ['reach_tracking', 'frequency_analysis', 'attribution'],
                'Billing': ['invoice_reconciliation', 'budget_tracking']
            }
        }
    },
    'E17': {
        'name': 'RVM (Ringless Voicemail)',
        'directories': {
            'Voice_Management': {
                'Voice_Profiles': ['clone_creation', 'profile_selection', 'quality_check'],
                'Audio_Production': ['script_to_audio', 'ai_generation', 'manual_upload'],
                'Approval': ['review_queue', 'compliance_check', 'final_approval']
            },
            'Campaign_Management': {
                'Setup': ['campaign_creation', 'audience_selection', 'schedule'],
                'AB_Testing': ['variant_creation', 'split_assignment', 'winner_selection'],
                'Execution': ['drop_queue', 'rate_limiting', 'carrier_optimization']
            },
            'Delivery': {
                'Drop_Cowboy': ['api_integration', 'batch_submission', 'status_tracking'],
                'Carrier_Management': ['carrier_detection', 'routing_optimization', 'block_handling']
            },
            'Compliance': {
                'Opt_Out': ['stop_processing', 'list_management', 'sync'],
                'Timing': ['calling_hours', 'timezone_handling', 'holiday_blocking']
            },
            'Reporting': {
                'Delivery_Stats': ['success_rate', 'carrier_breakdown', 'cost_analysis'],
                'Engagement': ['callback_tracking', 'text_replies', 'conversion_tracking']
            }
        }
    },
    'E18': {
        'name': 'Print Advertising & VDP',
        'directories': {
            'Variable_Data': {
                'Template_Design': ['field_mapping', 'conditional_logic', 'personalization'],
                'Data_Merge': ['data_preparation', 'merge_execution', 'proof_generation']
            },
            'Print_Advertising': {
                'Newspaper': ['ad_creation', 'placement', 'insertion_orders'],
                'Magazine': ['ad_creation', 'placement', 'insertion_orders'],
                'Outdoor': ['billboard_design', 'location_selection', 'posting_schedule']
            },
            'Production': {
                'Proofing': ['digital_proofs', 'approval_workflow', 'revision_tracking'],
                'Printing': ['vendor_submission', 'quality_control', 'delivery']
            }
        }
    },
    'E19': {
        'name': 'Social Media Manager',
        'directories': {
            'Account_Management': {
                'Connections': ['facebook_connect', 'twitter_connect', 'instagram_connect'],
                'Permissions': ['posting_access', 'analytics_access', 'ad_access']
            },
            'Content_Publishing': {
                'Scheduling': ['post_scheduler', 'optimal_timing', 'queue_management'],
                'Multi_Platform': ['cross_posting', 'platform_optimization', 'hashtag_management'],
                'Approval': ['review_queue', 'compliance_check', 'final_approval']
            },
            'Engagement': {
                'Monitoring': ['mention_tracking', 'comment_alerts', 'dm_notifications'],
                'Response': ['reply_management', 'sentiment_routing', 'escalation']
            },
            'Advertising': {
                'Campaign_Creation': ['audience_targeting', 'creative_upload', 'budget_setting'],
                'Optimization': ['bid_management', 'audience_refinement', 'creative_rotation'],
                'Reporting': ['performance_metrics', 'attribution', 'roi_analysis']
            }
        }
    },
    'E20': {
        'name': 'Intelligence Brain',
        'directories': {
            'Decision_Engine': {
                'Event_Processing': ['trigger_matching', 'score_calculation', 'action_selection'],
                'Channel_Selection': ['channel_scoring', 'budget_check', 'fatigue_check'],
                'Target_Selection': ['audience_filtering', 'priority_ranking', 'volume_control']
            },
            'Budget_Control': {
                'Allocation': ['channel_budgets', 'daily_limits', 'reserve_management'],
                'Tracking': ['spend_monitoring', 'pace_analysis', 'reallocation']
            },
            'Learning': {
                'Outcome_Tracking': ['response_recording', 'conversion_tracking', 'attribution'],
                'Model_Updates': ['performance_feedback', 'weight_adjustment', 'strategy_optimization']
            },
            'Override_Controls': {
                'Manual_Override': ['force_send', 'block_send', 'priority_boost'],
                'Emergency': ['global_pause', 'channel_pause', 'rapid_deploy']
            }
        }
    },
    'E21': {
        'name': 'ML Clustering',
        'directories': {
            'Segmentation': {
                'Donor_Clustering': ['feature_selection', 'model_training', 'cluster_assignment'],
                'Voter_Clustering': ['demographic_clustering', 'behavioral_clustering'],
                'Dynamic_Segments': ['real_time_scoring', 'segment_migration', 'alerts']
            },
            'Modeling': {
                'Propensity_Models': ['donation_propensity', 'volunteer_propensity', 'churn_propensity'],
                'Optimization_Models': ['ask_optimization', 'channel_optimization', 'timing_optimization']
            },
            'Deployment': {
                'Model_Serving': ['api_endpoint', 'batch_scoring', 'real_time_scoring'],
                'Monitoring': ['model_drift', 'performance_tracking', 'retraining_triggers']
            }
        }
    },
    'E22': {
        'name': 'AB Testing Engine',
        'directories': {
            'Test_Management': {
                'Creation': ['test_setup', 'variant_definition', 'audience_split'],
                'Execution': ['traffic_allocation', 'variant_serving', 'data_collection'],
                'Analysis': ['statistical_analysis', 'significance_testing', 'winner_declaration']
            },
            'Multi_Variate': {
                'Design': ['factor_selection', 'interaction_analysis'],
                'Optimization': ['bandit_algorithms', 'adaptive_allocation']
            },
            'Reporting': {
                'Results': ['variant_comparison', 'confidence_intervals', 'lift_calculation'],
                'Insights': ['segment_analysis', 'time_series', 'recommendations']
            }
        }
    },
    'E23': {
        'name': '3D Creative Assets',
        'directories': {
            'Asset_Creation': {
                'Model_Generation': ['template_selection', 'customization', 'rendering'],
                'Animation': ['motion_presets', 'custom_animation', 'export']
            },
            'Library': {
                'Templates': ['category_management', 'tagging', 'search'],
                'Custom_Assets': ['upload', 'approval', 'organization']
            },
            'Integration': {
                'Video_Export': ['format_selection', 'quality_settings', 'delivery'],
                'Social_Export': ['platform_optimization', 'sizing', 'compression']
            }
        }
    },
    'E24': {
        'name': 'Candidate Portal',
        'directories': {
            'Dashboard': {
                'Overview': ['metrics_display', 'alerts', 'quick_actions'],
                'Performance': ['fundraising_stats', 'outreach_stats', 'volunteer_stats']
            },
            'Content_Management': {
                'Approval_Queue': ['pending_items', 'review_workflow', 'bulk_actions'],
                'Asset_Library': ['browse', 'upload', 'organize']
            },
            'Communication': {
                'Compose': ['email_composer', 'sms_composer', 'social_composer'],
                'History': ['sent_messages', 'scheduled', 'drafts']
            },
            'Settings': {
                'Profile': ['account_settings', 'notification_preferences', 'security'],
                'Team': ['user_management', 'role_assignment', 'permissions']
            }
        }
    },
    'E25': {
        'name': 'Donor Portal',
        'directories': {
            'Account': {
                'Profile': ['personal_info', 'communication_preferences', 'payment_methods'],
                'History': ['donation_history', 'event_attendance', 'engagement_history']
            },
            'Giving': {
                'Donate': ['one_time', 'recurring', 'pledge'],
                'Manage_Recurring': ['view_subscriptions', 'modify', 'cancel']
            },
            'Engagement': {
                'Events': ['event_calendar', 'rsvp', 'tickets'],
                'Updates': ['campaign_updates', 'impact_reports', 'newsletters']
            }
        }
    },
    'E26': {
        'name': 'Volunteer Portal',
        'directories': {
            'Account': {
                'Profile': ['personal_info', 'skills', 'availability'],
                'History': ['hours_logged', 'events_attended', 'achievements']
            },
            'Opportunities': {
                'Browse': ['shift_calendar', 'event_list', 'location_filter'],
                'Signup': ['shift_signup', 'event_rsvp', 'team_join']
            },
            'My_Schedule': {
                'Upcoming': ['confirmed_shifts', 'pending_requests'],
                'Check_In': ['arrival_logging', 'hour_submission']
            },
            'Resources': {
                'Training': ['required_training', 'optional_courses', 'certifications'],
                'Materials': ['scripts', 'talking_points', 'collateral']
            }
        }
    },
    'E27': {
        'name': 'Realtime Dashboard',
        'directories': {
            'Live_Metrics': {
                'Donations': ['real_time_total', 'donor_count', 'average_gift'],
                'Outreach': ['emails_sent', 'sms_sent', 'calls_made'],
                'Engagement': ['website_visitors', 'form_submissions', 'social_engagement']
            },
            'Alerts': {
                'Thresholds': ['milestone_alerts', 'anomaly_detection', 'goal_tracking'],
                'Notifications': ['email_alerts', 'sms_alerts', 'push_notifications']
            },
            'Widgets': {
                'Configuration': ['widget_selection', 'layout', 'refresh_rate'],
                'Custom': ['custom_metrics', 'calculated_fields']
            }
        }
    },
    'E28': {
        'name': 'Financial Dashboard',
        'directories': {
            'Revenue': {
                'Donations': ['by_source', 'by_channel', 'by_segment'],
                'Trends': ['daily_tracking', 'comparison', 'forecasting']
            },
            'Expenses': {
                'By_Category': ['media', 'operations', 'payroll', 'consulting'],
                'By_Vendor': ['vendor_breakdown', 'payment_status']
            },
            'Compliance': {
                'FEC_Summary': ['contributions', 'disbursements', 'cash_on_hand'],
                'Filing_Status': ['upcoming_deadlines', 'filed_reports']
            }
        }
    },
    'E29': {
        'name': 'Analytics Dashboard',
        'directories': {
            'Campaign_Performance': {
                'Email': ['open_rates', 'click_rates', 'conversions'],
                'SMS': ['delivery_rates', 'response_rates', 'opt_outs'],
                'Ads': ['impressions', 'clicks', 'conversions', 'roas']
            },
            'Audience_Insights': {
                'Demographics': ['age', 'gender', 'location'],
                'Behavior': ['engagement_patterns', 'donation_patterns', 'channel_preferences']
            },
            'Attribution': {
                'Source_Tracking': ['first_touch', 'last_touch', 'multi_touch'],
                'Channel_Attribution': ['cross_channel', 'assisted_conversions']
            }
        }
    },
    'E30': {
        'name': 'Email System',
        'directories': {
            'Sending': {
                'Transactional': ['receipts', 'confirmations', 'notifications'],
                'Marketing': ['campaigns', 'newsletters', 'appeals'],
                'Automated': ['drip_sequences', 'triggered_emails', 'welcome_series']
            },
            'Delivery': {
                'Provider': ['sendgrid_routing', 'failover', 'rate_limiting'],
                'Reputation': ['bounce_handling', 'complaint_processing', 'warmup']
            },
            'Personalization': {
                'Merge_Fields': ['standard_fields', 'custom_fields', 'conditional_content'],
                'Dynamic_Content': ['audience_variants', 'behavior_based']
            },
            'AB_Testing': {
                'Subject_Lines': ['variant_creation', 'winner_selection'],
                'Content': ['body_variants', 'cta_variants'],
                'Send_Time': ['time_optimization', 'timezone_handling']
            },
            'Analytics': {
                'Engagement': ['opens', 'clicks', 'conversions'],
                'Deliverability': ['bounces', 'complaints', 'unsubscribes']
            }
        }
    },
    'E31': {
        'name': 'SMS System',
        'directories': {
            'Sending': {
                'Campaigns': ['bulk_send', 'segmented_send', 'personalized_send'],
                'Automated': ['triggers', 'sequences', 'responses'],
                'P2P': ['peer_texting', 'conversation_management']
            },
            'Delivery': {
                'Bandwidth': ['api_integration', 'number_management', 'routing'],
                'Compliance': ['tcpa_check', 'opt_out_processing', 'quiet_hours']
            },
            'Responses': {
                'Inbound': ['message_routing', 'keyword_triggers', 'ai_response'],
                'Conversation': ['thread_management', 'assignment', 'escalation']
            },
            'Analytics': {
                'Delivery': ['success_rate', 'carrier_breakdown'],
                'Engagement': ['response_rate', 'opt_out_rate', 'conversions']
            }
        }
    },
    'E32': {
        'name': 'Phone Banking',
        'directories': {
            'Campaign_Setup': {
                'List_Management': ['upload', 'deduplication', 'prioritization'],
                'Script_Assignment': ['script_selection', 'branching_logic'],
                'Caller_Assignment': ['volunteer_assignment', 'load_balancing']
            },
            'Dialing': {
                'Predictive': ['pacing', 'abandonment_rate', 'agent_availability'],
                'Preview': ['record_preview', 'manual_dial', 'disposition'],
                'Robocall': ['ivr_setup', 'transfer_routing', 'message_playback']
            },
            'Results': {
                'Disposition': ['outcome_recording', 'callback_scheduling', 'dnc_processing'],
                'Survey': ['response_capture', 'data_sync']
            },
            'Compliance': {
                'DNC': ['list_scrubbing', 'real_time_check'],
                'Timing': ['calling_hours', 'timezone_management']
            }
        }
    },
    'E33': {
        'name': 'Direct Mail',
        'directories': {
            'List_Preparation': {
                'Selection': ['audience_query', 'segmentation', 'suppression'],
                'Address_Hygiene': ['ncoa_processing', 'cass_certification', 'deduplication'],
                'Postal_Optimization': ['presort', 'drop_shipping', 'commingling']
            },
            'Creative': {
                'Design': ['template_selection', 'personalization_mapping'],
                'Proofing': ['digital_proof', 'approval_workflow', 'revision']
            },
            'Production': {
                'Print_Vendor': ['job_submission', 'status_tracking', 'delivery'],
                'Inventory': ['stock_management', 'reorder']
            },
            'Tracking': {
                'Mail_Tracking': ['imb_tracking', 'delivery_confirmation'],
                'Response': ['response_tracking', 'attribution', 'roi_calculation']
            }
        }
    },
    'E34': {
        'name': 'Events System',
        'directories': {
            'Event_Management': {
                'Creation': ['event_setup', 'ticketing', 'registration'],
                'Promotion': ['email_invites', 'social_posts', 'paid_ads'],
                'Logistics': ['venue_management', 'vendor_coordination', 'timeline']
            },
            'Registration': {
                'Forms': ['registration_form', 'ticket_selection', 'payment'],
                'Management': ['attendee_list', 'check_in', 'badges']
            },
            'Communication': {
                'Pre_Event': ['confirmations', 'reminders', 'updates'],
                'Post_Event': ['thank_you', 'surveys', 'follow_up']
            }
        }
    },
    'E35': {
        'name': 'Interactive Comm Hub',
        'directories': {
            'Live_Chat': {
                'Widget': ['website_embed', 'customization', 'availability'],
                'Routing': ['agent_assignment', 'queue_management', 'escalation'],
                'AI_Assist': ['suggested_responses', 'auto_response', 'sentiment_detection']
            },
            'Chatbot': {
                'Flows': ['flow_builder', 'intent_recognition', 'entity_extraction'],
                'Integration': ['crm_sync', 'donation_processing', 'volunteer_signup']
            },
            'Auto_Response': {
                'Email': ['auto_reply', 'ai_drafting', 'approval_queue'],
                'SMS': ['keyword_response', 'ai_conversation']
            }
        }
    },
    'E36': {
        'name': 'Messenger Integration',
        'directories': {
            'Facebook_Messenger': {
                'Setup': ['page_connection', 'webhook_config', 'permissions'],
                'Messaging': ['broadcast', 'targeted', 'sponsored'],
                'Automation': ['welcome_message', 'quick_replies', 'chatbot']
            },
            'WhatsApp': {
                'Setup': ['business_account', 'template_approval'],
                'Messaging': ['template_messages', 'session_messages'],
                'Automation': ['quick_replies', 'buttons', 'list_messages']
            },
            'Instagram_DM': {
                'Setup': ['account_connection', 'permissions'],
                'Messaging': ['direct_messages', 'story_replies']
            }
        }
    },
    'E37': {
        'name': 'Event Management',
        'directories': {
            'Planning': {
                'Calendar': ['event_scheduling', 'conflict_detection', 'resource_booking'],
                'Budget': ['cost_estimation', 'vendor_quotes', 'payment_tracking']
            },
            'Execution': {
                'Day_Of': ['check_in', 'volunteer_coordination', 'live_updates'],
                'Virtual': ['streaming_setup', 'engagement_tools', 'breakout_rooms']
            },
            'Analysis': {
                'Attendance': ['registration_vs_attendance', 'no_show_analysis'],
                'ROI': ['cost_per_attendee', 'donation_attribution', 'follow_up_conversion']
            }
        }
    },
    'E38': {
        'name': 'Volunteer Coordination',
        'directories': {
            'Recruitment': {
                'Outreach': ['targeted_recruitment', 'referral_program', 'social_recruiting'],
                'Screening': ['application_review', 'background_check', 'interview']
            },
            'Training': {
                'Onboarding': ['welcome_sequence', 'orientation', 'handbook'],
                'Skills': ['role_training', 'tool_training', 'certification']
            },
            'Management': {
                'Scheduling': ['shift_management', 'availability_tracking', 'conflict_resolution'],
                'Performance': ['hour_tracking', 'quality_scoring', 'recognition']
            }
        }
    },
    'E39': {
        'name': 'P2P Fundraising',
        'directories': {
            'Campaign_Setup': {
                'Page_Creation': ['team_pages', 'individual_pages', 'customization'],
                'Goals': ['fundraising_goals', 'milestone_badges', 'leaderboards']
            },
            'Fundraiser_Tools': {
                'Sharing': ['social_sharing', 'email_templates', 'link_tracking'],
                'Management': ['donor_list', 'thank_you_messages', 'updates']
            },
            'Admin': {
                'Monitoring': ['progress_tracking', 'top_performers', 'coaching'],
                'Reporting': ['revenue_attribution', 'participant_analysis']
            }
        }
    },
    'E40': {
        'name': 'Automation Control Panel',
        'directories': {
            'Workflow_Builder': {
                'Triggers': ['event_triggers', 'time_triggers', 'behavior_triggers'],
                'Actions': ['communication_actions', 'data_actions', 'integration_actions'],
                'Conditions': ['if_then', 'branching', 'filters']
            },
            'Templates': {
                'Library': ['pre_built_workflows', 'custom_templates'],
                'Import_Export': ['workflow_sharing', 'backup_restore']
            },
            'Control_Modes': {
                'Toggle': ['on_off', 'timer', 'ai_control'],
                'Issue_Response': ['suspend_by_issue', 'resume', 'emergency_override']
            },
            'Monitoring': {
                'Execution': ['active_workflows', 'pending_actions', 'error_log'],
                'Performance': ['conversion_tracking', 'ab_results', 'recommendations']
            }
        }
    },
    'E41': {
        'name': 'Campaign Builder',
        'directories': {
            'Creation': {
                'Setup': ['campaign_type', 'goals', 'timeline'],
                'Audience': ['segment_selection', 'exclusions', 'volume_control'],
                'Content': ['message_creation', 'creative_upload', 'personalization']
            },
            'Channels': {
                'Selection': ['channel_mix', 'sequencing', 'timing'],
                'Coordination': ['cross_channel_sync', 'frequency_capping']
            },
            'Launch': {
                'Review': ['compliance_check', 'audience_preview', 'cost_estimate'],
                'Approval': ['approval_workflow', 'scheduling'],
                'Execution': ['send_initiation', 'monitoring']
            }
        }
    },
    'E42': {
        'name': 'News Intelligence',
        'directories': {
            'Monitoring': {
                'Sources': ['news_apis', 'rss_feeds', 'social_monitoring'],
                'Keywords': ['keyword_management', 'entity_tracking', 'competitor_tracking']
            },
            'Analysis': {
                'Sentiment': ['sentiment_scoring', 'trend_detection', 'alert_triggers'],
                'Categorization': ['topic_classification', 'relevance_scoring']
            },
            'Response': {
                'Alerts': ['real_time_alerts', 'digest_emails', 'dashboard_notifications'],
                'Actions': ['rapid_response_trigger', 'talking_points_generation']
            }
        }
    },
    'E43': {
        'name': 'Advocacy Tools',
        'directories': {
            'Petitions': {
                'Creation': ['petition_builder', 'signature_goals', 'sharing'],
                'Management': ['signature_tracking', 'verification', 'reporting']
            },
            'Action_Alerts': {
                'Setup': ['alert_creation', 'target_officials', 'message_templates'],
                'Distribution': ['email_blast', 'sms_blast', 'social_push'],
                'Tracking': ['action_completion', 'official_response']
            },
            'Grassroots': {
                'Mobilization': ['call_to_action', 'event_promotion', 'volunteer_asks'],
                'Tracking': ['participation_tracking', 'impact_measurement']
            }
        }
    },
    'E44': {
        'name': 'Vendor Compliance Security',
        'directories': {
            'Vendor_Management': {
                'Onboarding': ['vendor_registration', 'contract_management', 'compliance_check'],
                'Monitoring': ['performance_tracking', 'sla_monitoring', 'issue_tracking']
            },
            'Security': {
                'Access_Control': ['user_permissions', 'api_keys', 'audit_logging'],
                'Data_Protection': ['encryption', 'backup', 'retention']
            },
            'Compliance': {
                'Auditing': ['compliance_reports', 'exception_tracking', 'remediation'],
                'Certifications': ['certification_tracking', 'renewal_alerts']
            }
        }
    },
    'E45': {
        'name': 'Video Studio',
        'directories': {
            'Production': {
                'Recording': ['webcam_capture', 'screen_recording', 'upload'],
                'AI_Generation': ['talking_head', 'b_roll', 'animations'],
                'Editing': ['trimming', 'transitions', 'overlays', 'captions']
            },
            'Templates': {
                'Library': ['video_templates', 'intro_outros', 'lower_thirds'],
                'Customization': ['branding', 'color_grading', 'music']
            },
            'Export': {
                'Formats': ['social_formats', 'broadcast_formats', 'web_formats'],
                'Distribution': ['youtube_upload', 'social_posting', 'cdn_hosting']
            },
            'Teleprompter': {
                'Scripts': ['script_loading', 'scroll_speed', 'cue_markers'],
                'Recording': ['prompter_display', 'recording_sync']
            }
        }
    },
    'E46': {
        'name': 'Broadcast Hub',
        'directories': {
            'Live_Streaming': {
                'Setup': ['stream_configuration', 'encoder_settings', 'destinations'],
                'Multi_Platform': ['facebook_live', 'youtube_live', 'rumble', 'x_live'],
                'Production': ['scene_switching', 'graphics_overlay', 'guest_management']
            },
            'Town_Halls': {
                'Scheduling': ['event_creation', 'registration', 'reminders'],
                'Moderation': ['question_queue', 'participant_management', 'chat_moderation'],
                'Engagement': ['polls', 'qa', 'reactions']
            },
            'Recording': {
                'Capture': ['stream_recording', 'backup_recording'],
                'Post_Production': ['clip_extraction', 'highlight_reel', 'transcript']
            }
        }
    },
    'E47': {
        'name': 'AI Script Generator',
        'directories': {
            'Script_Generation': {
                'Types': ['rvm_scripts', 'phone_scripts', 'video_scripts', 'email_scripts'],
                'Customization': ['issue_selection', 'tone_setting', 'audience_targeting'],
                'Variations': ['ab_variants', 'audience_versions', 'length_options']
            },
            'Voice_Synthesis': {
                'Chatterbox_TTS': ['voice_cloning', 'voice_selection', 'quality_settings'],
                'Audio_Generation': ['script_to_audio', 'batch_processing', 'export'],
                'Quality_Control': ['preview', 'approval', 'revision']
            },
            'Communication_DNA': {
                'Profile': ['tone_settings', 'vocabulary', 'style'],
                'Application': ['auto_apply', 'override_settings']
            }
        }
    },
    'E48': {
        'name': 'Communication DNA',
        'directories': {
            'Profile_Management': {
                'Voice': ['tone', 'formality', 'vocabulary', 'phrases'],
                'Style': ['greeting_style', 'closing_style', 'emoji_usage'],
                'Constraints': ['words_to_avoid', 'required_elements', 'length_preferences']
            },
            'Application': {
                'Content_Generation': ['ai_prompt_injection', 'post_processing'],
                'Quality_Check': ['voice_consistency', 'brand_compliance']
            },
            'Learning': {
                'Feedback': ['approval_tracking', 'revision_analysis'],
                'Optimization': ['style_refinement', 'performance_correlation']
            }
        }
    },
    'E49': {
        'name': 'Interview System',
        'directories': {
            'Preparation': {
                'Question_Bank': ['common_questions', 'issue_questions', 'gotcha_questions'],
                'Talking_Points': ['key_messages', 'pivots', 'bridges'],
                'Practice': ['mock_interviews', 'video_review', 'coaching']
            },
            'During_Interview': {
                'Real_Time': ['talking_point_prompts', 'fact_checking', 'time_tracking'],
                'Recording': ['audio_capture', 'video_capture', 'transcript']
            },
            'Post_Interview': {
                'Analysis': ['performance_scoring', 'message_discipline', 'improvement_areas'],
                'Clip_Extraction': ['highlight_clips', 'social_snippets']
            }
        }
    },
    'E50': {
        'name': 'GPU Orchestrator',
        'directories': {
            'Resource_Management': {
                'GPU_Allocation': ['job_queue', 'priority_scheduling', 'resource_limits'],
                'Server_Management': ['hetzner_gex44', 'health_monitoring', 'scaling']
            },
            'Video_Processing': {
                'SadTalker': ['talking_head_generation', 'lip_sync', 'emotion_control'],
                'Transcoding': ['format_conversion', 'compression', 'batch_processing']
            },
            'Voice_Processing': {
                'Chatterbox_TTS': ['voice_cloning', 'speech_synthesis', 'quality_check'],
                'ASR': ['transcription', 'speaker_diarization']
            },
            'Cost_Management': {
                'Usage_Tracking': ['gpu_hours', 'cost_calculation'],
                'Optimization': ['job_batching', 'off_peak_scheduling']
            }
        }
    },
    'E51': {
        'name': 'Nexus Social',
        'directories': {
            'Data_Collection': {
                'Profile_Harvesting': ['linkedin', 'facebook', 'twitter', 'instagram'],
                'Enrichment': ['contact_append', 'demographic_append', 'social_append']
            },
            'Analysis': {
                'Network_Mapping': ['connections', 'influence_scoring', 'community_detection'],
                'Engagement_Scoring': ['activity_level', 'content_analysis', 'sentiment']
            },
            'Integration': {
                'CRM_Sync': ['contact_creation', 'field_mapping', 'update_frequency'],
                'Outreach': ['personalized_messaging', 'connection_requests']
            }
        }
    },
    'E52': {
        'name': 'Messaging Center',
        'directories': {
            'Inbox': {
                'Message_Reception': ['sms_inbound', 'email_inbound', 'portal_messages'],
                'Routing': ['auto_categorization', 'priority_assignment', 'agent_assignment'],
                'Threading': ['conversation_grouping', 'history_display']
            },
            'Response': {
                'Manual_Reply': ['compose', 'template_insert', 'send'],
                'AI_Assist': ['suggested_reply', 'auto_draft', 'sentiment_analysis'],
                'Automation': ['auto_response', 'escalation_rules']
            },
            'Notifications': {
                'Badge_Count': ['unread_tracking', 'priority_alerts'],
                'Newsfeed': ['activity_stream', 'candidate_dashboard']
            }
        }
    },
    'E53': {
        'name': 'Document Generation',
        'directories': {
            'Templates': {
                'Donor_Documents': ['receipts', 'thank_you_letters', 'tax_letters', 'pledge_reminders'],
                'FEC_Forms': ['form_3', 'form_3p', 'form_24', 'schedules'],
                'Volunteer_Documents': ['certificates', 'packets', 'training_materials'],
                'Campaign_Materials': ['palm_cards', 'door_hangers', 'flyers']
            },
            'Generation': {
                'Single': ['on_demand', 'personalization', 'preview'],
                'Batch': ['bulk_generation', 'mail_merge', 'progress_tracking']
            },
            'Delivery': {
                'Download': ['pdf_download', 'print_queue'],
                'Email': ['auto_attach', 'scheduled_delivery']
            }
        }
    },
    'E54': {
        'name': 'Calendar Scheduling',
        'directories': {
            'Event_Management': {
                'Creation': ['event_types', 'recurrence', 'capacity'],
                'Modification': ['drag_drop', 'resize', 'bulk_edit'],
                'Deletion': ['single_delete', 'series_delete', 'cancellation_notice']
            },
            'Views': {
                'Calendar_Views': ['month', 'week', 'day', 'list'],
                'Filtering': ['by_type', 'by_candidate', 'by_county']
            },
            'RSVP': {
                'Registration': ['signup_form', 'capacity_check', 'waitlist'],
                'Management': ['attendee_list', 'check_in', 'no_show_tracking']
            },
            'Reminders': {
                'Scheduling': ['reminder_times', 'channels', 'content'],
                'Sending': ['email_reminders', 'sms_reminders', 'rvm_reminders']
            },
            'Integration': {
                'Communication': ['invite_emails', 'update_notifications'],
                'Volunteer': ['shift_creation', 'signup_sync']
            }
        }
    },
    'E55': {
        'name': 'API Gateway',
        'directories': {
            'External_APIs': {
                'Government': ['fec_gov', 'nc_sboe', 'legiscan', 'opensecrets'],
                'Enrichment': ['bettercontact', 'clearbit', 'fullcontact'],
                'Communication': ['twilio', 'bandwidth', 'drop_cowboy', 'sendgrid'],
                'Payment': ['stripe', 'paypal', 'actblue'],
                'AI': ['openai', 'anthropic']
            },
            'Rate_Limiting': {
                'Per_Provider': ['request_limits', 'window_config', 'burst_handling'],
                'Monitoring': ['usage_tracking', 'alert_thresholds']
            },
            'Circuit_Breaker': {
                'Failure_Detection': ['threshold_config', 'timeout_settings'],
                'Recovery': ['half_open_testing', 'auto_recovery']
            },
            'API_Keys': {
                'Management': ['key_generation', 'permissions', 'expiration'],
                'Security': ['ip_whitelist', 'rate_limits', 'audit_logging']
            },
            'Webhooks': {
                'Registration': ['endpoint_config', 'event_selection', 'secret_management'],
                'Delivery': ['retry_logic', 'failure_handling', 'logging']
            }
        }
    }
}

# ============================================================================
# MASTER CONTROL PANEL
# ============================================================================

class MasterControlPanel:
    """
    Hierarchical control panel managing ALL 56 ecosystems.
    Each ecosystem has 3-5 level deep directory structure.
    All controls accessible from E00 Intelligence Hub.
    """
    
    def __init__(self, redis_client=None, supabase_client=None):
        self.redis = redis_client
        self.supabase = supabase_client
        
        # Root control structure
        self.control_tree: Dict[str, ControlDirectory] = {}
        
        # Feature toggles indexed by path
        self.toggles: Dict[str, FeatureToggle] = {}
        
        # Change history
        self.change_log: List[Dict] = []
        
        # Initialize control structure
        self._initialize_control_structure()
    
    def _initialize_control_structure(self):
        """Build the complete control hierarchy from ECOSYSTEM_CONTROL_STRUCTURE."""
        for eco_id, eco_config in ECOSYSTEM_CONTROL_STRUCTURE.items():
            eco_dir = ControlDirectory(
                name=eco_config['name'],
                path=eco_id,
                parent_path='',
                level=0,
                ecosystem=eco_id,
                description=f"{eco_id} - {eco_config['name']}"
            )
            
            # Build subdirectories
            self._build_directory_tree(
                eco_dir,
                eco_config.get('directories', {}),
                eco_id,
                1
            )
            
            self.control_tree[eco_id] = eco_dir
        
        logger.info(f"Initialized control panel with {len(self.control_tree)} ecosystems, {len(self.toggles)} features")
    
    def _build_directory_tree(
        self,
        parent: ControlDirectory,
        structure: Dict,
        base_path: str,
        level: int
    ):
        """Recursively build directory tree."""
        for name, children in structure.items():
            path = f"{base_path}/{name}"
            
            if isinstance(children, dict):
                # This is a subdirectory
                subdir = ControlDirectory(
                    name=name,
                    path=path,
                    parent_path=parent.path,
                    level=level,
                    ecosystem=parent.ecosystem
                )
                self._build_directory_tree(subdir, children, path, level + 1)
                parent.subdirectories[name] = subdir
            elif isinstance(children, list):
                # This is a directory with feature toggles
                subdir = ControlDirectory(
                    name=name,
                    path=path,
                    parent_path=parent.path,
                    level=level,
                    ecosystem=parent.ecosystem
                )
                
                # Create toggles for each feature
                for feature_name in children:
                    feature_path = f"{path}/{feature_name}"
                    toggle = FeatureToggle(
                        name=feature_name,
                        path=feature_path,
                        state=ToggleState.ON,  # Default ON
                        control_mode=ControlMode.MANUAL
                    )
                    subdir.features[feature_name] = toggle
                    self.toggles[feature_path] = toggle
                
                parent.subdirectories[name] = subdir
    
    # =========================================================================
    # TOGGLE OPERATIONS
    # =========================================================================
    
    def set_toggle(
        self,
        path: str,
        state: ToggleState,
        changed_by: str = '',
        reason: str = ''
    ) -> bool:
        """Set a feature toggle state."""
        toggle = self.toggles.get(path)
        if not toggle:
            logger.error(f"Toggle not found: {path}")
            return False
        
        old_state = toggle.state
        toggle.state = state
        toggle.last_changed_by = changed_by
        toggle.last_changed_at = datetime.now()
        toggle.change_reason = reason
        
        # Clear timer if not TIMER state
        if state != ToggleState.TIMER:
            toggle.timer_start = None
            toggle.timer_end = None
        
        # Log change
        self._log_change(path, old_state.value, state.value, changed_by, reason)
        
        # Publish to Redis for ecosystem notification
        if self.redis:
            asyncio.create_task(self._publish_toggle_change(path, state))
        
        logger.info(f"Toggle {path}: {old_state.value} -> {state.value}")
        return True
    
    def set_timer(
        self,
        path: str,
        start: datetime,
        end: datetime,
        changed_by: str = '',
        recurring: bool = False,
        cron: Optional[str] = None
    ) -> bool:
        """Set a timer-based toggle."""
        toggle = self.toggles.get(path)
        if not toggle:
            return False
        
        toggle.state = ToggleState.TIMER
        toggle.timer_start = start
        toggle.timer_end = end
        toggle.timer_recurring = recurring
        toggle.timer_cron = cron
        toggle.last_changed_by = changed_by
        toggle.last_changed_at = datetime.now()
        
        self._log_change(path, 'previous', 'timer', changed_by, f"Timer: {start} to {end}")
        
        logger.info(f"Timer set for {path}: {start} to {end}")
        return True
    
    def set_ai_control(
        self,
        path: str,
        enabled: bool,
        can_override: bool = False,
        confidence_threshold: float = 0.8,
        changed_by: str = ''
    ) -> bool:
        """Enable/disable AI control for a feature."""
        toggle = self.toggles.get(path)
        if not toggle:
            return False
        
        if enabled:
            toggle.state = ToggleState.AI
            toggle.control_mode = ControlMode.AI
        else:
            toggle.state = ToggleState.ON
            toggle.control_mode = ControlMode.MANUAL
        
        toggle.ai_controlled = enabled
        toggle.ai_can_override = can_override
        toggle.ai_confidence_threshold = confidence_threshold
        toggle.last_changed_by = changed_by
        toggle.last_changed_at = datetime.now()
        
        logger.info(f"AI control {'enabled' if enabled else 'disabled'} for {path}")
        return True
    
    # =========================================================================
    # BULK OPERATIONS
    # =========================================================================
    
    def set_ecosystem_state(
        self,
        ecosystem_id: str,
        state: ToggleState,
        changed_by: str = '',
        reason: str = ''
    ) -> int:
        """Set all features in an ecosystem to a state."""
        count = 0
        prefix = f"{ecosystem_id}/"
        
        for path, toggle in self.toggles.items():
            if path.startswith(prefix) or path == ecosystem_id:
                self.set_toggle(path, state, changed_by, reason)
                count += 1
        
        logger.info(f"Set {count} features in {ecosystem_id} to {state.value}")
        return count
    
    def set_directory_state(
        self,
        directory_path: str,
        state: ToggleState,
        changed_by: str = '',
        reason: str = ''
    ) -> int:
        """Set all features in a directory (and subdirectories) to a state."""
        count = 0
        prefix = f"{directory_path}/"
        
        for path, toggle in self.toggles.items():
            if path.startswith(prefix):
                self.set_toggle(path, state, changed_by, reason)
                count += 1
        
        logger.info(f"Set {count} features in {directory_path} to {state.value}")
        return count
    
    def emergency_shutoff(self, changed_by: str = 'EMERGENCY') -> int:
        """Turn OFF all features across all ecosystems."""
        count = 0
        for path in self.toggles:
            self.set_toggle(path, ToggleState.OFF, changed_by, 'EMERGENCY SHUTOFF')
            count += 1
        
        logger.critical(f"EMERGENCY SHUTOFF: Disabled {count} features")
        return count
    
    def restore_defaults(self, changed_by: str = '') -> int:
        """Restore all features to ON state."""
        count = 0
        for path in self.toggles:
            self.set_toggle(path, ToggleState.ON, changed_by, 'Restore defaults')
            count += 1
        
        logger.info(f"Restored {count} features to defaults")
        return count
    
    def delegate_to_ai(self, ecosystem_id: str, changed_by: str = '') -> int:
        """Delegate an entire ecosystem to AI control."""
        count = 0
        prefix = f"{ecosystem_id}/"
        
        for path in self.toggles:
            if path.startswith(prefix):
                self.set_ai_control(path, True, can_override=True, changed_by=changed_by)
                count += 1
        
        logger.info(f"Delegated {count} features in {ecosystem_id} to AI control")
        return count
    
    # =========================================================================
    # QUERY OPERATIONS
    # =========================================================================
    
    def get_toggle(self, path: str) -> Optional[FeatureToggle]:
        """Get a specific toggle."""
        return self.toggles.get(path)
    
    def get_toggle_state(self, path: str) -> Optional[str]:
        """Get just the state of a toggle."""
        toggle = self.toggles.get(path)
        return toggle.state.value if toggle else None
    
    def is_feature_active(self, path: str) -> bool:
        """Check if a feature is currently active."""
        toggle = self.toggles.get(path)
        if not toggle:
            return False
        
        if toggle.state == ToggleState.OFF:
            return False
        elif toggle.state == ToggleState.ON:
            return True
        elif toggle.state == ToggleState.AI:
            return True  # AI controlled means active
        elif toggle.state == ToggleState.TIMER:
            now = datetime.now()
            if toggle.timer_start and toggle.timer_end:
                return toggle.timer_start <= now <= toggle.timer_end
            return False
        
        return False
    
    def get_ecosystem_status(self, ecosystem_id: str) -> Dict[str, Any]:
        """Get status of all features in an ecosystem."""
        eco = self.control_tree.get(ecosystem_id)
        if not eco:
            return {}
        
        prefix = f"{ecosystem_id}/"
        features = {
            path: {
                'state': toggle.state.value,
                'control_mode': toggle.control_mode.value,
                'ai_controlled': toggle.ai_controlled,
                'last_changed': toggle.last_changed_at.isoformat() if toggle.last_changed_at else None
            }
            for path, toggle in self.toggles.items()
            if path.startswith(prefix)
        }
        
        # Count by state
        state_counts = defaultdict(int)
        for f in features.values():
            state_counts[f['state']] += 1
        
        return {
            'ecosystem_id': ecosystem_id,
            'name': eco.name,
            'total_features': len(features),
            'state_counts': dict(state_counts),
            'features': features
        }
    
    def get_all_status(self) -> Dict[str, Any]:
        """Get status of all ecosystems."""
        ecosystems = {}
        for eco_id in self.control_tree:
            ecosystems[eco_id] = self.get_ecosystem_status(eco_id)
        
        total_features = len(self.toggles)
        state_counts = defaultdict(int)
        for toggle in self.toggles.values():
            state_counts[toggle.state.value] += 1
        
        return {
            'total_ecosystems': len(self.control_tree),
            'total_features': total_features,
            'global_state_counts': dict(state_counts),
            'ecosystems': ecosystems
        }
    
    def get_directory_tree(self, ecosystem_id: str) -> Dict[str, Any]:
        """Get the full directory tree for an ecosystem."""
        eco = self.control_tree.get(ecosystem_id)
        if not eco:
            return {}
        
        return self._directory_to_dict(eco)
    
    def _directory_to_dict(self, dir: ControlDirectory) -> Dict[str, Any]:
        """Convert ControlDirectory to dictionary."""
        result = {
            'name': dir.name,
            'path': dir.path,
            'level': dir.level,
            'subdirectories': {},
            'features': {}
        }
        
        for name, subdir in dir.subdirectories.items():
            result['subdirectories'][name] = self._directory_to_dict(subdir)
        
        for name, toggle in dir.features.items():
            result['features'][name] = {
                'path': toggle.path,
                'state': toggle.state.value,
                'control_mode': toggle.control_mode.value,
                'ai_controlled': toggle.ai_controlled
            }
        
        return result
    
    # =========================================================================
    # LOGGING & AUDIT
    # =========================================================================
    
    def _log_change(
        self,
        path: str,
        old_value: str,
        new_value: str,
        changed_by: str,
        reason: str
    ):
        """Log a change to the audit trail."""
        entry = {
            'timestamp': datetime.now().isoformat(),
            'path': path,
            'old_value': old_value,
            'new_value': new_value,
            'changed_by': changed_by,
            'reason': reason
        }
        self.change_log.append(entry)
        
        # Keep last 10000 entries
        if len(self.change_log) > 10000:
            self.change_log = self.change_log[-10000:]
    
    def get_change_log(
        self,
        path_filter: Optional[str] = None,
        limit: int = 100
    ) -> List[Dict]:
        """Get recent changes, optionally filtered by path."""
        log = self.change_log
        if path_filter:
            log = [e for e in log if path_filter in e['path']]
        return log[-limit:]
    
    # =========================================================================
    # REDIS INTEGRATION
    # =========================================================================
    
    async def _publish_toggle_change(self, path: str, state: ToggleState):
        """Publish toggle change to Redis for ecosystem notification."""
        if not self.redis:
            return
        
        # Determine ecosystem from path
        ecosystem = path.split('/')[0]
        
        payload = {
            'event': 'toggle_change',
            'path': path,
            'state': state.value,
            'timestamp': datetime.now().isoformat()
        }
        
        # Publish to ecosystem-specific channel
        channel = f"e00:control:{ecosystem.lower()}"
        await self.redis.publish(channel, json.dumps(payload))
        
        # Also publish to global control channel
        await self.redis.publish('e00:control:global', json.dumps(payload))
    
    # =========================================================================
    # E00 HUB INTERFACE
    # =========================================================================
    
    async def receive_hub_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Receive control commands from E00 Intelligence Hub."""
        action = command.get('action')
        
        if action == 'set_toggle':
            success = self.set_toggle(
                command['path'],
                ToggleState(command['state']),
                command.get('changed_by', 'E00_Hub'),
                command.get('reason', '')
            )
            return {'success': success}
        
        elif action == 'set_timer':
            success = self.set_timer(
                command['path'],
                datetime.fromisoformat(command['start']),
                datetime.fromisoformat(command['end']),
                command.get('changed_by', 'E00_Hub'),
                command.get('recurring', False),
                command.get('cron')
            )
            return {'success': success}
        
        elif action == 'set_ai_control':
            success = self.set_ai_control(
                command['path'],
                command['enabled'],
                command.get('can_override', False),
                command.get('confidence_threshold', 0.8),
                command.get('changed_by', 'E00_Hub')
            )
            return {'success': success}
        
        elif action == 'set_ecosystem_state':
            count = self.set_ecosystem_state(
                command['ecosystem_id'],
                ToggleState(command['state']),
                command.get('changed_by', 'E00_Hub'),
                command.get('reason', '')
            )
            return {'success': True, 'count': count}
        
        elif action == 'emergency_shutoff':
            count = self.emergency_shutoff(command.get('changed_by', 'EMERGENCY'))
            return {'success': True, 'count': count}
        
        elif action == 'get_status':
            if 'ecosystem_id' in command:
                return self.get_ecosystem_status(command['ecosystem_id'])
            else:
                return self.get_all_status()
        
        elif action == 'check_feature':
            return {'active': self.is_feature_active(command['path'])}
        
        return {'error': f"Unknown action: {action}"}


# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

def create_control_panel() -> MasterControlPanel:
    """Create and initialize the master control panel."""
    return MasterControlPanel()


def print_ecosystem_tree(panel: MasterControlPanel, ecosystem_id: str):
    """Print the directory tree for an ecosystem."""
    tree = panel.get_directory_tree(ecosystem_id)
    
    def print_tree(node: Dict, indent: int = 0):
        prefix = "  " * indent
        print(f"{prefix}{node['name']}/")
        
        for name, feat in node.get('features', {}).items():
            state = feat['state'].upper()
            mode = 'AI' if feat['ai_controlled'] else 'Manual'
            print(f"{prefix}  ├── {name} [{state}] ({mode})")
        
        for name, subdir in node.get('subdirectories', {}).items():
            print_tree(subdir, indent + 1)
    
    print_tree(tree)


# ============================================================================
# MAIN
# ============================================================================

async def main():
    """Demonstrate the Master Control Panel."""
    print("="*80)
    print("MASTER CONTROL PANEL - HIERARCHICAL ECOSYSTEM MANAGEMENT")
    print("="*80)
    print()
    
    panel = create_control_panel()
    
    # Show stats
    status = panel.get_all_status()
    print(f"Total Ecosystems: {status['total_ecosystems']}")
    print(f"Total Features: {status['total_features']}")
    print(f"State Distribution: {status['global_state_counts']}")
    print()
    
    # Show E01 tree
    print("E01 Donor Intelligence Control Tree:")
    print("-" * 40)
    print_ecosystem_tree(panel, 'E01')
    print()
    
    # Demo operations
    print("Demo Operations:")
    print("-" * 40)
    
    # Turn off FEC import
    panel.set_toggle('E01/Data_Ingestion/FEC_Import/auto_sync', ToggleState.OFF, 'admin', 'Maintenance')
    print("✓ E01/Data_Ingestion/FEC_Import/auto_sync -> OFF")
    
    # Set timer for batch regrade
    panel.set_timer(
        'E01/Grading_Engine/Auto_Regrade/batch_regrade',
        datetime.now() + timedelta(hours=2),
        datetime.now() + timedelta(hours=4),
        'admin'
    )
    print("✓ E01/Grading_Engine/Auto_Regrade/batch_regrade -> TIMER (2h from now)")
    
    # Delegate E47 to AI
    count = panel.delegate_to_ai('E47', 'admin')
    print(f"✓ Delegated {count} features in E47 to AI control")
    
    # Check if feature is active
    active = panel.is_feature_active('E01/Data_Ingestion/FEC_Import/auto_sync')
    print(f"✓ E01/Data_Ingestion/FEC_Import/auto_sync active: {active}")
    
    print()
    print("Control Panel ready for E00 Intelligence Hub integration.")


if __name__ == '__main__':
    asyncio.run(main())
