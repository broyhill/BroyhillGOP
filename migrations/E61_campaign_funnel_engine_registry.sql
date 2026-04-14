-- E61 Campaign Funnel Engine — Registry Entry
-- Run against Supabase: INSERT into framework_document_registry
-- Applied: 2026-04-13, id=60, status=cataloged

INSERT INTO framework_document_registry (
  document_name, file_name, category, subcategory, description,
  key_deliverables, database_objects_created, integration_status,
  priority, created_date, document_date, location, ecosystem_codes,
  ecosystems_text, notes
) VALUES (
  'E61_CAMPAIGN_FUNNEL_ENGINE',
  'ECOSYSTEM_REPORTS/E61_CAMPAIGN_FUNNEL_ENGINE.docx',
  'ecosystem_blueprints',
  'fundraising',
  'Campaign funnel engine — two objectives: maximize donations to candidate campaigns and recruit passionate volunteers for deployment',
  ARRAY[
    'DONOR TRACK: visitor → issue trigger → donation ask → WinRed → E01 updated',
    'VOLUNTEER TRACK: visitor → passion scoring → commitment → E38 deployment → E39 P2P fundraising',
    'candidate_funnel_config — per-candidate pixel key, WinRed URL, fundraising and volunteer goals',
    'funnel_donors — donation conversions with trigger issue, amount asked vs given, news hook shown',
    'funnel_volunteers — volunteer signups with passion score, issue affinity, deployment status, P2P raised',
    'funnel_issue_performance — revenue per impression per issue per track — primary optimization metric',
    'P2P force multiplier pipeline: passionate volunteer → peer fundraiser → compounds donations'
  ],
  ARRAY[
    'candidate_funnel_config',
    'funnel_sessions',
    'funnel_donors',
    'funnel_volunteers',
    'funnel_issue_performance',
    'funnel_brain_requests'
  ],
  'cataloged',
  'high',
  '2026-04-13',
  '2026-04-13',
  'GitHub: ECOSYSTEM_REPORTS/E61_CAMPAIGN_FUNNEL_ENGINE.docx',
  ARRAY['E61'],
  'E61 Campaign Funnel Engine: Maximize donations + recruit passionate volunteers',
  'BLOCKED pending Golden Record Stages 0-5. Integrates with E20 Brain, E60 Poll Intel, E42 News, E01 Donor Intel, E56 Deanonymization, E38 Field Ops, E39 P2P Fundraising.'
);
