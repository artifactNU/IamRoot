# IamRoot

Where sysadmins unlock the ultimate power of configurations  
held together by duct tape and optimism.

## What is this?

IamRoot is a personal and shared toolbox for Linux sysadmins.

It is a collection of:
- Useful scripts for day-to-day admin work
- Inventory and audit helpers
- Diagnostics and troubleshooting tools
- Cheat sheets and snippets you actually look up
- Documentation that explains things without assuming too much

This repo exists because real systems are messy and understanding them should not be.

---

## What this repo is trying to do

The main idea is simple:

- Make systems easier to understand
- Prefer inspection over modification
- Produce output that humans can read
- Turn command-line knowledge into documentation

Many scripts here are designed to generate information that can later be turned into internal documentation or PDFs. Nothing fancy, just useful.

---

## What this repo is not

- Not a framework
- Not a config management system
- Not opinionated about your infrastructure
- Not trying to automate everything

If something is clever but hard to understand, it probably does not belong here.

---

## How things are organized

This repo is split into a few top-level directories like:
- docs
- scripts
- tools
- snippets
- configs
- cheat-sheets
- archive

Each directory has its own README that explains what belongs there.  
The main README stays high-level on purpose.

If you are unsure where something should go, check the README in that directory first.

---

## Scripts, tools, and everything else

In general:
- Scripts are small, focused, and easy to audit
- Tools are bigger or made of multiple pieces
- Snippets are short examples or reminders
- Cheat sheets are quick references
- Archive is where old or replaced things go

If you are hesitating, start with scripts. It is easier to move things later than to overthink it.

---

## Safety first

Most scripts here are read-only by default.
If something is destructive, it should be obvious and clearly documented.

This repo favors:
- clarity over speed
- boring solutions over clever ones
- commands you can explain to someone else

---

## Who this is for

- Linux sysadmins
- Research IT and lab support
- Anyone maintaining systems they did not set up themselves
- People who want fewer surprises at 3 AM

It works best in Ubuntu and Debian environments, but nothing should be tightly coupled to one setup.

---

## Contributing

If you want to add or change something, please read:
- CONTRIBUTING.md

Short version:
- Follow the existing structure
- Write things so future you understands them
- Prefer simple and readable
- Use conventional commits
- Avoid destructive defaults

---

## Final words

This repo is about understanding systems, not pretending they are perfect.

If a script helped you answer  
"what is actually going on here?"  
then it probably belongs in IamRoot.
