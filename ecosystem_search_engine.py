#!/usr/bin/env python3
"""
BroyhillGOP Advanced Ecosystem Search Engine
=============================================
Searches all MD docs for ecosystem references (E00-E57),
extracts context, cross-references planned vs built,
and identifies missing/planned components.

Solves limitations of basic search:
- Case-sensitive ecosystem ID matching
- Filters out footnote/URL noise
- Extracts meaningful context windows
- Deduplicates across files
- Structured JSON + MD output
- Component-level detection (harvesting, deanonymization, etc.)
"""

import os
import re
import json
import sys
from collections import defaultdict
from pathlib import Path

# ============================================================
# CONFIGURATION
# ============================================================

SEARCH_DIRS = [
    "/Users/Broyhill/Downloads",
    "/Users/Broyhill/Documents",
    "/Users/Broyhill/Desktop/BroyhillGOP-CURSOR",
]

OUTPUT_DIR = "/Users/Broyhill/Desktop"

# Known ecosystem mapping (E00-E57 + E58)
ECOSYSTEM_NAMES = {
    "E00": "DataHub / Master Database",
    "E01": "Donor Intelligence Engine",
    "E02": "Donation Processing",
    "E03": "Candidate Profiles / Marketing Automation",
    "E04": "Activist Network",
    "E05": "Volunteer Management",
    "E06": "Analytics Engine",
    "E07": "Issue Tracking",
    "E08": "Communications Library",
    "E09": "Content Creation AI",
    "E10": "Compliance Manager",
    "E11": "Budget Management / Training LMS",
    "E12": "Campaign Operations",
    "E13": "AI Hub",
    "E14": "Print Production",
    "E15": "Contact Directory",
    "E16": "TV/Radio AI + Voice Synthesis",
    "E17": "RVM (Ringless Voicemail)",
    "E18": "VDP / Print Advertising",
    "E19": "Social Media Manager / Personalization",
    "E20": "Intelligence Brain",
    "E21": "ML Clustering",
    "E22": "A/B Testing Engine (Thompson Sampling)",
    "E23": "Creative Asset / 3D Engine",
    "E24": "Candidate Portal",
    "E25": "Donor Portal",
    "E26": "Volunteer Portal",
    "E27": "Realtime Dashboard",
    "E28": "Financial Dashboard",
    "E29": "Analytics Dashboard",
    "E30": "Email Engine",
    "E31": "SMS/MMS Engine",
    "E32": "Phone Banking",
    "E33": "Direct Mail",
    "E34": "Events",
    "E35": "Interactive Comm Hub / Auto-Response",
    "E36": "Messenger Integration",
    "E37": "Event Management",
    "E38": "Volunteer Coordination",
    "E39": "P2P Fundraising",
    "E40": "Automation Control Panel",
    "E41": "Campaign Builder",
    "E42": "News Intelligence",
    "E43": "Advocacy Tools",
    "E44": "Vendor Compliance / Social Intelligence",
    "E45": "Video Studio",
    "E46": "Broadcast Hub",
    "E47": "AI Script Generator / Unified Voice",
    "E48": "Communication DNA",
    "E49": "Interview System / GPU Orchestrator",
    "E50": "GPU Orchestrator",
    "E51": "Nexus Dashboard",
    "E52": "Contact Intelligence Engine",
    "E53": "Document Generation",
    "E54": "Calendar/Scheduling",
    "E55": "API Gateway",
    "E56": "Visitor Deanonymization",
    "E57": "Messaging Center",
    "E58": "Business Model / Candidate Network Data Acquisition",
}

# Components/features to detect (planned but possibly never built)
COMPONENT_PATTERNS = {
    "facebook_group_infiltration": r"facebook\s+group.*?infiltrat|140\s+facebook\s+groups?|facebook\s+group\s+harvest",
    "social_harvesting_inbound": r"inbound\s+harvest|social\s+harvest|social\s+media\s+harvest|scraping\s+social",
    "heat_map": r"heat\s*map|issue\s+heat|geographic\s+heat|real.?time\s+issue\s+intelligence",
    "deanonymization": r"deanonymiz|de-anonymiz|visitor\s+identif|pixel\s+track|website\s+visitor",
    "newsletter_engine": r"newsletter\s+engine|newsletter\s+generat|automated\s+newsletter",
    "voice_cloning": r"voice\s+clon|ai\s+voice|voice\s+synthe|eleven\s*labs|voice\s+match",
    "communication_dna": r"communication\s+dna|comm\.?\s*dna|tone\s+match|psychological\s+profile\s+match",
    "variable_data_print": r"variable\s+data\s+print|vdp|every\s+piece\s+unique",
    "thompson_sampling": r"thompson\s+sampl|multi.?armed\s+bandit|100.?way\s+test",
    "prospecting_agent": r"prospect.*?agent|ai\s+agent\s+prospect|autonomous\s+prospect",
    "nexus_dashboard": r"nexus\s+dashboard|nexus\s+intelligence|fomo\s+trigger|addicting\s+dashboard",
    "funnel_orchestration": r"funnel\s+orchestrat|1080\s+concurrent|multi.?dimensional\s+funnel|funnel\s+engine",
    "linkedin_monitoring": r"linkedin\s+monitor|pdl|proxycurl|linkedin\s+scrape",
    "opposition_research": r"opposition\s+research|oppo\s+research|opponent\s+track",
    "candidate_intake": r"candidate\s+intake|smart\s+intake|onboard.*?candidate|candidate\s+onboard",
    "make_n8n_integration": r"make\.com|n8n|zapier\s+integrat|automation\s+workflow\s+tool",
    "predictive_modeling": r"predictive\s+model|propensity\s+scor|churn\s+predict|donor\s+likelihood",
    "ai_content_factory": r"content\s+factory|swipe\s+approv|political\s+content\s+factory",
    "gpu_orchestration": r"gpu\s+orchestrat|runpod|h100|omniavatar|gpu\s+cluster",
    "household_grouping": r"household\s+group|household\s+id|household\s+match|family\s+unit",
}

# ============================================================
# SEARCH ENGINE
# ============================================================

class EcosystemSearchEngine:
    def __init__(self):
        self.results = {
            "ecosystem_refs": defaultdict(lambda: defaultdict(list)),  # {eco_id: {file: [contexts]}}
            "component_refs": defaultdict(lambda: defaultdict(list)),  # {component: {file: [contexts]}}
            "files_scanned": 0,
            "files_with_hits": 0,
            "total_ecosystem_hits": 0,
            "total_component_hits": 0,
            "errors": [],
        }

    def is_noise(self, line, match_pos):
        """Filter out footnote/URL noise that isn't a real ecosystem ref."""
        # Skip if inside a URL
        url_pattern = r'https?://[^\s\)]*'
        for m in re.finditer(url_pattern, line):
            if m.start() <= match_pos <= m.end():
                return True
        # Skip if it's a footnote reference like [^3_13] or e86 in a citation
        footnote = r'\[\^[\d_]+\]'
        for m in re.finditer(footnote, line):
            if m.start() <= match_pos <= m.end():
                return True
        # Skip standalone lowercase e+digits in citations
        if re.match(r'^e\d+$', line.strip()):
            return True
        return False

    def extract_context(self, lines, line_idx, window=3):
        """Extract context window around a match."""
        start = max(0, line_idx - window)
        end = min(len(lines), line_idx + window + 1)
        ctx_lines = lines[start:end]
        ctx = "\n".join(ctx_lines).strip()
        if len(ctx) > 500:
            ctx = ctx[:500] + "..."
        return ctx

    def scan_file(self, filepath):
        """Scan a single file for ecosystem and component references."""
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except Exception as e:
            self.results["errors"].append(f"{filepath}: {e}")
            return

        lines = content.split('\n')
        self.results["files_scanned"] += 1
        file_had_hits = False
        rel_path = filepath  # Keep full path for now

        # --- Ecosystem ID search (case-insensitive E00-E58) ---
        eco_pattern = r'\bE(\d{2})\b'
        for i, line in enumerate(lines):
            for m in re.finditer(eco_pattern, line):
                eco_num = m.group(1)
                eco_id = f"E{eco_num}"
                if eco_id not in ECOSYSTEM_NAMES:
                    continue
                if self.is_noise(line, m.start()):
                    continue
                ctx = self.extract_context(lines, i, window=2)
                self.results["ecosystem_refs"][eco_id][rel_path].append({
                    "line": i + 1,
                    "match": line.strip()[:200],
                    "context": ctx,
                })
                self.results["total_ecosystem_hits"] += 1
                file_had_hits = True

        # --- Component/feature search ---
        content_lower = content.lower()
        for comp_name, pattern in COMPONENT_PATTERNS.items():
            for m in re.finditer(pattern, content_lower):
                # Find which line this is on
                line_start = content_lower.count('\n', 0, m.start())
                ctx = self.extract_context(lines, line_start, window=2)
                self.results["component_refs"][comp_name][rel_path].append({
                    "line": line_start + 1,
                    "match": lines[line_start].strip()[:200] if line_start < len(lines) else "",
                    "context": ctx,
                })
                self.results["total_component_hits"] += 1
                file_had_hits = True

        if file_had_hits:
            self.results["files_with_hits"] += 1

    def scan_directory(self, dirpath):
        """Recursively scan a directory for .md files."""
        dirpath = Path(dirpath)
        if not dirpath.exists():
            self.results["errors"].append(f"Directory not found: {dirpath}")
            return
        md_files = list(dirpath.rglob("*.md"))
        print(f"  Found {len(md_files)} .md files in {dirpath}")
        for fp in md_files:
            self.scan_file(str(fp))

    def run(self):
        """Run the full search across all configured directories."""
        print("=" * 70)
        print("BroyhillGOP Advanced Ecosystem Search Engine")
        print("=" * 70)
        for d in SEARCH_DIRS:
            print(f"\nScanning: {d}")
            self.scan_directory(d)
        print(f"\n{'=' * 70}")
        print(f"SCAN COMPLETE")
        print(f"  Files scanned: {self.results['files_scanned']}")
        print(f"  Files with hits: {self.results['files_with_hits']}")
        print(f"  Ecosystem hits: {self.results['total_ecosystem_hits']}")
        print(f"  Component hits: {self.results['total_component_hits']}")
        print(f"  Errors: {len(self.results['errors'])}")
        print(f"{'=' * 70}")

    def generate_cross_reference(self):
        """Build the planned-vs-built cross-reference."""
        # Cursor ecosystem files that exist
        cursor_dir = Path("/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/ecosystems")
        built_files = {}
        if cursor_dir.exists():
            for f in cursor_dir.iterdir():
                if f.name.startswith("ecosystem_") and f.suffix == ".py":
                    # Extract eco number
                    m = re.search(r'ecosystem_(\d+)', f.name)
                    if m:
                        eco_id = f"E{int(m.group(1)):02d}"
                        if eco_id not in built_files:
                            built_files[eco_id] = []
                        built_files[eco_id].append(f.name)

        cross_ref = {}
        for eco_id, eco_name in sorted(ECOSYSTEM_NAMES.items()):
            num_doc_refs = sum(len(contexts) for contexts in self.results["ecosystem_refs"].get(eco_id, {}).values())
            num_files_mentioning = len(self.results["ecosystem_refs"].get(eco_id, {}))
            has_code = eco_id in built_files
            code_files = built_files.get(eco_id, [])

            cross_ref[eco_id] = {
                "name": eco_name,
                "has_code": has_code,
                "code_files": code_files,
                "doc_references": num_doc_refs,
                "files_mentioning": num_files_mentioning,
                "status": "BUILT" if has_code else ("PLANNED" if num_doc_refs > 0 else "UNKNOWN"),
                "top_files": list(self.results["ecosystem_refs"].get(eco_id, {}).keys())[:5],
            }
        return cross_ref

    def generate_component_report(self):
        """Report on planned components/features found across docs."""
        report = {}
        for comp_name, file_refs in self.results["component_refs"].items():
            total_hits = sum(len(ctxs) for ctxs in file_refs.values())
            report[comp_name] = {
                "total_hits": total_hits,
                "files_found_in": len(file_refs),
                "file_list": list(file_refs.keys())[:10],
                "sample_contexts": [],
            }
            # Grab up to 3 sample contexts
            count = 0
            for fp, ctxs in file_refs.items():
                for ctx in ctxs:
                    if count < 3:
                        report[comp_name]["sample_contexts"].append({
                            "file": os.path.basename(fp),
                            "line": ctx["line"],
                            "context": ctx["context"][:300],
                        })
                        count += 1
        return report

    def write_json_output(self, cross_ref, comp_report):
        """Write structured JSON output."""
        output = {
            "scan_summary": {
                "files_scanned": self.results["files_scanned"],
                "files_with_hits": self.results["files_with_hits"],
                "total_ecosystem_hits": self.results["total_ecosystem_hits"],
                "total_component_hits": self.results["total_component_hits"],
                "errors_count": len(self.results["errors"]),
            },
            "ecosystem_cross_reference": cross_ref,
            "component_report": comp_report,
            "errors": self.results["errors"][:20],
        }
        outpath = os.path.join(OUTPUT_DIR, "ecosystem_search_results.json")
        with open(outpath, 'w') as f:
            json.dump(output, f, indent=2, default=str)
        print(f"\nJSON output: {outpath}")
        return outpath

    def write_md_output(self, cross_ref, comp_report):
        """Write human-readable MD report."""
        outpath = os.path.join(OUTPUT_DIR, "ECOSYSTEM_GAP_ANALYSIS.md")
        lines = []
        lines.append("# BroyhillGOP Ecosystem Gap Analysis")
        lines.append(f"## Generated by Advanced Search Engine — March 12, 2026\n")
        lines.append(f"**Files scanned:** {self.results['files_scanned']}")
        lines.append(f"**Files with ecosystem refs:** {self.results['files_with_hits']}")
        lines.append(f"**Total ecosystem hits:** {self.results['total_ecosystem_hits']}")
        lines.append(f"**Total component hits:** {self.results['total_component_hits']}\n")
        lines.append("---\n")

        # --- CROSS REFERENCE TABLE ---
        lines.append("## 1. Ecosystem Cross-Reference: Planned vs Built\n")
        lines.append("| ID | Name | Status | Code Files | Doc Refs | Files Mentioning |")
        lines.append("|-----|------|--------|------------|----------|------------------|")
        for eco_id in sorted(cross_ref.keys(), key=lambda x: int(x[1:])):
            r = cross_ref[eco_id]
            status_icon = "✅" if r["status"] == "BUILT" else ("📋" if r["status"] == "PLANNED" else "❓")
            code_count = len(r["code_files"])
            lines.append(f"| {eco_id} | {r['name']} | {status_icon} {r['status']} | {code_count} | {r['doc_references']} | {r['files_mentioning']} |")

        # --- MISSING ECOSYSTEMS (planned but no code) ---
        lines.append("\n---\n")
        lines.append("## 2. PLANNED But NOT Built (No Code Found)\n")
        missing = {k: v for k, v in cross_ref.items() if v["status"] == "PLANNED"}
        if missing:
            for eco_id in sorted(missing.keys(), key=lambda x: int(x[1:])):
                r = missing[eco_id]
                lines.append(f"### {eco_id}: {r['name']}")
                lines.append(f"- Referenced in {r['doc_references']} places across {r['files_mentioning']} files")
                if r["top_files"]:
                    lines.append(f"- Key docs: {', '.join(os.path.basename(f) for f in r['top_files'][:3])}")
                lines.append("")
        else:
            lines.append("*All referenced ecosystems have code files.*\n")

        # --- COMPONENT/FEATURE REPORT ---
        lines.append("---\n")
        lines.append("## 3. Planned Components & Features Found in Docs\n")
        lines.append("These are specific capabilities described in historical docs.\n")
        sorted_comps = sorted(comp_report.items(), key=lambda x: x[1]["total_hits"], reverse=True)
        for comp_name, data in sorted_comps:
            display_name = comp_name.replace("_", " ").title()
            lines.append(f"### {display_name}")
            lines.append(f"- **Mentions:** {data['total_hits']} across {data['files_found_in']} files")
            if data["sample_contexts"]:
                lines.append(f"- **Sample context:**")
                for sc in data["sample_contexts"][:2]:
                    ctx_clean = sc["context"].replace("\n", " ")[:200]
                    lines.append(f"  - `{sc['file']}` L{sc['line']}: _{ctx_clean}_")
            lines.append("")

        # --- BUILT ECOSYSTEMS INVENTORY ---
        lines.append("---\n")
        lines.append("## 4. Built Ecosystems (Code Files Found)\n")
        built = {k: v for k, v in cross_ref.items() if v["status"] == "BUILT"}
        for eco_id in sorted(built.keys(), key=lambda x: int(x[1:])):
            r = built[eco_id]
            files_str = ", ".join(r["code_files"][:3])
            lines.append(f"- **{eco_id}** {r['name']}: {files_str}")
        lines.append("")

        # --- OVERLAP/CONFUSION ZONES ---
        lines.append("---\n")
        lines.append("## 5. Overlap & Confusion Zones\n")
        lines.append("Ecosystems with similar names/functions that may cause confusion:\n")
        overlaps = [
            ("E05/E26/E38", "Volunteer Management vs Volunteer Portal vs Volunteer Coordination"),
            ("E34/E37", "Events vs Event Management"),
            ("E31/E52/E57", "SMS Engine vs Contact Intelligence vs Messaging Center"),
            ("E11", "Budget Management AND Training LMS in same ecosystem"),
            ("E49/E50", "Interview System/GPU Orchestrator vs GPU Orchestrator (duplicate IDs?)"),
            ("E14/E18", "Print Production vs Print Advertising / VDP"),
            ("E06/E29", "Analytics Engine vs Analytics Dashboard"),
            ("E35/E36", "Interactive Comm Hub vs Messenger Integration"),
        ]
        for ids, desc in overlaps:
            lines.append(f"- **{ids}**: {desc}")
        lines.append("")

        with open(outpath, 'w') as f:
            f.write("\n".join(lines))
        print(f"MD output: {outpath}")
        return outpath


# ============================================================
# MAIN
# ============================================================

def main():
    engine = EcosystemSearchEngine()
    engine.run()
    cross_ref = engine.generate_cross_reference()
    comp_report = engine.generate_component_report()
    engine.write_json_output(cross_ref, comp_report)
    engine.write_md_output(cross_ref, comp_report)

    # Print quick summary to stdout
    print("\n" + "=" * 70)
    print("QUICK SUMMARY")
    print("=" * 70)

    print("\n--- Ecosystems by Status ---")
    built = [k for k, v in cross_ref.items() if v["status"] == "BUILT"]
    planned = [k for k, v in cross_ref.items() if v["status"] == "PLANNED"]
    unknown = [k for k, v in cross_ref.items() if v["status"] == "UNKNOWN"]
    print(f"  BUILT ({len(built)}): {', '.join(sorted(built, key=lambda x: int(x[1:])))}")
    print(f"  PLANNED only ({len(planned)}): {', '.join(sorted(planned, key=lambda x: int(x[1:])))}")
    print(f"  UNKNOWN ({len(unknown)}): {', '.join(sorted(unknown, key=lambda x: int(x[1:])))}")

    print("\n--- Top 10 Components by Mention Count ---")
    sorted_comps = sorted(comp_report.items(), key=lambda x: x[1]["total_hits"], reverse=True)
    for comp_name, data in sorted_comps[:10]:
        print(f"  {comp_name.replace('_', ' ').title():40s} {data['total_hits']:4d} hits in {data['files_found_in']:3d} files")

    print(f"\nFull reports written to:")
    print(f"  /Users/Broyhill/Desktop/ecosystem_search_results.json")
    print(f"  /Users/Broyhill/Desktop/ECOSYSTEM_GAP_ANALYSIS.md")


if __name__ == "__main__":
    main()
