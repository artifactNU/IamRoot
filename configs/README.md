# Configuration Examples

This directory contains **example configuration files**.

All files here are templates meant to be copied, reviewed, and adapted.

---

## Rules

- Files must use the `.example` suffix
- Never include secrets, credentials, or tokens
- Avoid environment-specific values
- Document assumptions inside the file where appropriate

---

## Structure

Configuration examples are grouped by subsystem:

    configs/
      ssh/
      systemd/
      logrotate/

Each subdirectory should contain minimal, well-commented examples.

---

## Intended Use

These files are meant to:
- illustrate good defaults
- serve as starting points
- document recommended patterns

They are **not** drop-in replacements.

---

## What Does NOT Belong Here

- Active production configuration
- Private or internal-only settings
- Generated files
- Large configuration dumps

---

## Philosophy

Configuration examples should be:
- conservative
- readable
- safe
- easy to reason about

When in doubt, include fewer options and more comments.
