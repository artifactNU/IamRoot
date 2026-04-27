# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

IamRoot is a Linux sysadmin toolbox: scripts, tools, docs, cheat-sheets, configs, and snippets for understanding and inspecting systems. It targets Ubuntu/Debian environments. Nothing here should be tightly coupled to one setup.

The guiding philosophy: **clarity over speed, boring solutions over clever ones, read-only by default**.

## Repository structure

| Directory | Purpose |
|-----------|---------|
| `scripts/` | All executable scripts, organized by domain |
| `scripts/system/` | OS-level: health, inventory, diagnostics, backup |
| `scripts/networking/` | Network scanning, packet capture, diagnostics |
| `scripts/security/` | Login auditing, hardening, forensics |
| `scripts/utils/` | General-purpose helpers |
| `docs/` | Long-form explanatory documentation (wiki-style, no scripts) |
| `cheat-sheets/` | Concise operator quick-references |
| `snippets/` | Short command examples and reminders |
| `configs/` | Example config files (always `.example` suffix, never real secrets) |
| `archive/deprecated/` | Superseded content — nothing here should be actively used |

Scripts are organized by domain, not by language. Bash, Perl, and Python scripts all live alongside each other within the relevant domain directory.

## Script requirements

Every script must have this header:

```bash
#!/usr/bin/env bash
# script-name.sh
# Purpose: One-line description of what the script does
# Usage:   ./script-name.sh [options]
# Exit:    0 OK, 1 WARN, 2 ERROR   # if exit codes are meaningful
```

### Bash style

- Shebang: `#!/usr/bin/env bash`
- Use `set -euo pipefail` unless the script is intentionally fault-tolerant
- Quote all variables unless word-splitting is intentional
- Avoid Bash features newer than Ubuntu LTS (20.04/22.04/24.04)
- ShellCheck compatibility is strongly encouraged
- Fail gracefully when optional tools are missing — partial output is better than none

### Perl scripts

- Use `use strict; use warnings; use autodie;`
- Live under `scripts/perl/`

## Output conventions

- **Diagnostic scripts**: human-readable stdout, best-effort (partial output acceptable)
- **Inventory tools** (under `tools/`): stable Markdown output, must support redaction of sensitive data (e.g. a `--public` flag), safe to archive long-term

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add CUDA compatibility check script
fix: handle missing nvidia-smi gracefully
docs: document SSH hardening steps
refactor: standardize script headers
chore: move deprecated scripts to archive
```

## Key design constraints

- Scripts must be **read-only by default** — no destructive actions (delete, modify, reboot, restart services) without explicit documentation
- Output should be usable in tickets, emails, or documentation
- No unnecessary dependencies or frameworks
- If something is clever but hard to understand, it does not belong here
