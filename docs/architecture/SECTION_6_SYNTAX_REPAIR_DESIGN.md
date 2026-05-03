# Section 6 — Pre-existing Syntax Error Repair (Design + Rationale)

**Merged:** 2026-05-02 as commit `d2259cf` (PR #4 into rename branch) and `1e7846e` (rename branch into main).
**Branch:** `claude/section-6-syntax-fixes-2026-05-02` (now defunct).

---

## Why this PR existed

Nexus's rename branch (`fix/rename-and-cleanup-2026-05-02`) successfully renamed 119 ecosystem files (dropping the `_complete` suffix), repaired 536 invalid Python class names from Cursor's "Auto-added by repair tool" damage, and fixed 476 internal references. **But** when Nexus ran `ast.parse` against the post-rename tree, 6 files still failed.

Those 6 failures pre-existed on `main` — the rename didn't cause them. They were exposed by the rename because the cleanup made the parse-rate-improvement measurable for the first time. Before the rename, the file tree was so broken nobody could tell which files were syntactically valid.

The 6 files were:

| File | Reported error | Root cause |
|---|---|---|
| `ecosystems/ecosystem_50_gpu_orchestrator.py` | L1150 invalid syntax in `print("""` | Inner classes' `"""docstrings"""` prematurely closed an outer banner string |
| `ecosystems/ecosystem_01_platform_social_import.py` | L1411 unexpected indent | Cursor injection inside an `elif` body |
| `ecosystems/ecosystem_47_unified_voice_engine.py` | L359 unexpected indent | Cursor injection inside a `try` body |
| `ecosystems/ecosystem_53_document_generation.py` | L675 expected `except` or `finally` | Cursor injection cracked open a `try:` block |
| `ecosystems/ecosystem_55_api_gateway.py` | L465 unexpected indent | Cursor injection mid-method |
| `backend/python/ecosystems/ecosystem_36_messenger_integration.py` | L6 unexpected indent at start of file | Cursor stripped the entire wrapping module/class def |

## Universal root cause

Cursor's "repair tool" — invoked at some point in late 2025 / early 2026 — injected module-level Python (imports, exception classes, sometimes a `Config` dataclass) at **whatever character position the cursor happened to be in when the tool ran.** That position was usually inside a method body, an `elif` branch, or a `try:` block.

The injection landed at indent 0, breaking the indent of whatever code followed. In file 1 (the GPU orchestrator), the inner classes' docstrings (`"""Base exception for this ecosystem"""`) prematurely closed an outer `print("""...""")` banner string, which compounded the damage.

## The repair recipe

A single regex catches the universal pattern:

```python
INJECTION_RE = re.compile(
    r"\n*# === [A-Z ]+\(Auto-added by repair tool\) ===\n"
    r".*?"
    r"# === END [A-Z ]+ ===\n+",
    re.DOTALL,
)
```

For files 1–5, the recipe was:

1. Strip every `# === ... (Auto-added by repair tool) ===` ... `# === END ... ===` block.
2. Hoist ONE deduplicated copy of the canonical exception classes + `handle_errors` decorator to module level just after the imports.
3. For file 1 only: rewrite the `__main__` banner to use a module-level `_BANNER` string with no inner triple-quotes.

For file 6, the damage was beyond recipe — the file was a 1,430-line orphan fragment with no imports, no class wrappers, and duplicate `def deploy_messenger_integration` blocks. **Replaced contents with the canonical sibling at `ecosystems/ecosystem_36_messenger_integration.py`** (37 KB clean), as recommended by the assignment doc ("compare against its sibling in the other dir — one may be the un-corrupted twin").

## Why this approach over alternatives

**Alternative considered:** delete the broken backend twin entirely, on the grounds that the duplicate-folder problem is out-of-scope. **Rejected** because nothing else in the build/deploy pipeline distinguishes between front and backend files; deleting one half could break a downstream consumer that imports from `backend/python/ecosystems/...`. Replacing with the canonical sibling is reversible and risk-free.

**Alternative considered:** comment out the broken sections. **Rejected** because commented-out code is the worst of both worlds — still confusing to readers, still consumes line numbers, never gets removed.

## What this PR did NOT change

- Functional behavior of any module. The repairs are syntactic only.
- The hoisted exception classes are dead code unless something later imports them. They were dead code before the repair too — the repair just makes them legally parseable dead code.
- The duplicate-folder problem (`ecosystems/` vs `backend/python/ecosystems/`).

## Validation that ran before merge

- `ast.parse` on every changed file: ✅
- `python3 -m py_compile` on every changed file: ✅
- Full-repo sweep across all `ecosystem_##_*.py`: 133/139 → 139/139 ✅
- Zero baseline-passing files regressed.

## What anyone picking this up later needs to know

Cursor may run its "repair tool" again on this codebase in the future. If it does, the same injection pattern will reappear. The regex above is reusable. Check periodically with:

```bash
grep -rln "Auto-added by repair tool" --include="*.py" ecosystems/ backend/python/ecosystems/
```

If that returns hits, run the same recipe again.

The duplicate-folder problem is the bigger picture: as long as `backend/python/ecosystems/` exists alongside `ecosystems/`, every change touches both. A future PR should pick one as canonical and either delete or symlink the other.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. Repaired files merged via `d2259cf`.*
