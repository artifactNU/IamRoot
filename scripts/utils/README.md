# Utility Scripts

General-purpose helpers that don't belong to a specific domain.

---

## Contents

| Script | Description | Safe to run? |
|--------|-------------|--------------|
| `xlsx-to-csv.sh` | Extract columns/rows from Excel or ODS files and output CSV | Read-only |
| `cleanup-old-files.sh` | Find and delete old files by age, size, and pattern | **DESTRUCTIVE** — use `--dry-run` first |
| `rotate_logs.py` | Rotate, compress, and prune log files per a JSON config | **DESTRUCTIVE** — use `--dry-run` first |

---

## Guidelines

- Scripts here should be self-contained with minimal dependencies
- Destructive scripts must support a `--dry-run` mode and document it clearly
- Compatible with Ubuntu LTS releases
