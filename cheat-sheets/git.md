# Git Cheat Sheet

Quick reference for common Git workflows.

---

## Setup

- Set your name/email
  - `git config --global user.name "Your Name"`
  - `git config --global user.email "you@example.com"`

- Useful defaults
  - `git config --global init.defaultBranch main`
  - `git config --global pull.rebase false`

- Show config
  - `git config --list`

---

## Create / Clone

- Initialize repo
  - `git init`

- Clone repo
  - `git clone <url>`

---

## Status & History

- Check status
  - `git status`

- Short status
  - `git status -sb`

- View log (compact)
  - `git log --oneline --decorate --graph --all`

- Show a commit
  - `git show <commit>`

---

## Staging & Committing

- Stage a file
  - `git add <file>`

- Stage all changes
  - `git add -A`

- Unstage a file
  - `git restore --staged <file>`

- Discard local changes in a file
  - `git restore <file>`

- Commit
  - `git commit -m "type: message"`

- Amend last commit message/content
  - `git commit --amend`

---

## Branching

- List branches
  - `git branch`

- Create branch
  - `git checkout -b <branch>`
  - or: `git switch -c <branch>`

- Switch branch
  - `git checkout <branch>`
  - or: `git switch <branch>`

- Rename current branch
  - `git branch -m <new-name>`

- Delete local branch
  - `git branch -d <branch>` (safe)
  - `git branch -D <branch>` (force)

---

## Pulling & Pushing

- Fetch (update remote refs)
  - `git fetch`

- Pull (fetch + merge)
  - `git pull`

- Push current branch
  - `git push`

- Push new branch and set upstream
  - `git push -u origin <branch>`

---

## Merging & Rebasing (common cases)

- Merge another branch into current
  - `git merge <branch>`

- Rebase current branch onto main
  - `git fetch origin`
  - `git rebase origin/main`

- Abort a rebase
  - `git rebase --abort`

- Continue a rebase after resolving conflicts
  - `git rebase --continue`

---

## Conflicts

- See conflict markers in files:
  - `<<<<<<<`, `=======`, `>>>>>>>`

Typical flow:
1. Edit file(s) to resolve
2. `git add <resolved-file>`
3. Continue:
   - merge: `git commit`
   - rebase: `git rebase --continue`

---

## Undo & Recovery

- Undo last commit but keep changes staged
  - `git reset --soft HEAD~1`

- Undo last commit and unstage changes
  - `git reset HEAD~1`

- Undo last commit and discard changes (danger)
  - `git reset --hard HEAD~1`

- Recover lost commits (lifesaver)
  - `git reflog`
  - `git checkout <commit>`
  - or: `git reset --hard <commit>`

---

## Stash

- Stash changes
  - `git stash`

- List stashes
  - `git stash list`

- Apply stash (keep stash)
  - `git stash apply`

- Pop stash (remove stash)
  - `git stash pop`

- Stash with message
  - `git stash push -m "wip: something"`

---

## Tags

- List tags
  - `git tag`

- Create tag
  - `git tag v1.0.0`

- Push tags
  - `git push --tags`

---

## Remotes

- Show remotes
  - `git remote -v`

- Add remote
  - `git remote add origin <url>`

- Change remote URL
  - `git remote set-url origin <url>`

---

## Useful Inspection Commands

- Show what changed (unstaged)
  - `git diff`

- Show what’s staged
  - `git diff --staged`

- Who changed a line (blame)
  - `git blame <file>`

- Search history for a string
  - `git log -S "string"`

---

## Conventional Commit Quick Reference

Common types used in IamRoot-style repos:

- `feat:` new functionality
- `fix:` bug fix
- `refactor:` restructure without behavior change
- `docs:` documentation-only
- `chore:` maintenance/repo hygiene

Examples:
- `feat: add workstation inventory script`
- `refactor: reorganize scripts into tools and scripts directories`
- `docs: add git cheat sheet`

---

## Notes

- `git status` is the command you should run most often
- If you are unsure: `git status -sb` and `git log --oneline --decorate -5`
- `reflog` can recover mistakes — don’t panic
