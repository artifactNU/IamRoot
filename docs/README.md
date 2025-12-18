# Documentation

This directory contains **long-form documentation** for Linux system administration.

The focus is on **concepts, explanations, and troubleshooting approaches**, not scripts or automation.

Documentation here should age well and remain useful even as tooling changes.

---

## Scope

Content in `docs/` should answer questions like:

- How does this part of the system work?
- What are the common failure modes?
- How should an admin think about diagnosing issues?
- What trade-offs exist between approaches?

If it reads like a guide, tutorial, or reference article, it belongs here.

---

## Structure

Documentation is organized by topic area:

- `linux-basics/`  
  Core concepts such as filesystems, permissions, and processes

- `networking/`  
  TCP/IP fundamentals, troubleshooting, firewalls

- `security/`  
  Hardening, auditing, incident response

- `troubleshooting/`  
  Performance, disk issues, boot problems

Each subdirectory should contain focused Markdown files with clear titles.

---

## Guidelines

- Use Markdown
- Prefer clarity over completeness
- Avoid environment-specific assumptions
- Do not embed secrets or internal-only details
- Reference scripts or tools by name, not by embedding code

---

## What Does NOT Belong Here

- Executable scripts
- One-liners or short command snippets (use `snippets/`)
- Generated output or reports
- Configuration files

---

## Goal

The goal of `docs/` is to act as a **durable knowledge base** for system administrators, readable under pressure and useful years later.
