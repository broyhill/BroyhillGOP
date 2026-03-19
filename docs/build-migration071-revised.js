const { Document, Packer, Paragraph, TextRun, HeadingLevel,
        AlignmentType, BorderStyle, LevelFormat } = require('docx');
const fs = require('fs');

const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, font: "Arial", color: "1B3A5C" },
        paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, font: "Arial", color: "2E5E8E" },
        paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
    ]
  },
  numbering: {
    config: [
      { reference: "bullets",
        levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
    ]
  },
  sections: [{
    properties: {
      page: { size: { width: 12240, height: 15840 },
              margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } }
    },
    children: [
      // TITLE
      new Paragraph({ heading: HeadingLevel.HEADING_1, alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "MIGRATION 071 — IDENTITY ROLLUP", bold: true, size: 36 })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 },
        children: [new TextRun({ text: "REVISED 2026-03-16 | EXECUTE NOW", color: "CC0000", bold: true })] }),
      new Paragraph({ spacing: { after: 200 },
        children: [new TextRun({ text: "Cursor: Run this migration against the Supabase database. The SQL file is at:", bold: true })] }),
      new Paragraph({ spacing: { after: 300 },
        children: [new TextRun({ text: "database/migrations/071_identity_rollup_revised.sql", italics: true, color: "2E5E8E" })] }),

      // SECTION 1: CURRENT STATE
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("1. Current State (Verified Live)")] }),
      bullet("person_master: 7,655,593 rows | 33,363 have golden_record_id (max=129165) | 7,622,230 NULL"),
      bullet("nc_boe_donations_raw: 830,561 rows | 138,128 have golden_record_id | 692,433 NULL"),
      bullet("pending_golden_merges: 0 pending (Step 2 is a no-op)"),
      bullet("name_nickname_map: 326 rows | columns: nickname, canonical, gender, confidence"),
      bullet("employer_sic_master (donor_intelligence schema): 62,100 rows"),
      bullet("person_master has NO employer column — employer data is only in nc_boe_donations_raw"),
      new Paragraph({ spacing: { after: 100 }, children: [] }),

      // SECTION 2: BUGS FIXED
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("2. Bugs Fixed from Original Migration 071")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Bug 1: Employer vs Street Column")] }),
      new Paragraph({ children: [new TextRun("person_master has NO employer column. Original migration compared boe.employer to pm.street (wrong). "), new TextRun({ text: "Fix: ", bold: true }), new TextRun("Strategy B now matches unmatched BOE rows to already-matched BOE rows via employer_normalized + last name + city. No person_master employer join.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Bug 2: 0.4% Golden Record Trap")] }),
      new Paragraph({ children: [new TextRun("Only 33,363 of 7.6M person_master rows had golden_record_id. All matching steps filtered on pm.golden_record_id IS NOT NULL, making 99.6% invisible. "), new TextRun({ text: "Fix: ", bold: true }), new TextRun("Added Step 0 — seeds golden_record_id for all 7,622,230 NULL rows using a sequence starting at 129166.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Bug 3: Wrong Table / Column Names")] }),
      new Paragraph({ children: [new TextRun("Original referenced name_canonical_map with (variant, canonical). Correct table is name_nickname_map with columns (nickname, canonical). "), new TextRun({ text: "Fix: ", bold: true }), new TextRun("Step 6 now uses name_nickname_map.nickname and name_nickname_map.canonical.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("FEC Gap (Not Fixed — Future Migration 072)")] }),
      new Paragraph({ spacing: { after: 200 }, children: [new TextRun("fec_donations (1,093,620 rows) and fec_party_committee_donations (1,734,568 rows) are not covered. A separate Migration 072 is needed.")] }),

      // SECTION 3: MIGRATION STEPS
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("3. Migration Steps")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 0: Seed golden_record_id (CRITICAL)")] }),
      new Paragraph({ children: [new TextRun("Creates sequence starting at 129166, assigns golden_record_id to all 7,622,230 NULL rows in person_master. This makes every person_master row visible to subsequent matching steps. "), new TextRun({ text: "WARNING: This will take several minutes on 7.6M rows.", bold: true, color: "CC0000" })] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 1: SKIP")] }),
      new Paragraph({ children: [new TextRun("golden_record_id column already exists on nc_boe_donations_raw with 138,128 rows populated.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 2: SKIP")] }),
      new Paragraph({ children: [new TextRun("0 pending merges in pending_golden_merges.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 3: Strategy A — Name + ZIP Exact Match")] }),
      new Paragraph({ children: [new TextRun("Matches nc_boe_donations_raw to person_master on: lower(norm_last) = lower(last_name) AND lower(norm_first) = lower(first_name) AND norm_zip5 = zip5. This is the highest-confidence match.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 4: Strategy B — Employer Bridge")] }),
      new Paragraph({ children: [new TextRun("Since person_master has no employer column, this step matches unmatched BOE donations to already-matched BOE donations that share: same employer_normalized + same norm_last + same norm_city. Transitive matching through donation records.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 5: Strategy C — Voter NCID Bridge")] }),
      new Paragraph({ children: [new TextRun("Direct join: boe.voter_ncid = pm.ncvoter_ncid. Leverages voter registration IDs already populated on both tables.")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Step 6: Strategy D — Fuzzy Match (2-Factor Guard Rails)")] }),
      new Paragraph({ children: [new TextRun("Matches remaining BOE donations to person_master using last_name + city, then requires one of: (a) first initial match, OR (b) nickname resolution via name_nickname_map (columns: nickname, canonical). Takes first match per BOE row via ROW_NUMBER().")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Indexes Created")] }),
      bullet("idx_boe_golden_record_id — partial index on golden_record_id IS NOT NULL"),
      bullet("idx_pm_golden_record_id — partial index on golden_record_id IS NOT NULL"),
      bullet("idx_boe_norm_last_first_zip — composite on (norm_last, norm_first, norm_zip5)"),
      bullet("idx_boe_voter_ncid — partial index on voter_ncid IS NOT NULL"),

      // SECTION 4: CONNECTION DETAILS
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("4. Connection Details")] }),
      new Paragraph({ children: [new TextRun({ text: "Database URL: ", bold: true }), new TextRun("postgresql://postgres:BroyhillGOP2026@db.isbgjpnbocdkeslofota.supabase.co:6543/postgres")] }),
      new Paragraph({ spacing: { after: 200 }, children: [new TextRun({ text: "Run command: ", bold: true }), new TextRun('psql "$SUPABASE_DB_URL" -f database/migrations/071_identity_rollup_revised.sql')] }),

      // SECTION 5: VERIFICATION
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("5. Verification Queries")] }),
      new Paragraph({ children: [new TextRun("After the migration completes, run these to verify:")] }),

      code("-- Check person_master seeding\nSELECT count(*) AS total,\n       count(golden_record_id) AS has_grid,\n       count(*) - count(golden_record_id) AS null_grid\n  FROM public.person_master;"),
      code("-- Check BOE donation matching\nSELECT count(*) AS total,\n       count(golden_record_id) AS matched,\n       round(100.0 * count(golden_record_id) / count(*), 1) AS pct\n  FROM public.nc_boe_donations_raw;"),
      code("-- Check top matched donors\nSELECT pm.first_name, pm.last_name, pm.city,\n       count(*) AS donations,\n       sum(boe.amount_numeric) AS total_amount\n  FROM public.nc_boe_donations_raw boe\n  JOIN public.person_master pm ON boe.golden_record_id = pm.golden_record_id\n GROUP BY 1,2,3\n ORDER BY total_amount DESC\n LIMIT 20;"),

      // SECTION 6: ABSOLUTE RULES
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("6. Absolute Rules")] }),
      bullet("Run inside a transaction (BEGIN/COMMIT is in the SQL file)"),
      bullet("Do NOT delete or truncate any table"),
      bullet("Do NOT modify person_master columns other than golden_record_id"),
      bullet("Do NOT modify nc_boe_donations_raw columns other than golden_record_id"),
      bullet("Report match counts after each step via the SELECT statements embedded in the SQL"),
      bullet("If Step 0 fails or times out, do NOT proceed — the rest depends on it"),
    ]
  }]
});

// Helper functions
function bullet(text) {
  return new Paragraph({ numbering: { reference: "bullets", level: 0 },
    children: [new TextRun(text)] });
}

function code(text) {
  return new Paragraph({ spacing: { before: 100, after: 100 },
    border: { top: { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" },
              bottom: { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" },
              left: { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" },
              right: { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" } },
    children: [new TextRun({ text: text, font: "Courier New", size: 18 })] });
}

const outPath = __dirname + '/MIGRATION_071_REVISED_EXECUTE_NOW.docx';
Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(outPath, buffer);
  console.log('Written to ' + outPath + ' (' + buffer.length + ' bytes)');
});
