# Archive

This directory contains **archived and deprecated content** from the IamRoot repository.

Nothing in this directory should be considered **actively maintained**, **recommended**, or **safe to use without review**.

The archive exists to preserve history, context, and learning, not to provide ready-to-use tools.

---

## Purpose of the Archive

The archive serves several goals:

- Preserve **historical scripts or approaches** that were once useful
- Provide **context** for why certain tools or patterns were replaced
- Avoid deleting content that may still be referenced in:
  - old tickets
  - documentation
  - institutional knowledge
- Keep the active parts of the repository **clean and focused**

---

## Directory Structure

Typical layout:

    archive/
    ├── README.md
    └── deprecated/
        ├── old-script.sh
        ├── legacy-tool.py
        └── notes.md

---

## deprecated/

The `deprecated/` subdirectory contains items that are no longer recommended.

Common reasons for deprecation include:

- Superseded by a newer script or tool
- No longer compatible with supported operating systems
- Relies on outdated assumptions or workflows
- Too risky or invasive by modern standards
- Kept only for reference or forensic purposes

Where possible, deprecated items should include:
- A short comment explaining **why** they were deprecated
- A pointer to the **replacement**, if one exists

---

## Usage Policy

- Do **not** use archived scripts in production
- Do **not** reference archived content in new documentation
- Do **not** add new features to archived items

- You **may** read archived content for:
  - historical understanding
  - debugging legacy systems
  - learning from past mistakes

If archived content becomes relevant again, it should be:
1. Reviewed
2. Updated
3. Moved back into the appropriate active directory

---

## Adding to the Archive

When moving content into the archive:

- Prefer moving instead of deleting
- Preserve git history if possible
- Add a short note explaining the reason for archival
- Update any references pointing to the new location

---

## Final Note

The presence of content in `archive/` is a signal:

> “This exists for reference, not for use.”

Keeping this boundary clear helps ensure that IamRoot remains trustworthy, predictable, and safe over time.
