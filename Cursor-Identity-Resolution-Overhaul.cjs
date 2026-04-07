const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
        ShadingType, PageNumber, PageBreak, LevelFormat } = require('docx');

const border = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 80, bottom: 80, left: 120, right: 120 };

function headerCell(text, width) {
  return new TableCell({
    borders, width: { size: width, type: WidthType.DXA },
    shading: { fill: "1B3A5C", type: ShadingType.CLEAR },
    margins: cellMargins,
    children: [new Paragraph({ children: [new TextRun({ text, bold: true, color: "FFFFFF", font: "Arial", size: 20 })] })]
  });
}
function cell(text, width, opts = {}) {
  return new TableCell({
    borders, width: { size: width, type: WidthType.DXA },
    shading: opts.shade ? { fill: "F2F7FB", type: ShadingType.CLEAR } : undefined,
    margins: cellMargins,
    children: [new Paragraph({
      alignment: opts.right ? AlignmentType.RIGHT : AlignmentType.LEFT,
      children: [new TextRun({ text: String(text), font: "Arial", size: 20, bold: opts.bold || false })]
    })]
  });
}

function makeTable(headers, rows, widths) {
  const tw = widths.reduce((a,b)=>a+b,0);
  return new Table({
    width: { size: tw, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ children: headers.map((h,i) => headerCell(h, widths[i])) }),
      ...rows.map((row, ri) => new TableRow({
        children: row.map((c, ci) => cell(c, widths[ci], { shade: ri % 2 === 1, right: ci > 0 && !isNaN(String(c).replace(/[,%]/g,'')) }))
      }))
    ]
  });
}

function h1(text) { return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 360, after: 200 }, children: [new TextRun({ text, font: "Arial", size: 32, bold: true, color: "1B3A5C" })] }); }
function h2(text) { return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 280, after: 160 }, children: [new TextRun({ text, font: "Arial", size: 26, bold: true, color: "2E75B6" })] }); }
function h3(text) { return new Paragraph({ heading: HeadingLevel.HEADING_3, spacing: { before: 200, after: 120 }, children: [new TextRun({ text, font: "Arial", size: 22, bold: true, color: "404040" })] }); }
function p(text, opts = {}) { return new Paragraph({ spacing: { after: 120 }, children: [new TextRun({ text, font: "Arial", size: 20, ...opts })] }); }
function bold(text) { return p(text, { bold: true }); }
function code(text) { return new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text, font: "Courier New", size: 18, color: "333333" })] }); }

const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 20 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, font: "Arial", color: "1B3A5C" },
        paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, font: "Arial", color: "2E75B6" },
        paragraph: { spacing: { before: 280, after: 160 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 22, bold: true, font: "Arial", color: "404040" },
        paragraph: { spacing: { before: 200, after: 120 }, outlineLevel: 2 } },
    ]
  },
  numbering: {
    config: [
      { reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      { reference: "sub_numbers", levels: [{ level: 0, format: LevelFormat.LOWER_LETTER, text: "%1)", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1080, hanging: 360 } } } }] },
    ]
  },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
      }
    },
    headers: {
      default: new Header({ children: [new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [new TextRun({ text: "BroyhillGOP Identity Resolution Overhaul", font: "Arial", size: 16, color: "888888", italics: true })]
      })] })
    },
    footers: {
      default: new Footer({ children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "Page ", font: "Arial", size: 16, color: "888888" }), new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 16, color: "888888" })]
      })] })
    },
    children: [
      // TITLE
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [
        new TextRun({ text: "IDENTITY RESOLUTION OVERHAUL", font: "Arial", size: 40, bold: true, color: "1B3A5C" })
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 80 }, children: [
        new TextRun({ text: "Unified Donor Record Architecture for BroyhillGOP", font: "Arial", size: 24, color: "666666" })
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 }, children: [
        new TextRun({ text: "Claude \u2192 Cursor Instructions | March 14, 2026", font: "Arial", size: 20, color: "888888" })
      ]}),

      // ========== EXECUTIVE SUMMARY ==========
      h1("1. Executive Summary"),
      p("The BroyhillGOP database currently has TWO disconnected identity systems that must be unified into a single, dependable donor record:"),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 80 },
        children: [new TextRun({ text: "person_master", font: "Arial", size: 20, bold: true }), new TextRun({ text: " (public schema) \u2014 7,655,593 rows. 100% voter-linked (all have NCID + RNCID). ZERO donor linkage: boe_donor_id and fec_contributor_id are both empty for every row. Only 77,200 flagged as is_donor. Only 33,363 linked to golden records.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 80 },
        children: [new TextRun({ text: "core.person_spine", font: "Arial", size: 20, bold: true }), new TextRun({ text: " \u2014 333,374 rows. Donor-centric with 69 columns including donation aggregates. Only 56.9% voter-linked. Fragmented: Art Pope appears as 6 separate records instead of 1.", font: "Arial", size: 20 })]
      }),
      p("Neither system is usable as a unified donor record today. The goal of this overhaul is to merge them into a single authoritative system where every donor has one golden record linked to their voter registration, all donations from NC BOE (830K) and FEC (3.95M across 3 tables), and accurate aggregate metrics."),

      // ========== CURRENT STATE ==========
      h1("2. Current State Diagnosis"),

      h2("2.1 Table Inventory"),
      makeTable(
        ["Table", "Rows", "Schema", "Purpose"],
        [
          ["person_master", "7,655,593", "public", "Voter file copy \u2014 all voters, no donor links"],
          ["core.person_spine", "333,374", "core", "Donor profiles \u2014 fragmented, partially voter-linked"],
          ["person_source_links", "1,846,282", "public", "Maps person_master to source records"],
          ["nc_boe_donations_raw", "830,561", "public", "NC Board of Elections donation transactions"],
          ["fec_party_committee_donations", "2,591,000", "public", "FEC party/committee donations"],
          ["fec_god_contributions", "226,000", "public", "FEC GOD individual contributions"],
          ["fec_donations", "1,130,000", "public", "FEC individual donations (UNMAPPED)"],
          ["donor_contribution_map", "3,102,546", "public", "Maps donations to golden records"],
          ["archive.donor_golden_records", "393,334", "archive", "Old golden records (archived)"],
        ],
        [2200, 1600, 1200, 4360]
      ),

      h2("2.2 Linkage Gaps"),
      makeTable(
        ["Problem", "Impact", "Records Affected"],
        [
          ["person_master has zero donor links", "boe_donor_id=0, fec_contributor_id=0 for ALL 7.66M rows", "7,655,593"],
          ["core.person_spine fragmented", "Art Pope = 6 records, many donors split across multiple spine rows", "333,374"],
          ["General Fund 0% voter_ncid", "70,283 General-type donations have no voter linkage at all", "70,283"],
          ["fec_donations not in contribution map", "1.13M FEC donations completely unmapped to any identity", "1,130,000"],
          ["Individual only 73.8% voter_ncid", "156K Individual donations have no voter link", "155,813"],
          ["person_source_links incomplete", "Only 280K NC BOE linked (of 830K), zero FEC linked", "~550,000 gap"],
          ["Golden records stale", "393K archived, only 33K linked to person_master", "393,334"],
        ],
        [3000, 4360, 2000]
      ),

      h2("2.3 The Art Pope Problem (Proof of Fragmentation)"),
      p("Art Pope (real name James Arthur Pope, voter NCID EH34831) demonstrates the identity resolution failure. In core.person_spine he appears as 6 separate records:"),
      makeTable(
        ["norm_first", "nickname_canonical", "voter_ncid", "txns", "total $"],
        [
          ["JAMES", "JAMES", "EH34831", "134", "$790,984"],
          ["JAMES", "JAMES", "BY154109", "1", "$200"],
          ["JAMES", "JAMES", "DB194751", "7", "$1,400"],
          ["JAMES", "JAMES", "BN196820", "12", "$2,241"],
          ["ARTHUR", "ARTHUR", "(none)", "1", "$2,700"],
          ["ART", "ART", "(none)", "11", "$197,135"],
        ],
        [1600, 2000, 1600, 900, 3260]
      ),
      p("Records 1, 5, and 6 are the SAME person (Art Pope). Records 2-4 are different people named James Pope. The system failed because: (a) ART, ARTHUR, and JAMES A. POPE were never linked via nickname/canonical_first resolution, (b) the two unlinked records have no voter_ncid to match on, and (c) no fuzzy matching on address/employer was attempted."),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== ARCHITECTURE ==========
      h1("3. Target Architecture"),
      p("After the overhaul, the unified identity system should have this structure:"),
      bold("core.person_spine = THE authoritative identity table (DONOR GOLDEN RECORDS)"),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "One row per real person who has ever donated (NC BOE or FEC)", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "voter_ncid and voter_rncid populated where match exists (target: >80%)", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "Aggregate donation metrics (total_contributed, contribution_count, etc.) computed from ALL sources", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "merged_from[] array tracks which spine records were collapsed", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 120 }, children: [new TextRun({ text: "Linked to person_master via voter_ncid for voter demographics/scores", font: "Arial", size: 20 })] }),

      bold("person_master = voter universe (unchanged, but BRIDGED to spine)"),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "7.66M voter records remain as-is", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "boe_donor_id and fec_contributor_id columns populated where spine match exists", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 120 }, children: [new TextRun({ text: "is_donor flag set true for all matched donors", font: "Arial", size: 20 })] }),

      bold("donor_contribution_map = ALL donations linked to spine person_id"),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "NC_BOE: 830K (currently 683K \u2014 add 147K General Fund + missing Individual)", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "fec_party: 2.2M (already mapped)", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "fec_god: 197K (already mapped)", font: "Arial", size: 20 })] }),
      new Paragraph({ numbering: { reference: "bullets", level: 0 }, spacing: { after: 60 }, children: [new TextRun({ text: "fec_donations: 1.13M (currently UNMAPPED \u2014 must add)", font: "Arial", size: 20 })] }),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 1: DB HEALTH ==========
      h1("4. Phase 0: Database Health (Do First)"),
      p("Before any identity work, clean up the database to reclaim space and improve performance."),

      h2("4.1 VACUUM Bloated Tables"),
      code("VACUUM ANALYZE nc_boe_donations_raw;   -- 60K dead tuples, 7.2%"),
      code("VACUUM ANALYZE ncsbe_candidates;        -- 4.5K dead tuples, 14.7%"),
      code("VACUUM ANALYZE staging_committee_ref;   -- 141 dead tuples, 21.3%"),
      code("VACUUM ANALYZE boe_committee_candidate_map;  -- 114 dead, 11%"),
      code("VACUUM ANALYZE candidate_profiles;      -- 123 dead, 5.3%"),

      h2("4.2 Drop Unused Indexes (5.1 GB recoverable)"),
      p("93 indexes with zero scans. Drop the 6 largest first to reclaim ~1.8 GB immediately:"),
      code("DROP INDEX IF EXISTS idx_nc_voters_last_first_city;   -- 357 MB"),
      code("DROP INDEX IF EXISTS idx_nc_voters_last_first_zip;    -- 334 MB"),
      code("DROP INDEX IF EXISTS idx_pm_name_zip;                 -- 294 MB"),
      code("DROP INDEX IF EXISTS idx_dt_last_first_zip;           -- 294 MB"),
      code("DROP INDEX IF EXISTS idx_datatrust_full_name;         -- 289 MB"),
      code("DROP INDEX IF EXISTS idx_pm_datatrust;                -- 230 MB"),
      p("IMPORTANT: Before dropping, verify these are truly unused. Run:"),
      code("SELECT indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid))"),
      code("FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;"),
      p("Only drop indexes with idx_scan = 0 since last stats reset. Some may be needed for the identity resolution work below."),

      h2("4.3 Do NOT touch empty ecosystem tables"),
      p("The 553 empty tables (e17_*, campaign_*, volunteer_*, etc.) are intentional platform scaffolding. Total footprint is ~15 MB. Leave them."),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 1: SPINE DEDUP ==========
      h1("5. Phase 1: Fix core.person_spine Fragmentation"),
      p("The core problem: multiple spine records represent the same real person because names were not resolved through nicknames, canonical forms, or fuzzy matching. This phase merges duplicates WITHIN the existing 333K spine records."),

      h2("5.1 Build Candidate Match Pairs"),
      p("Create a staging table of potential merges using multiple match strategies:"),

      h3("Strategy A: Nickname/Canonical Resolution"),
      p("Use fn_normalize_donor_name to get canonical_first for all spine records. Then match on canonical_first + norm_last + zip5:"),
      code("-- Example: ART POPE, ARTHUR POPE, JAMES A POPE all resolve to canonical_first = ARTHUR"),
      code("CREATE TABLE staging.spine_merge_candidates AS"),
      code("SELECT a.person_id as keep_id, b.person_id as merge_id,"),
      code("       'nickname' as match_method, 0.9 as confidence"),
      code("FROM core.person_spine a JOIN core.person_spine b"),
      code("  ON a.norm_last = b.norm_last"),
      code("  AND a.zip5 = b.zip5 AND a.zip5 IS NOT NULL"),
      code("  AND fn_normalize_donor_name(a.first_name || ' ' || a.last_name).canonical_first_name"),
      code("    = fn_normalize_donor_name(b.first_name || ' ' || b.last_name).canonical_first_name"),
      code("WHERE a.person_id < b.person_id;  -- avoid self-joins and duplicates"),
      p("Keep the record with the most donation history (highest contribution_count) as the survivor."),

      h3("Strategy B: Same Voter NCID"),
      p("If two spine records have the same voter_ncid (and it is not null), they are the same person:"),
      code("INSERT INTO staging.spine_merge_candidates"),
      code("SELECT a.person_id, b.person_id, 'voter_ncid', 1.0"),
      code("FROM core.person_spine a JOIN core.person_spine b"),
      code("  ON a.voter_ncid = b.voter_ncid AND a.voter_ncid IS NOT NULL"),
      code("WHERE a.person_id < b.person_id;"),

      h3("Strategy C: Last + First Initial + Employer"),
      p("For records without voter_ncid, match on employer when first initial matches:"),
      code("INSERT INTO staging.spine_merge_candidates"),
      code("SELECT a.person_id, b.person_id, 'employer', 0.75"),
      code("FROM core.person_spine a JOIN core.person_spine b"),
      code("  ON a.norm_last = b.norm_last"),
      code("  AND left(a.norm_first,1) = left(b.norm_first,1)"),
      code("  AND a.employer = b.employer AND a.employer IS NOT NULL AND a.employer != ''"),
      code("  AND a.city = b.city"),
      code("WHERE a.person_id < b.person_id AND a.voter_ncid IS NULL AND b.voter_ncid IS NULL;"),

      h2("5.2 Union-Find Clustering"),
      p("Apply transitive closure to merge candidates. If A matches B and B matches C, all three become one cluster:"),
      code("-- Use a recursive CTE or PL/pgSQL union-find to build clusters"),
      code("-- Assign each cluster a canonical person_id (the one with highest contribution_count)"),
      code("-- Store in staging.spine_clusters(person_id, cluster_id, is_canonical)"),

      h2("5.3 Execute Merges"),
      p("For each cluster, pick the canonical record and merge all others into it:"),
      code("-- 1. Aggregate donation metrics from all cluster members"),
      code("-- 2. Union all name variations into merged_from[]"),
      code("-- 3. Copy best voter_ncid (prefer the one with most donations)"),
      code("-- 4. Set is_active = false on non-canonical records"),
      code("-- 5. Update donor_contribution_map to point all donations to canonical person_id"),
      p("CRITICAL: Never delete spine records. Mark merged records as is_active = false and populate merged_from on the survivor. This preserves audit trail."),

      h2("5.4 Validation"),
      code("-- Art Pope should collapse to 1 canonical record:"),
      code("SELECT person_id, norm_first, voter_ncid, contribution_count, total_contributed, merged_from"),
      code("FROM core.person_spine WHERE norm_last = 'POPE' AND is_active = true"),
      code("  AND (norm_first IN ('ART','JAMES','ARTHUR') OR nickname_canonical IN ('ARTHUR','ART'));"),
      code("-- Expected: 1 row with voter_ncid=EH34831, ~156 txns, ~$990K+, merged_from has 2 IDs"),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 2: VOTER MATCHING ==========
      h1("6. Phase 2: Voter-Link the Unlinked"),
      p("After dedup, ~143K spine records still lack voter_ncid. Match them to nc_voters using progressive strategies:"),

      h2("6.1 Create nc_voters Indexes (CRITICAL \u2014 currently ZERO indexes)"),
      code("CREATE INDEX CONCURRENTLY idx_nv_ncid ON nc_voters(ncid);"),
      code("CREATE INDEX CONCURRENTLY idx_nv_last_first ON nc_voters(last_name, first_name);"),
      code("CREATE INDEX CONCURRENTLY idx_nv_last_zip ON nc_voters(last_name, zip_code);"),
      code("CREATE INDEX CONCURRENTLY idx_nv_last_city ON nc_voters(last_name, county_desc);"),
      p("Without these, every voter match query does a full scan of 9.45M rows."),

      h2("6.2 Match Strategy (in priority order)"),

      h3("Pass 1: Exact last + first + zip5 (confidence: 0.95)"),
      code("UPDATE core.person_spine s SET voter_ncid = v.ncid, voter_rncid = ("),
      code("  SELECT datatrust_rncid FROM person_master WHERE ncvoter_ncid = v.ncid LIMIT 1)"),
      code("FROM nc_voters v WHERE s.voter_ncid IS NULL"),
      code("  AND s.norm_last = upper(v.last_name) AND s.norm_first = upper(v.first_name)"),
      code("  AND s.zip5 = v.zip_code AND v.status_cd = 'A';"),

      h3("Pass 2: Canonical first + last + zip5 (confidence: 0.85)"),
      code("-- Use fn_normalize_donor_name canonical_first_name to match"),
      code("-- e.g., ART POPE matches ARTHUR POPE in voter file"),

      h3("Pass 3: Last + first initial + zip5 + party=REP (confidence: 0.7)"),
      code("-- For remaining unmatched, use first initial + same zip + Republican registration"),

      h2("6.3 Link General Fund Donors"),
      p("The 70,283 General-type donations have 0% voter_ncid. These are individual donors to party general accounts. First, create spine records for them (many will match existing spine records). Then voter-match using the strategies above."),
      code("-- Insert General-type donors not already in spine:"),
      code("INSERT INTO core.person_spine (last_name, first_name, norm_last, norm_first, ...)"),
      code("SELECT DISTINCT norm_last, norm_first, canonical_first, city, state, zip5"),
      code("FROM nc_boe_donations_raw WHERE transaction_type = 'General'"),
      code("  AND NOT EXISTS (SELECT 1 FROM core.person_spine s"),
      code("    WHERE s.norm_last = r.norm_last AND s.norm_first = r.norm_first AND s.zip5 = r.zip5);"),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 3: FEC MAPPING ==========
      h1("7. Phase 3: Map fec_donations to Identity System"),
      p("fec_donations (1.13M rows) is completely unmapped. It has a contributor_id column but no person_id or voter linkage."),

      h2("7.1 Assess fec_donations Schema"),
      code("-- Check what identity columns exist"),
      code("SELECT column_name FROM information_schema.columns"),
      code("WHERE table_name = 'fec_donations' AND column_name ILIKE ANY(ARRAY['%name%','%state%','%zip%','%city%','%employer%','%occupation%']);"),
      p("Use contributor name + state + zip to match against core.person_spine or create new spine records."),

      h2("7.2 Create Spine Records for FEC-Only Donors"),
      code("-- For FEC donors with no NC address match, they may be out-of-state donors"),
      code("-- to NC committees. Create spine records but mark source = 'FEC'"),
      code("-- These will NOT have voter_ncid (correct \u2014 they may not be NC voters)"),

      h2("7.3 Add to donor_contribution_map"),
      code("INSERT INTO donor_contribution_map (source_id, source_system, golden_record_id,"),
      code("  contribution_receipt_amount, contribution_receipt_date, committee_id)"),
      code("SELECT d.id, 'fec_donations', s.person_id, d.amount, d.date, d.committee_id"),
      code("FROM fec_donations d JOIN core.person_spine s ON [match logic];"),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 4: BRIDGE ==========
      h1("8. Phase 4: Bridge person_master \u2190\u2192 core.person_spine"),
      p("After Phases 1-3, core.person_spine is clean and all donations are mapped. Now bridge it to person_master so the voter universe knows who is a donor."),

      h2("8.1 Update person_master Donor Links"),
      code("UPDATE person_master pm SET"),
      code("  boe_donor_id = s.person_id::text,"),
      code("  is_donor = true"),
      code("FROM core.person_spine s"),
      code("WHERE s.voter_ncid = pm.ncvoter_ncid AND s.voter_ncid IS NOT NULL AND s.is_active = true;"),

      h2("8.2 Update person_source_links"),
      code("-- Add entries for all newly linked spine records"),
      code("INSERT INTO person_source_links (person_id, source_table, source_key, match_method, match_confidence)"),
      code("SELECT pm.person_id, 'core.person_spine', s.person_id::text, 'voter_ncid_exact', 0.95"),
      code("FROM person_master pm JOIN core.person_spine s ON s.voter_ncid = pm.ncvoter_ncid"),
      code("WHERE s.is_active = true AND NOT EXISTS ("),
      code("  SELECT 1 FROM person_source_links psl"),
      code("  WHERE psl.person_id = pm.person_id AND psl.source_table = 'core.person_spine');"),

      h2("8.3 Rebuild Aggregate Metrics on Spine"),
      code("-- Recompute all donation aggregates from donor_contribution_map"),
      code("UPDATE core.person_spine s SET"),
      code("  total_contributed = agg.total, contribution_count = agg.cnt,"),
      code("  first_contribution = agg.first_dt, last_contribution = agg.last_dt,"),
      code("  max_single_gift = agg.max_gift, avg_gift = agg.avg_gift"),
      code("FROM (SELECT golden_record_id, SUM(contribution_receipt_amount) as total,"),
      code("  COUNT(*) as cnt, MIN(contribution_receipt_date) as first_dt,"),
      code("  MAX(contribution_receipt_date) as last_dt, MAX(contribution_receipt_amount) as max_gift,"),
      code("  AVG(contribution_receipt_amount) as avg_gift"),
      code("  FROM donor_contribution_map GROUP BY golden_record_id) agg"),
      code("WHERE agg.golden_record_id = s.person_id;"),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== PHASE 5: NC BOE GAP CLOSE ==========
      h1("9. Phase 5: Close NC BOE Gaps"),

      h2("9.1 Add Missing NC BOE Rows to Contribution Map"),
      p("Currently 683K of 830K NC BOE donations are in donor_contribution_map. The gap is 147K rows, mostly from the General Fund ingestion (70K) plus ~77K Individual rows that were never mapped."),
      code("-- Find unmapped NC BOE donations"),
      code("SELECT count(*) FROM nc_boe_donations_raw r"),
      code("WHERE NOT EXISTS (SELECT 1 FROM donor_contribution_map m"),
      code("  WHERE m.source_system = 'NC_BOE' AND m.source_id = r.id::text);"),
      code(""),
      code("-- Map them via spine match on norm_last + norm_first + zip5"),
      code("-- or via voter_ncid where available"),

      h2("9.2 Voter-Match General Fund Donors"),
      p("Run the voter matching passes from Phase 2 specifically targeting General-type donations where voter_ncid is NULL. With fn_normalize_donor_name canonical resolution, expect to match 60-70% to the voter file."),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== VALIDATION ==========
      h1("10. Validation Queries"),
      p("Run ALL of these after completing each phase. Every query must pass."),

      h2("10.1 Art Pope Golden Record"),
      code("SELECT person_id, norm_last, norm_first, voter_ncid, contribution_count,"),
      code("  total_contributed, merged_from, is_active"),
      code("FROM core.person_spine WHERE norm_last = 'POPE'"),
      code("  AND voter_ncid = 'EH34831' AND is_active = true;"),
      code("-- Expected: 1 row, ~156 txns, ~$990K+"),

      h2("10.2 No Orphaned Donations"),
      code("SELECT source_system, count(*) FROM donor_contribution_map"),
      code("WHERE golden_record_id NOT IN (SELECT person_id FROM core.person_spine WHERE is_active = true)"),
      code("GROUP BY source_system;"),
      code("-- Expected: 0 rows (all donations point to active spine records)"),

      h2("10.3 Full Coverage"),
      code("SELECT 'nc_boe' as src, count(*) as total,"),
      code("  (SELECT count(*) FROM donor_contribution_map WHERE source_system = 'NC_BOE') as mapped"),
      code("FROM nc_boe_donations_raw WHERE transaction_type IN ('Individual','General')"),
      code("UNION ALL"),
      code("SELECT 'fec_donations', count(*),"),
      code("  (SELECT count(*) FROM donor_contribution_map WHERE source_system = 'fec_donations')"),
      code("FROM fec_donations;"),
      code("-- Expected: mapped should be >= 95% of total for each source"),

      h2("10.4 person_master Bridge"),
      code("SELECT count(*) as total_donors, count(boe_donor_id) as with_boe_link"),
      code("FROM person_master WHERE is_donor = true;"),
      code("-- Expected: all donors have boe_donor_id or fec_contributor_id populated"),

      h2("10.5 Spine Linkage Rate"),
      code("SELECT count(*) as total_active,"),
      code("  count(voter_ncid) as voter_linked,"),
      code("  round(100.0*count(voter_ncid)/count(*),1) as pct"),
      code("FROM core.person_spine WHERE is_active = true;"),
      code("-- Target: >80% (up from current 56.9%)"),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== EXECUTION ORDER ==========
      h1("11. Execution Order & Dependencies"),
      makeTable(
        ["Phase", "Task", "Depends On", "Est. Duration"],
        [
          ["0", "VACUUM + drop unused indexes", "Nothing", "10 min"],
          ["0", "Create nc_voters indexes", "Nothing", "20 min (CONCURRENTLY)"],
          ["1", "Build spine merge candidates", "Phase 0", "15 min"],
          ["1", "Union-find clustering", "Merge candidates", "10 min"],
          ["1", "Execute merges", "Clustering", "20 min"],
          ["2", "Voter-match unlinked spine records (3 passes)", "Phase 1", "30 min"],
          ["2", "Create spine records for General Fund donors", "Phase 1", "15 min"],
          ["3", "Map fec_donations to spine", "Phase 1", "30 min"],
          ["3", "Add to donor_contribution_map", "fec_donations mapped", "10 min"],
          ["4", "Bridge person_master to spine", "Phases 1-3", "15 min"],
          ["4", "Update person_source_links", "Bridge", "10 min"],
          ["5", "Close NC BOE contribution map gaps", "Phase 2", "15 min"],
          ["5", "Rebuild aggregate metrics", "All above", "20 min"],
          ["V", "Run ALL validation queries", "Phase 5", "5 min"],
        ],
        [800, 4360, 2400, 1800]
      ),

      new Paragraph({ children: [new PageBreak()] }),

      // ========== CRITICAL RULES ==========
      h1("12. Critical Rules"),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "NEVER delete donations. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "One person giving 10 times = 10 rows. That is correct.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "NEVER delete spine records. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "Mark merged records as is_active = false. Populate merged_from on the survivor.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "Use fn_normalize_donor_name for all name parsing. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "It lives in the database and returns canonical_first_name, last_name, etc. Do NOT use pipeline.parse_ncboe_name for identity resolution.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "Cluster FIRST, roll up SECOND. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "Build all merge pairs, run union-find, THEN execute merges. Do not merge pairwise.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "General-type donations are from INDIVIDUAL PERSONS, not organizations. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "We already fixed 70,283 rows with fn_normalize_donor_name. donor_type = 'individual', is_organization = false. Exception: 5 records (ELECTAFILE x3, WALMART, SRH) are orgs.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "SELECT COUNT(*) after every DDL change. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "Verify row counts before and after. No silent data loss.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "Ignore dedup_* tables. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "They were built on a false premise that donations are duplicates.", font: "Arial", size: 20 })]
      }),
      new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 100 },
        children: [new TextRun({ text: "Update SESSION-STATE.md after every database change. ", font: "Arial", size: 20, bold: true }), new TextRun({ text: "Document what was done, row counts, and what is next.", font: "Arial", size: 20 })]
      }),

      new Paragraph({ spacing: { before: 400 }, children: [
        new TextRun({ text: "Document generated by Claude (Cowork) for Cursor execution \u2014 March 14, 2026", font: "Arial", size: 18, color: "888888", italics: true })
      ]}),
    ]
  }]
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync("/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/Cursor-Identity-Resolution-Overhaul.docx", buffer);
  console.log("SUCCESS: Written to Cursor-Identity-Resolution-Overhaul.docx (" + buffer.length + " bytes)");
});
