/**
 * NEXUS AI Agent System - TypeScript Types
 * =========================================
 * Type definitions for NEXUS integration with BroyhillGOP platform
 */

// ============================================================================
// ENUMS
// ============================================================================

export type Decision = 'GO' | 'NO_GO' | 'DEFER' | 'MANUAL_REVIEW';

export type TriggerType = 
  | 'HARVEST_IMPORT'
  | 'HARVEST_MATCH'
  | 'ENRICHMENT_FEC'
  | 'ENRICHMENT_VOTER'
  | 'ENRICHMENT_PROPERTY'
  | 'PERSONA_ANALYSIS'
  | 'DRAFT_GENERATION'
  | 'APPROVAL_LEARNING';

export type EnrichmentSource = 'fec' | 'nc_sboe' | 'property' | 'sec_edgar' | 'opensecrets';

export type MatchMethod = 
  | 'email_exact'
  | 'phone_exact'
  | 'facebook_id'
  | 'name_zip'
  | 'name_phone_last4';

export type BVAStatus = 
  | 'ON_TARGET'
  | 'OVER_PERFORMING'
  | 'CRITICAL_UNDER'
  | 'WARNING_UNDER'
  | 'SLIGHT_UNDER';

export type CostType = 'AI_API' | 'INFRASTRUCTURE' | 'DATA' | 'VENDOR';

// ============================================================================
// MODEL SCORES (7 Mathematical Models)
// ============================================================================

export interface ModelScores {
  model_1_expected_roi: number;         // 0-100x
  model_2_success_probability: number;   // 0-1.0
  model_3_relevance_score: number;       // 0-100
  model_4_expected_cost: number;         // $0.00+
  model_5_persona_match_score: number;   // 0-100
  model_6_budget_approved: boolean;      // TRUE/FALSE
  model_7_confidence_score: number;      // 0-100
  reason: string;
  composite_score: number;               // Calculated
}

// ============================================================================
// HARVEST RECORDS
// ============================================================================

export interface HarvestRecord {
  harvest_id: string;
  raw_first_name: string;
  raw_last_name: string;
  raw_email: string;
  raw_phone: string;
  raw_address: string;
  raw_city: string;
  raw_state: string;
  raw_zip: string;
  normalized_email: string;
  normalized_phone: string;
  facebook_id?: string;
  facebook_url?: string;
  twitter_handle?: string;
  instagram_handle?: string;
  linkedin_url?: string;
  source_type: string;
  source_name: string;
  batch_id: string;
  enrichment_status: 'pending' | 'queued' | 'processing' | 'completed' | 'failed';
  enrichment_priority: number;
  enrichment_score: number;
  matched_donor_id?: string;
  matched_volunteer_id?: string;
  match_confidence: number;
  match_method?: MatchMethod;
  match_verified: boolean;
  created_at: string;
  matched_at?: string;
}

export interface HarvestBatch {
  batch_id: string;
  source_type: string;
  source_name: string;
  total_records: number;
  imported: number;
  duplicates: number;
  matched: number;
  created_at: string;
}

export interface HarvestImportResult {
  batch_id: string;
  imported: number;
  duplicates: number;
  total: number;
}

export interface MatchingResult {
  processed: number;
  matched: number;
  match_rate: number;
}

// ============================================================================
// VOICE SIGNATURE & PERSONA
// ============================================================================

export interface VoiceSignature {
  formality: number;          // 1-10
  warmth: number;             // 1-10
  directness: number;         // 1-10
  emotion_intensity: number;  // 1-10
  humor_frequency: number;    // 0-1
  avg_sentence_length: number;
  vocabulary_level: 'simple' | 'moderate' | 'advanced';
}

export interface IssueVocabulary {
  issue_code: string;
  issue_name: string;
  preferred_terms: string[];
  banned_terms: string[];
  talking_points_used: string[];
  emotional_tone: string;
  posts_using_issue: number;
  avg_engagement: number;
}

export interface CandidatePersona {
  candidate_id: string;
  voice_signature: VoiceSignature;
  issue_vocabulary: IssueVocabulary[];
  platform_variations: {
    facebook: PlatformStyle;
    twitter: PlatformStyle;
    instagram: PlatformStyle;
    linkedin: PlatformStyle;
  };
  ml_confidence: number;
  training_posts_count: number;
  last_analyzed: string;
}

export interface PlatformStyle {
  max_length: number;
  hashtag_count: number;
  emoji_adjustment: number;
  tone_modifier: number;
}

// ============================================================================
// DRAFT GENERATION
// ============================================================================

export interface DraftContent {
  draft_id: string;
  content: string;
  platform: string;
  persona_score: number;
  tone_match: number;
  vocabulary_match: number;
  length_appropriate: boolean;
  hashtags: string[];
}

export interface ApprovalRequest {
  approval_request_id: string;
  candidate_id: string;
  event_id: string;
  platform: string;
  drafts: DraftContent[];
  nexus_persona_score: number;
  nexus_trigger_type: TriggerType;
  nexus_confidence: number;
  status: 'pending' | 'approved' | 'edited' | 'rejected' | 'expired';
  selected_option?: number;
  edited_content?: string;
  created_at: string;
  approved_at?: string;
}

// ============================================================================
// DECISIONS
// ============================================================================

export interface NexusDecision {
  decision_id: string;
  brain_trigger_id: string;
  decision: Decision;
  decision_reason: string;
  decision_timestamp: string;
  model_scores: ModelScores;
  composite_score: number;
  target_type?: string;
  target_id?: string;
  candidate_id?: string;
  executed: boolean;
  executed_at?: string;
  actual_cost?: number;
  actual_success?: boolean;
}

// ============================================================================
// COST TRACKING
// ============================================================================

export interface CostTransaction {
  transaction_id: string;
  transaction_timestamp: string;
  level_1_universe: string;
  level_2_candidate_id?: string;
  level_3_campaign_id?: string;
  level_4_channel: string;
  level_5_tier?: string;
  function_code: string;
  cost_type: CostType;
  cost_category?: string;
  quantity: number;
  unit_cost: number;
  total_cost: number;
  reference_type?: string;
  reference_id?: string;
  decision_id?: string;
}

export interface BudgetStatus {
  daily_ai_spend: number;
  daily_ai_budget: number;
  daily_ai_remaining: number;
  daily_ai_pct: number;
  monthly_ai_spend: number;
  monthly_ai_budget: number;
  monthly_ai_remaining: number;
  monthly_ai_pct: number;
  monthly_total_spend: number;
}

// ============================================================================
// BVA (Budget vs Actual vs Variance)
// ============================================================================

export interface BVAMetric {
  metric_code: string;
  metric_name: string;
  metric_category: 'VOLUME' | 'QUALITY' | 'COST' | 'ROI';
  period_start: string;
  period_end: string;
  budget_value: number;
  actual_value: number;
  variance_value: number;
  variance_pct: number;
  status: BVAStatus;
  data_source: string;
  calculated_at: string;
}

// ============================================================================
// LINEAR PROGRAMMING
// ============================================================================

export interface LPConstraint {
  constraint_id: string;
  constraint_name: string;
  constraint_type: 'BUDGET' | 'CAPACITY' | 'TIMING' | 'QUALITY';
  variable: string;
  operator: '<=' | '>=' | '=';
  bound_value: number;
  scope_type: 'GLOBAL' | 'CANDIDATE' | 'CAMPAIGN';
  scope_id?: string;
  period_type: 'DAILY' | 'WEEKLY' | 'MONTHLY';
  is_hard_constraint: boolean;
  penalty_cost: number;
  is_active: boolean;
}

export interface LPRun {
  run_id: string;
  run_type: 'DAILY_ALLOCATION' | 'CAMPAIGN_OPTIMIZATION' | 'RESOURCE_SCHEDULING';
  objective: string;
  input_variables: Record<string, any>;
  active_constraints: string[];
  status: 'PENDING' | 'OPTIMAL' | 'INFEASIBLE' | 'SUBOPTIMAL';
  objective_value?: number;
  solution_variables: Record<string, any>;
  slack_variables: Record<string, any>;
  shadow_prices: Record<string, any>;
  solve_time_ms?: number;
  applied: boolean;
  applied_at?: string;
  created_at: string;
}

export interface DailyAllocation {
  candidate_id: string;
  drafts_allowed: number;
  persona_refresh: boolean;
  budget_allocated: number;
}

// ============================================================================
// ML MODELS
// ============================================================================

export interface MLModel {
  model_id: string;
  model_code: string;
  model_name: string;
  model_type: 'CLASSIFICATION' | 'REGRESSION';
  algorithm: string;
  framework: string;
  version?: string;
  accuracy?: number;
  precision_score?: number;
  recall_score?: number;
  f1_score?: number;
  auc_roc?: number;
  training_samples?: number;
  feature_count?: number;
  feature_names: string[];
  feature_importance: Record<string, number>;
  hyperparameters: Record<string, any>;
  is_active: boolean;
  is_champion: boolean;
  deployed_at?: string;
}

export interface MLPrediction {
  prediction_id: string;
  model_id: string;
  input_features: Record<string, any>;
  prediction_value?: number;
  prediction_class?: string;
  prediction_probabilities?: Record<string, number>;
  confidence?: number;
  target_type?: string;
  target_id?: string;
  candidate_id?: string;
  actual_value?: number;
  actual_class?: string;
  feedback_at?: string;
  prediction_time_ms?: number;
  created_at: string;
}

// ============================================================================
// REPORTING
// ============================================================================

export interface ExecutiveDashboard {
  total_harvest_records: number;
  matched_to_donors: number;
  verified_matches: number;
  donors_enriched: number;
  donors_with_fec: number;
  avg_fec_contribution: number;
  approval_requests_30d: number;
  avg_persona_score: number;
  ml_optimized_posts_30d: number;
  mtd_cost: number;
  mtd_budget: number;
  active_ml_models: number;
  predictions_24h: number;
  go_decisions_7d: number;
  no_go_decisions_7d: number;
  report_generated_at: string;
}

export interface OperationsReport {
  report_date: string;
  records_imported: number;
  records_matched: number;
  matches_verified: number;
  avg_match_confidence: number;
  from_events: number;
  from_social: number;
  from_petitions: number;
  with_facebook: number;
  with_twitter: number;
  with_linkedin: number;
}

export interface CandidatePerformance {
  candidate_id: string;
  candidate_name: string;
  office_sought: string;
  ml_confidence: number;
  training_samples: number;
  approval_requests: number;
  approved: number;
  edited: number;
  rejected: number;
  avg_persona_score: number;
  posts_published: number;
  avg_engagement: number;
  total_cost: number;
}

// ============================================================================
// API RESPONSES
// ============================================================================

export interface NexusApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  metadata?: {
    timestamp: string;
    request_id: string;
    processing_time_ms: number;
  };
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  per_page: number;
  total_pages: number;
}

// ============================================================================
// NEXUS ECOSYSTEM CONFIG
// ============================================================================

export interface NexusConfig {
  ecosystem_code: 'NEXUS';
  ecosystem_name: string;
  version: string;
  status: 'ACTIVE' | 'INACTIVE' | 'MAINTENANCE';
  ai_powered: true;
  ai_provider: 'Anthropic';
  ai_model: string;
  monthly_budget: number;
  daily_budget: number;
  functions: NexusFunction[];
}

export interface NexusFunction {
  function_code: string;
  function_name: string;
  is_ai_powered: boolean;
  cost_type: 'per_call' | 'per_record' | 'per_lookup';
  unit_cost: number;
  monthly_forecast_calls: number;
  monthly_forecast_cost: number;
}
