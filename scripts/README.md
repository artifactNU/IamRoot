# Scripts

This directory contains all executable scripts, organized by **domain**.

Scripts are meant to be:
- run directly by an administrator
- easy to read and modify
- safe by default (read-only unless explicitly documented otherwise)

---

## Structure

    scripts/
      system/      # OS-level: health, inventory, diagnostics, backup
      networking/  # Network diagnostics, scanning, packet capture
      security/    # Auditing, hardening, forensics, login analysis
      utils/       # General-purpose helpers

Scripts may be written in Bash, Perl, or Python. Language does not determine placement — domain does.

---

## What Belongs Here

- Health checks and diagnostics
- Inventory and audit collectors
- Security and log analysis
- Maintenance helpers

Scripts should:
- Do one thing
- Produce human-readable output
- Fail gracefully when dependencies are missing

---

## What Does NOT Belong Here

- Long-running daemons
- Configuration management logic
- Scripts that modify system state without explicit intent

---

## Script Requirements

All scripts must include a header:

    #!/usr/bin/env bash
    # script-name.sh
    # Purpose: One-line description
    # Usage:   ./script-name.sh [options]

Bash scripts should use `set -euo pipefail` unless intentionally fault-tolerant.  
Python scripts should target Python 3.8+ and use `#!/usr/bin/env python3`.  
Perl scripts should use `use strict; use warnings; use autodie;`.

---

## Output

Scripts are primarily for **interactive use**.
Machine-readable output (e.g. `--json`) is optional.

Inventory-style scripts that produce long-lived documentation output should prefer Markdown and support redaction of sensitive data.
