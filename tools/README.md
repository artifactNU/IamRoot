# Tools

This directory contains **larger, structured helpers** intended for deliberate use.

Tools typically:
- collect multiple data points
- generate reports
- produce documentation-ready output
- are run infrequently but intentionally

---

## Structure

Tools are grouped by domain:

    tools/
      system/
        inventory/
        diagnostics/
      networking/
        sniffing/
        scanning/
      security/
        forensics/
        hardening/

---

## What Belongs Here

- Inventory generators
- Diagnostic bundles
- Audit collectors
- Documentation-producing tools

Tools often:
- span multiple logical steps
- output files instead of just stdout
- require careful consideration of sensitive data

---

## Inventory Tools

Inventory-related tools must:
- Consider long-term documentation use
- Prefer stable Markdown output
- Support redaction of sensitive information
- Be safe to publish when run in “public” mode

---

## What Does NOT Belong Here

- Small ad-hoc scripts (use `scripts/`)
- Long-form documentation (use `docs/`)
- Experimental or unfinished ideas

---

## Design Philosophy

Tools should prioritize:
- clarity over speed
- explicit behavior over automation
- trustworthiness over completeness

If a tool’s output cannot be safely shared or archived, that should be clearly documented.
