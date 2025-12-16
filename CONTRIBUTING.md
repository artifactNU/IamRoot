# Contributing to IamRoot

Thanks for your interest in contributing to **IamRoot**.

IamRoot is a long-term knowledge and tooling repository for Linux system administration.

The project is intentionally **boring, explicit, and safe**. It is meant to age well, be readable years later, and remain trustworthy.

---

## Scope and Philosophy

Before contributing, please align with these principles:

- **Safety first**
  - No destructive actions (delete, modify, reboot, restart services) unless clearly and explicitly documented
- **Simple over clever**
  - Prefer readable Bash over abstractions
  - Avoid unnecessary dependencies and frameworks
- **Sysadmin-focused**
  - Tools should help answer real operational questions
  - Output should be usable in tickets, emails or documentation
- **Documentation-aware**
  - Some outputs are meant to become long-lived documentation
  - Inventory-style tools must consider redaction and publishing

---

## Repository Structure

IamRoot is organized to separate **knowledge**, **scripts**, **tools**, and **examples**.

High-level structure:

    IamRoot/
    ├── README.md
    ├── LICENSE
    ├── CONTRIBUTING.md
    ├── .gitignore
    │
    ├── docs/
    │   ├── README.md
    │   ├── linux-basics/
    │   ├── networking/
    │   ├── security/
    │   └── troubleshooting/
    │
    ├── scripts/
    │   ├── README.md
    │   ├── bash/
    │   ├── python/
    │   └── perl/
    │
    ├── tools/
    │   ├── README.md
    │   ├── system/
    │   │   ├── inventory/
    │   │   └── diagnostics/
    │   ├── networking/
    │   └── security/
    │
    ├── snippets/
    │   ├── README.md
    │   └── *.md
    │
    ├── configs/
    │   ├── README.md
    │   └── *.example
    │
    ├── cheat-sheets/
    │   └── *.md
    │
    └── archive/
        ├── README.md
        └── deprecated/

---

## What Goes Where

### docs/
Long-form **explanatory documentation**.

- Conceptual guides
- How things work
- Troubleshooting theory
- No scripts here

If it reads like a wiki page or teaching material, it belongs here.

---

### scripts/
Small, focused **utilities** intended to be run directly.

- Short-lived execution
- Often run interactively
- Usually one concern per script

Examples:
- health checks
- disk usage checks
- quick diagnostics
- cleanup helpers

Subdirectories reflect language and purpose.

---

### tools/
Larger or more structured helpers.

These often:
- Generate reports
- Produce documentation-ready output
- Collect inventory or system state
- Are run less frequently, but more deliberately

Examples:
- workstation inventory generators
- GPU diagnostics bundles
- system audit collectors

Inventory-related tools must consider **redaction** and **publishability**.

---

### snippets/
Short reference material.

- Command examples
- systemd units
- SSH one-liners
- vim tricks

Not executable scripts, not full documentation.

---

### configs/
Example configuration files.

- Always use `.example` suffix
- Never include secrets
- Meant to be copied and adapted

---

### cheat-sheets/
Concise operator references.

- Commands
- Flags
- Common workflows

Optimized for quick lookup, not explanation.

---

### archive/
Old or deprecated content.

- Superseded scripts
- Obsolete approaches
- Historical reference

Nothing here should be actively used.

---

## Script Guidelines

### Headers

All scripts **must** include a minimal header:

    #!/usr/bin/env bash
    # script-name.sh
    # Purpose: One-line description of what the script does
    # Usage:   ./script-name.sh [options]
    # Exit:    0 OK, 1 WARN, 2 ERROR   # if applicable

Keep headers short and factual.

---

### Bash Style

- Use `#!/usr/bin/env bash`
- Prefer:

      set -euo pipefail

  unless the script is intentionally fault-tolerant
- Quote variables unless word-splitting is intentional
- Avoid Bash features newer than Ubuntu LTS
- ShellCheck compatibility is encouraged

---

## Output Expectations

### Diagnostic scripts
- Human-readable output
- Best-effort execution
- Partial output is better than none
- No requirement for machine-readable formats

### Inventory tools
- Output should be **stable and documentation-ready**
- Markdown output is preferred
- Must support redaction of sensitive data (for example `--public`)

---

## Sensitive Information

Never hardcode or publish:

- Credentials or secrets
- Tokens or API keys
- Private SSH keys
- Passwords or hashes

---

## Testing

At minimum, contributions should be tested on:

- Ubuntu LTS releases (20.04 / 22.04 / 24.04)

Where applicable:
- Test behavior when optional tools are missing
- Ensure scripts fail **gracefully** and explain what could not be collected

---

## Commits and Conventions

IamRoot follows **Conventional Commits**.

Common prefixes:

- feat: new functionality
- fix: bug fixes
- refactor: restructuring without behavior change
- docs: documentation-only changes
- chore: maintenance or repo hygiene

Examples:

    feat: add CUDA compatibility check script
    refactor: standardize script headers
    docs: document repository structure

Keep commits small and focused.

---

## Submitting Changes

1. Fork the repository
2. Create a topic branch
3. Make your changes
4. Ensure safety, clarity and consistency
5. Open a pull request with a clear description

There is no strict PR template

---

## Final Note

IamRoot aims to be:

- boring in the best way
- predictable
- readable under pressure
- useful years from now

If your contribution helps admins understand a system faster or make fewer mistakes, it belongs here.

Thanks for contributing.
