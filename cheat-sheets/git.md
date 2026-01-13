# Git Cheat Sheet

Quick reference for common Git workflows and commands.

---

## Table of Contents

- [Setup](#setup)
- [Create / Clone](#create--clone)
- [Status & History](#status--history)
- [Staging & Committing](#staging--committing)
- [Branching](#branching)
- [Pulling & Pushing](#pulling--pushing)
- [Merging & Rebasing](#merging--rebasing)
- [Conflicts](#conflicts)
- [Undo & Recovery](#undo--recovery)
- [Stash](#stash)
- [Tags](#tags)
- [Remotes](#remotes)
- [Working with Changes](#working-with-changes)
- [Advanced History](#advanced-history)
- [Submodules](#submodules)
- [Git Worktree](#git-worktree)
- [Cherry Pick](#cherry-pick)
- [Bisect](#bisect)
- [Cleaning](#cleaning)
- [Aliases](#aliases)
- [GitHub CLI](#github-cli)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Conventional Commits](#conventional-commits)
- [Quick Reference](#quick-reference)

---

## Setup

### Initial Configuration

- Set your name/email
  - `git config --global user.name "Your Name"`
  - `git config --global user.email "you@example.com"`

- Useful defaults
  - `git config --global init.defaultBranch main`
  - `git config --global pull.rebase false`
  - `git config --global core.autocrlf input` (Linux/Mac)
  - `git config --global core.editor vim` (or nano, code, etc.)

- Show config
  - `git config --list`
  - `git config --global --list`

- Show specific config
  - `git config user.name`

- Edit config file
  - `git config --global --edit`

### Helpful Aliases

Add to your git config:

```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.lg 'log --oneline --decorate --graph --all'
```

---

## Create / Clone

### Initialize Repository

- Initialize repo
  - `git init`

- Initialize with specific branch name
  - `git init -b main`

- Initialize bare repository (server-side)
  - `git init --bare`

### Clone Repository

- Clone repo
  - `git clone <url>`

- Clone to specific directory
  - `git clone <url> <directory>`

- Clone specific branch
  - `git clone -b <branch> <url>`

- Shallow clone (faster, less history)
  - `git clone --depth 1 <url>`

- Clone with submodules
  - `git clone --recursive <url>`

---

## Status & History

### Status Commands

- Check status
  - `git status`

- Short status
  - `git status -sb`
  - `git status -s` (shorter format)

- Show ignored files
  - `git status --ignored`

### Basic Log

- View log (compact)
  - `git log --oneline`
  - `git log --oneline --decorate --graph --all`

- View log with patches
  - `git log -p`

- View last N commits
  - `git log -n 5`

- View log since date
  - `git log --since="2 weeks ago"`
  - `git log --after="2024-01-01"`

- View log by author
  - `git log --author="Name"`

### Advanced Log

- One-line with dates
  - `git log --pretty=format:"%h %ad | %s%d [%an]" --date=short`

- Graph view (pretty)
  - `git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'`

- Files changed in each commit
  - `git log --stat`

- Show commits that changed a file
  - `git log --follow <file>`

- Show commits affecting a function
  - `git log -L :function_name:file.py`

### Show Command

- Show a commit
  - `git show <commit>`

- Show specific file from commit
  - `git show <commit>:<file>`

- Show commit stats only
  - `git show --stat <commit>`

---

## Staging & Committing

### Staging Changes

- Stage a file
  - `git add <file>`

- Stage all changes
  - `git add -A`
  - `git add .` (current directory)

- Stage all tracked files
  - `git add -u`

- Stage interactively
  - `git add -p` (patch mode, choose hunks)

- Stage part of a file
  - `git add -e <file>` (edit in editor)

### Unstaging

- Unstage a file
  - `git restore --staged <file>`
  - `git reset HEAD <file>` (older syntax)

- Unstage all
  - `git restore --staged .`
  - `git reset HEAD`

### Discarding Changes

- Discard local changes in a file
  - `git restore <file>`
  - `git checkout -- <file>` (older syntax)

- Discard all local changes
  - `git restore .`

### Committing

- Commit
  - `git commit -m "type: message"`

- Commit with detailed message
  - `git commit` (opens editor)

- Commit all tracked changes
  - `git commit -am "message"`

- Amend last commit message
  - `git commit --amend -m "new message"`

- Amend last commit (add more changes)
  - `git add <file>`
  - `git commit --amend --no-edit`

- Commit with specific author
  - `git commit --author="Name <email>" -m "message"`

- Empty commit (useful for CI triggers)
  - `git commit --allow-empty -m "message"`

---

## Branching

### Listing Branches

- List local branches
  - `git branch`

- List all branches (local + remote)
  - `git branch -a`

- List remote branches
  - `git branch -r`

- List with last commit
  - `git branch -v`

- List merged branches
  - `git branch --merged`

- List unmerged branches
  - `git branch --no-merged`

### Creating Branches

- Create branch
  - `git branch <branch>`

- Create and switch
  - `git checkout -b <branch>`
  - `git switch -c <branch>` (modern)

- Create from specific commit
  - `git branch <branch> <commit>`

- Create from remote branch
  - `git checkout -b <branch> origin/<branch>`

### Switching Branches

- Switch branch
  - `git checkout <branch>`
  - `git switch <branch>` (modern)

- Switch to previous branch
  - `git checkout -`
  - `git switch -`

### Renaming Branches

- Rename current branch
  - `git branch -m <new-name>`

- Rename other branch
  - `git branch -m <old-name> <new-name>`

- Update remote after rename
  - `git push origin -u <new-name>`
  - `git push origin --delete <old-name>`

### Deleting Branches

- Delete local branch (safe)
  - `git branch -d <branch>`

- Force delete local branch
  - `git branch -D <branch>`

- Delete remote branch
  - `git push origin --delete <branch>`
  - `git push origin :<branch>` (older syntax)

---

## Pulling & Pushing

### Fetching

- Fetch (update remote refs)
  - `git fetch`

- Fetch all remotes
  - `git fetch --all`

- Fetch and prune deleted branches
  - `git fetch --prune`
  - `git fetch -p`

- Fetch specific branch
  - `git fetch origin <branch>`

### Pulling

- Pull (fetch + merge)
  - `git pull`

- Pull with rebase
  - `git pull --rebase`

- Pull from specific remote/branch
  - `git pull origin main`

- Pull all tags
  - `git pull --tags`

### Pushing

- Push current branch
  - `git push`

- Push new branch and set upstream
  - `git push -u origin <branch>`
  - `git push --set-upstream origin <branch>`

- Push all branches
  - `git push --all`

- Push tags
  - `git push --tags`

- Force push (dangerous)
  - `git push --force`
  - `git push -f`

- Force push safely (won't overwrite others' work)
  - `git push --force-with-lease`

- Push and skip hooks
  - `git push --no-verify`

---

## Merging & Rebasing

### Merging

- Merge another branch into current
  - `git merge <branch>`

- Merge with no fast-forward
  - `git merge --no-ff <branch>`

- Merge and squash commits
  - `git merge --squash <branch>`

- Abort merge
  - `git merge --abort`

- Continue merge after resolving conflicts
  - `git commit` (after adding resolved files)

### Rebasing

- Rebase current branch onto main
  - `git fetch origin`
  - `git rebase origin/main`

- Rebase onto specific branch
  - `git rebase <branch>`

- Interactive rebase (last N commits)
  - `git rebase -i HEAD~N`

- Rebase onto specific commit
  - `git rebase --onto <newbase> <oldbase>`

- Abort rebase
  - `git rebase --abort`

- Continue rebase after resolving conflicts
  - `git add <resolved-files>`
  - `git rebase --continue`

- Skip current commit in rebase
  - `git rebase --skip`

### Interactive Rebase Commands

When running `git rebase -i`:
- `pick` - use commit
- `reword` - use commit but edit message
- `edit` - use commit but stop for amending
- `squash` - combine with previous commit
- `fixup` - like squash but discard message
- `drop` - remove commit

---

## Conflicts

### Understanding Conflicts

Conflict markers in files:
```
<<<<<<< HEAD
Your changes
=======
Their changes
>>>>>>> branch-name
```

### Resolving Conflicts

Typical flow:
1. View conflicted files: `git status`
2. Edit file(s) to resolve (remove markers, keep desired code)
3. Stage resolved files: `git add <resolved-file>`
4. Continue:
   - For merge: `git commit`
   - For rebase: `git rebase --continue`
   - For cherry-pick: `git cherry-pick --continue`

### Conflict Tools

- Use merge tool
  - `git mergetool`

- Accept theirs for a file
  - `git checkout --theirs <file>`
  - `git add <file>`

- Accept ours for a file
  - `git checkout --ours <file>`
  - `git add <file>`

- Show conflicts
  - `git diff --name-only --diff-filter=U`

---

## Undo & Recovery

### Reset (Moving HEAD)

- Undo last commit but keep changes staged
  - `git reset --soft HEAD~1`

- Undo last commit and unstage changes
  - `git reset HEAD~1`
  - `git reset --mixed HEAD~1` (same as above)

- Undo last commit and discard changes (⚠️ dangerous)
  - `git reset --hard HEAD~1`

- Reset to specific commit
  - `git reset <commit>`

- Reset and keep working directory
  - `git reset --soft <commit>`

### Revert (Create new commit)

- Revert a commit (safer than reset)
  - `git revert <commit>`

- Revert multiple commits
  - `git revert <oldest>..<newest>`

- Revert without committing
  - `git revert -n <commit>`

### Reflog (Recovery)

- View reflog (lifesaver)
  - `git reflog`

- Reflog for specific branch
  - `git reflog show <branch>`

- Recover lost commit
  - `git reflog` (find commit hash)
  - `git checkout <commit>`
  - `git branch recovery-branch <commit>`

- Recover deleted branch
  - `git reflog` (find branch tip)
  - `git branch <branch-name> <commit>`

### Other Undo Operations

- Undo file changes before staging
  - `git restore <file>`

- Undo staged changes
  - `git restore --staged <file>`

- Remove untracked files (preview first!)
  - `git clean -n` (dry run)
  - `git clean -f` (force)
  - `git clean -fd` (include directories)

---

## Stash

### Basic Stashing

- Stash changes
  - `git stash`
  - `git stash push` (same as above)

- Stash with message
  - `git stash push -m "wip: something"`

- Stash including untracked files
  - `git stash -u`

- Stash including ignored files
  - `git stash -a`

### Managing Stashes

- List stashes
  - `git stash list`

- Show stash contents
  - `git stash show`
  - `git stash show -p` (with patch)

- Show specific stash
  - `git stash show stash@{N}`

### Applying Stashes

- Apply stash (keep stash)
  - `git stash apply`

- Apply specific stash
  - `git stash apply stash@{N}`

- Pop stash (apply and remove)
  - `git stash pop`

- Pop specific stash
  - `git stash pop stash@{N}`

### Other Stash Operations

- Create branch from stash
  - `git stash branch <branch-name>`

- Drop specific stash
  - `git stash drop stash@{N}`

- Clear all stashes
  - `git stash clear`

---

## Tags

### Creating Tags

- List tags
  - `git tag`

- List tags matching pattern
  - `git tag -l "v1.*"`

- Create lightweight tag
  - `git tag v1.0.0`

- Create annotated tag (recommended)
  - `git tag -a v1.0.0 -m "Release version 1.0.0"`

- Tag specific commit
  - `git tag -a v1.0.0 <commit> -m "message"`

### Pushing Tags

- Push single tag
  - `git push origin v1.0.0`

- Push all tags
  - `git push --tags`
  - `git push origin --tags`

### Managing Tags

- Show tag information
  - `git show v1.0.0`

- Checkout tag
  - `git checkout v1.0.0` (detached HEAD)

- Delete local tag
  - `git tag -d v1.0.0`

- Delete remote tag
  - `git push origin --delete v1.0.0`
  - `git push origin :refs/tags/v1.0.0`

---

## Remotes

### Managing Remotes

- Show remotes
  - `git remote -v`

- Show remote details
  - `git remote show origin`

- Add remote
  - `git remote add origin <url>`

- Add additional remote
  - `git remote add upstream <url>`

- Change remote URL
  - `git remote set-url origin <url>`

- Rename remote
  - `git remote rename origin new-origin`

- Remove remote
  - `git remote remove origin`

### Working with Remotes

- List remote branches
  - `git branch -r`

- Prune stale remote branches
  - `git remote prune origin`
  - `git fetch --prune`

- Track remote branch
  - `git checkout --track origin/branch-name`

---

## Working with Changes

### Diff Commands

- Show what changed (unstaged)
  - `git diff`

- Show what's staged
  - `git diff --staged`
  - `git diff --cached` (same)

- Show changes between branches
  - `git diff <branch1>..<branch2>`

- Show changes between commits
  - `git diff <commit1> <commit2>`

- Show changes for specific file
  - `git diff <file>`

- Show word-level diff
  - `git diff --word-diff`

- Show stats only
  - `git diff --stat`

### Blame & History

- Who changed a line (blame)
  - `git blame <file>`

- Blame specific lines
  - `git blame -L 10,20 <file>`

- Blame and ignore whitespace
  - `git blame -w <file>`

### Search

- Search history for a string
  - `git log -S "string"`

- Search with regex
  - `git log -G "regex"`

- Search in commit messages
  - `git log --grep="pattern"`

- Search all branches
  - `git log --all --grep="pattern"`

---

## Advanced History

### Filtering Commits

- Commits by date range
  - `git log --since="2024-01-01" --until="2024-12-31"`

- Commits touching a path
  - `git log -- <path>`

- Commits by author
  - `git log --author="Name"`

- Merge commits only
  - `git log --merges`

- No merge commits
  - `git log --no-merges`

### Comparing

- Show commits in branch A but not in B
  - `git log A..B`

- Show commits in either branch
  - `git log A...B`

- List files that changed
  - `git diff --name-only <commit1> <commit2>`

- Show commits that changed a file
  - `git log --follow <file>`

---

## Submodules

### Adding Submodules

- Add submodule
  - `git submodule add <url> <path>`

- Initialize after clone
  - `git submodule init`
  - `git submodule update`

- Or in one step
  - `git submodule update --init --recursive`

### Working with Submodules

- Update all submodules
  - `git submodule update --remote`

- Update specific submodule
  - `git submodule update --remote <path>`

- Check submodule status
  - `git submodule status`

- Remove submodule
  - `git submodule deinit <path>`
  - `git rm <path>`

---

## Git Worktree

Work on multiple branches simultaneously without stashing.

- Add worktree
  - `git worktree add <path> <branch>`

- Create new branch in worktree
  - `git worktree add <path> -b <new-branch>`

- List worktrees
  - `git worktree list`

- Remove worktree
  - `git worktree remove <path>`

- Prune stale worktrees
  - `git worktree prune`

---

## Cherry Pick

Apply specific commits from another branch.

- Cherry pick commit
  - `git cherry-pick <commit>`

- Cherry pick multiple commits
  - `git cherry-pick <commit1> <commit2>`

- Cherry pick range
  - `git cherry-pick <commit1>^..<commit2>`

- Cherry pick without committing
  - `git cherry-pick -n <commit>`

- Abort cherry pick
  - `git cherry-pick --abort`

- Continue after conflict
  - `git cherry-pick --continue`

---

## Bisect

Binary search to find which commit introduced a bug.

- Start bisect
  - `git bisect start`

- Mark current as bad
  - `git bisect bad`

- Mark known good commit
  - `git bisect good <commit>`

- Git checks out middle commit, test it:
  - `git bisect good` (if it works)
  - `git bisect bad` (if broken)

- Repeat until found

- End bisect
  - `git bisect reset`

- Automate bisect with script
  - `git bisect run <script>`

---

## Cleaning

### Remove Untracked Files

- Preview what will be removed
  - `git clean -n`

- Remove untracked files
  - `git clean -f`

- Remove untracked directories
  - `git clean -fd`

- Remove ignored files too
  - `git clean -fX`

- Remove everything (untracked + ignored)
  - `git clean -fx`

### Maintenance

- Garbage collection
  - `git gc`

- Aggressive garbage collection
  - `git gc --aggressive --prune=now`

- Check repository integrity
  - `git fsck`

- Optimize repository
  - `git repack -ad`

---

## Aliases

### Useful Aliases to Add

```bash
# Status and log
git config --global alias.st 'status -sb'
git config --global alias.lg 'log --oneline --decorate --graph --all'
git config --global alias.last 'log -1 HEAD --stat'

# Diff
git config --global alias.staged 'diff --staged'
git config --global alias.unstage 'reset HEAD --'

# Branching
git config --global alias.br 'branch'
git config --global alias.co 'checkout'
git config --global alias.cob 'checkout -b'

# Committing
git config --global alias.ci 'commit'
git config --global alias.amend 'commit --amend --no-edit'

# Utilities
git config --global alias.aliases "config --get-regexp '^alias\.'"
git config --global alias.contributors 'shortlog -sn'
```

---

## GitHub CLI

If you have GitHub CLI (`gh`) installed:

### Repository Operations

- Clone repository
  - `gh repo clone <owner>/<repo>`

- Create repository
  - `gh repo create`

- View repository
  - `gh repo view`

### Pull Requests

- Create PR
  - `gh pr create`

- List PRs
  - `gh pr list`

- View PR
  - `gh pr view <number>`

- Checkout PR
  - `gh pr checkout <number>`

- Merge PR
  - `gh pr merge <number>`

### Issues

- Create issue
  - `gh issue create`

- List issues
  - `gh issue list`

- View issue
  - `gh issue view <number>`

---

## Troubleshooting

### Common Issues

**Detached HEAD state**
- You're not on any branch
- Solution: `git checkout <branch>` or `git switch <branch>`

**Merge conflicts**
- Edit files to resolve conflicts
- `git add <files>` then `git commit`

**Accidentally committed to wrong branch**
```bash
git reset HEAD~ --soft
git stash
git checkout <correct-branch>
git stash pop
git add -A
git commit -m "message"
```

**Undo last push (if no one pulled)**
```bash
git reset --hard HEAD~1
git push --force-with-lease
```

**Fix commit message on pushed commit**
```bash
git commit --amend -m "new message"
git push --force-with-lease
```

**Committed sensitive data**
- Use `git filter-branch` or BFG Repo-Cleaner
- Change any exposed credentials
- Consider repository as compromised

**Large files causing issues**
- Use Git LFS (Large File Storage)
- `git lfs install`
- `git lfs track "*.psd"`

### Debugging

- Verbose output
  - `GIT_TRACE=1 git <command>`

- Show configuration loading
  - `GIT_TRACE_SETUP=1 git <command>`

- Check repository health
  - `git fsck --full`

---

## Best Practices

### Commit Messages

- Write clear, descriptive messages
- Use present tense ("Add feature" not "Added feature")
- Keep subject line under 50 characters
- Use body to explain what and why, not how
- Reference issues/tickets when applicable

### Workflow

- Commit early and often (locally)
- Keep commits atomic (one logical change)
- Pull before starting work
- Push regularly to backup work
- Use feature branches
- Keep main/master stable
- Delete merged branches
- Don't commit secrets or sensitive data

### Collaboration

- Communicate about force pushes
- Use `--force-with-lease` instead of `-f`
- Review changes before committing
- Use `.gitignore` properly
- Document workflow in README

### Safety

- Test before pushing
- Use `git status` frequently
- Preview before force operations
- Keep backups of important work
- Use protected branches on GitHub
- Enable 2FA on GitHub account

---

## Conventional Commits

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

## Quick Reference

### Most Common Commands

```bash
# Setup
git clone <url>           # Clone repository
git init                  # Initialize repository

# Status
git status                # Check status
git log --oneline         # View commit history
git diff                  # Show unstaged changes

# Basic workflow
git add <file>            # Stage file
git add -A                # Stage all changes
git commit -m "msg"       # Commit with message
git push                  # Push to remote
git pull                  # Pull from remote

# Branching
git branch                # List branches
git checkout -b <branch>  # Create and switch branch
git switch <branch>       # Switch branch
git merge <branch>        # Merge branch

# Undo
git restore <file>        # Discard changes
git reset HEAD~1          # Undo last commit
git stash                 # Temporarily save changes
git reflog                # View all ref changes

# Remote
git remote -v             # Show remotes
git fetch                 # Fetch updates
git push -u origin <br>   # Push new branch
```

### Quick Tips

- `git status` is the command you should run most often
- If you are unsure: `git status -sb` and `git log --oneline --decorate -5`
- `reflog` can recover mistakes — don't panic
- Use `--force-with-lease` instead of `--force`
- Test dangerous commands with `--dry-run` when available
- Keep commits atomic and descriptive
- Pull before starting work, push regularly
