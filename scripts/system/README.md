# System Scripts

Scripts for monitoring, inspecting, and documenting the local system.

---

## Contents

- Health checks (CPU, memory, disk, GPU, APT)
- Workstation inventory and audit reports
- Log and error signal analysis
- Backup helpers
- Storage and performance diagnostics

---

## Guidelines

- Read-only by default
- Output should be usable in tickets or internal documentation
- Inventory scripts should prefer Markdown output and support redaction of sensitive data
- Fail gracefully when optional tools (e.g. `nvidia-smi`) are missing
