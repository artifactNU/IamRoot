# Python Scripts

Small, focused Python utilities for system administration tasks.

---

## Purpose

Python scripts here serve similar purposes to bash scripts but may:
- Handle more complex data structures
- Interface with APIs or libraries
- Require parsing structured data (JSON, YAML, XML)
- Benefit from Python's standard library

---

## Guidelines

Python scripts should:
- Use Python 3.8+ (compatible with Ubuntu 20.04 LTS)
- Include shebang: `#!/usr/bin/env python3`
- Have minimal external dependencies
- Include docstrings explaining purpose and usage
- Handle missing dependencies gracefully

---

## Structure

Scripts are organized by purpose:

    python/
      monitoring/
      automation/

---

## Dependencies

If a script requires external packages:
- Document them in a comment at the top of the file
- Check for their presence before use
- Provide a helpful error message if missing
- Consider whether the functionality belongs in `tools/` instead
