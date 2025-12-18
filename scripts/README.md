# Scripts

This directory contains **small, focused executable scripts**.

Scripts here are meant to be:
- run directly by an administrator
- short-lived in execution
- easy to read and modify
- safe by default

---

## Structure

Scripts are organized first by **language**, then by **purpose**.

Example:

    scripts/
      bash/
        monitoring/
        backup/
        utils/
      python/
        monitoring/
        automation/
      perl/
        legacy/

---

## What Belongs Here

- Health checks
- Quick diagnostics
- Disk or resource usage checks
- Small maintenance helpers
- One-task scripts

Scripts should generally:
- Do one thing
- Produce human-readable output
- Fail gracefully when dependencies are missing

---

## What Does NOT Belong Here

- Large report generators (use `tools/`)
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

Scripts should be:
- Read-only by default
- Explicit about any side effects
- Compatible with Ubuntu LTS releases

---

## Output

Scripts are primarily for **interactive use**.
Machine-readable output is optional and not required.

If output is meant to become documentation, consider placing the script under `tools/` instead.
