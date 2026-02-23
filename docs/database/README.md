# Database Administration

This directory contains **operational documentation** for common database systems used in production environments.

The focus is on **system administration tasks, monitoring, and troubleshooting**, not database design or SQL optimization.

---

## Scope

Content here answers questions like:

- How do I set up and maintain a database server?
- What can go wrong and how do I diagnose it?
- How do I safely backup and recover data?
- What are typical performance issues and how do I identify them?
- How do I monitor database health?

If it helps a sysadmin keep a database running reliably, it belongs here.

---

## Structure

Documentation is organized by database system and operational topic:

- `mysql-postgresql-basics.md`  
  Setup, user management, backups, monitoring, and troubleshooting for MySQL and PostgreSQL

- `backup-recovery.md` (planned)  
  Strategies and tools for backing up databases safely

- `performance-tuning.md` (planned)  
  Identifying and addressing performance issues

Each file should be self-contained but may reference others.

---

## Guidelines

- Use Markdown
- Assume the reader is a sysadmin, not a database specialist
- Focus on **operational tasks** (backups, monitoring, restarts)
- Include common failure modes and diagnostics
- Do not optimize queries or focus on schema design
- Prefer clarity over completeness

---

## What Does NOT Belong Here

- SQL syntax or database design
- Application connection pooling or driver setup
- Query optimization or tuning techniques
- Replication or high-availability clustering (separate concern)
- Database migration tools or strategies

---

## Goal

The goal is to act as a **reference for sysadmins operating database servers**, helping them keep systems running, respond to incidents, and perform routine maintenance tasks.
