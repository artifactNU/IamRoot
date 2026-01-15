# Tmux Cheat Sheet

Quick reference for tmux terminal multiplexer operations and commands.

---

## Table of Contents

- [Basics](#basics)
- [Sessions](#sessions)
- [Windows](#windows)
- [Panes](#panes)
- [Copy Mode](#copy-mode)
- [Buffers](#buffers)
- [Configuration](#configuration)
- [Command Mode](#command-mode)
- [Scripting & Automation](#scripting--automation)
- [Key Bindings](#key-bindings)
- [Useful Plugins](#useful-plugins)
- [Troubleshooting](#troubleshooting)
- [Quick Reference](#quick-reference)

---

## Basics

### Prefix Key

Default prefix: `Ctrl+b` (press `Ctrl` and `b` together, then release both)

Most tmux commands require pressing the prefix first, then the command key.

### Starting Tmux

- Start new session  
  `tmux`

- Start named session  
  `tmux new -s <session-name>`

- List sessions  
  `tmux ls`

- Attach to last session  
  `tmux attach` or `tmux a`

- Attach to specific session  
  `tmux attach -t <session-name>`

- Kill session  
  `tmux kill-session -t <session-name>`

- Kill all sessions  
  `tmux kill-server`

### Help

- Show all key bindings  
  `Prefix + ?`

- List all commands  
  `tmux list-commands`

---

## Sessions

Sessions are the top-level containers in tmux. They persist even if you disconnect.

- New session (from within tmux)  
  `Prefix + :new`

- Detach from session  
  `Prefix + d`

- Switch between sessions  
  `Prefix + s` (interactive list)

- Rename current session  
  `Prefix + $`

- Next session  
  `Prefix + )`

- Previous session  
  `Prefix + (`

- List sessions  
  `Prefix + s`

### Session Management Commands

- Create new session  
  `:new -s <name>`

- Rename session  
  `:rename-session <name>`

- Kill session  
  `:kill-session`

---

## Windows

Windows are like tabs in a terminal. Each session can have multiple windows.

### Basic Window Operations

- Create new window  
  `Prefix + c`

- Close current window  
  `Prefix + &` or `exit`

- Rename window  
  `Prefix + ,`

- List windows  
  `Prefix + w`

### Navigation

- Next window  
  `Prefix + n`

- Previous window  
  `Prefix + p`

- Last active window  
  `Prefix + l`

- Select window by number  
  `Prefix + 0-9`

- Find window  
  `Prefix + f`

### Window Management

- Move window left  
  `Prefix + :swap-window -t -1`

- Move window right  
  `Prefix + :swap-window -t +1`

- Reorder windows  
  `Prefix + :move-window -r`

- Kill window  
  `Prefix + :kill-window`

---

## Panes

Panes divide windows into multiple terminal views.

### Creating Panes

- Split horizontally (top/bottom)  
  `Prefix + "`

- Split vertically (left/right)  
  `Prefix + %`

### Navigation

- Navigate between panes  
  `Prefix + arrow keys`

- Cycle through panes  
  `Prefix + o`

- Go to last active pane  
  `Prefix + ;`

- Show pane numbers  
  `Prefix + q`

- Select pane by number  
  `Prefix + q` then type number

### Layout & Sizing

- Toggle pane zoom (fullscreen)  
  `Prefix + z`

- Resize pane down  
  `Prefix + Ctrl+arrow down`

- Resize pane up  
  `Prefix + Ctrl+arrow up`

- Resize pane left  
  `Prefix + Ctrl+arrow left`

- Resize pane right  
  `Prefix + Ctrl+arrow right`

- Cycle through layouts  
  `Prefix + spacebar`

- Even horizontal layout  
  `Prefix + Alt+1`

- Even vertical layout  
  `Prefix + Alt+2`

### Pane Management

- Close current pane  
  `Prefix + x` or `exit`

- Break pane into new window  
  `Prefix + !`

- Move pane to another window  
  `Prefix + :join-pane -t <window>`

- Swap panes  
  `Prefix + {` (swap with previous)  
  `Prefix + }` (swap with next)

- Display pane info  
  `Prefix + i`

- Synchronize panes (send input to all)  
  `Prefix + :setw synchronize-panes on`

---

## Copy Mode

Copy mode allows scrolling and text selection using keyboard.

### Entering Copy Mode

- Enter copy mode  
  `Prefix + [`

- Exit copy mode  
  `q` or `Esc`

### Navigation (vi mode)

- Move cursor  
  `h, j, k, l` (left, down, up, right)

- Word forward  
  `w`

- Word backward  
  `b`

- Start of line  
  `0`

- End of line  
  `$`

- Half page down  
  `Ctrl+d`

- Half page up  
  `Ctrl+u`

- Page down  
  `Ctrl+f`

- Page up  
  `Ctrl+b`

- Go to top  
  `g`

- Go to bottom  
  `G`

### Selecting & Copying (vi mode)

- Start selection  
  `Space`

- Copy selection  
  `Enter`

- Clear selection  
  `Esc`

- Rectangle selection  
  `Ctrl+v` then select

### Searching

- Search forward  
  `/`

- Search backward  
  `?`

- Next occurrence  
  `n`

- Previous occurrence  
  `N`

---

## Buffers

Buffers store copied text.

- Paste most recent buffer  
  `Prefix + ]`

- Choose buffer to paste  
  `Prefix + =`

- List all buffers  
  `Prefix + :list-buffers`

- Show buffer content  
  `Prefix + :show-buffer`

- Save buffer to file  
  `Prefix + :save-buffer <file>`

- Delete buffer  
  `Prefix + :delete-buffer -b <buffer-number>`

---

## Configuration

Configuration file: `~/.tmux.conf`

### Basic Configuration Examples

```bash
# Change prefix to Ctrl+a
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Increase scrollback buffer
set -g history-limit 10000

# Enable vi mode in copy mode
setw -g mode-keys vi

# Faster command sequences
set -g escape-time 0

# Enable 256 colors
set -g default-terminal "screen-256color"

# Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Split panes with | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Switch panes using Alt+arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D
```

### Reload Configuration

- Reload config file  
  `tmux source-file ~/.tmux.conf`

- Or from within tmux  
  `Prefix + :source-file ~/.tmux.conf`

---

## Command Mode

Enter command mode with `Prefix + :`

### Common Commands

- Create new window with name  
  `:neww -n <name>`

- Rename window  
  `:rename-window <name>`

- Move window  
  `:movew -t <target>`

- Set option  
  `:set -g <option> <value>`

- Set window option  
  `:setw <option> <value>`

- Show options  
  `:show-options -g`

- Show window options  
  `:show-window-options -g`

---

## Scripting & Automation

### Session Scripts

Create a session with multiple windows:

```bash
#!/bin/bash
SESSION="dev"

# Create session
tmux new-session -d -s $SESSION

# Window 1: Editor
tmux rename-window -t $SESSION:1 'editor'
tmux send-keys -t $SESSION:1 'cd ~/project && vim' C-m

# Window 2: Server
tmux new-window -t $SESSION:2 -n 'server'
tmux send-keys -t $SESSION:2 'cd ~/project && npm start' C-m

# Window 3: Git
tmux new-window -t $SESSION:3 -n 'git'
tmux send-keys -t $SESSION:3 'cd ~/project && git status' C-m

# Attach to session
tmux attach-session -t $SESSION
```

### Sending Commands

- Send command to window  
  `tmux send-keys -t <session>:<window> '<command>' C-m`

- Send to specific pane  
  `tmux send-keys -t <session>:<window>.<pane> '<command>' C-m`

### Capture Pane Output

- Capture visible pane  
  `tmux capture-pane -p`

- Capture to file  
  `tmux capture-pane -p -t <target> > output.txt`

---

## Key Bindings

### Viewing Bindings

- List all key bindings  
  `Prefix + ?`

- List bindings in command mode  
  `tmux list-keys`

### Custom Bindings

```bash
# Bind key to command
bind <key> <command>

# Bind key without prefix
bind -n <key> <command>

# Unbind key
unbind <key>

# Example: bind r to reload config
bind r source-file ~/.tmux.conf \; display "Reloaded!"
```

---

## Useful Plugins

### TPM (Tmux Plugin Manager)

Install TPM:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Add to `~/.tmux.conf`:

```bash
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Initialize TPM (keep at bottom)
run '~/.tmux/plugins/tpm/tpm'
```

- Install plugins: `Prefix + I`
- Update plugins: `Prefix + U`
- Uninstall: `Prefix + Alt+u`

### Popular Plugins

- **tmux-resurrect** — Save/restore sessions
- **tmux-continuum** — Automatic session saving
- **tmux-yank** — Better copy/paste
- **tmux-pain-control** — Better pane navigation
- **tmux-sensible** — Sensible defaults

---

## Troubleshooting

### Colors Not Working

- Check `$TERM` variable  
  `echo $TERM`

- Set in `~/.tmux.conf`  
  `set -g default-terminal "screen-256color"`

- Or with true color support  
  `set -g default-terminal "tmux-256color"`

### Mouse Not Working

- Enable mouse support  
  `set -g mouse on`

### Copy/Paste Issues

- On Linux, install `xclip` or `xsel`  
  `sudo apt install xclip`

- Configure copy to clipboard:

```bash
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
```

### Can't Attach to Session

- Check if session exists  
  `tmux ls`

- Kill zombie sessions  
  `tmux kill-server`

### Prefix Key Not Working

- Check key bindings  
  `tmux list-keys | grep prefix`

- Check config file for conflicts

---

## Quick Reference

### Essential Commands

| Action | Command |
|--------|---------|
| New session | `tmux new -s <name>` |
| Attach session | `tmux a -t <name>` |
| List sessions | `tmux ls` |
| Detach | `Prefix + d` |
| New window | `Prefix + c` |
| Split horizontal | `Prefix + "` |
| Split vertical | `Prefix + %` |
| Navigate panes | `Prefix + arrows` |
| Close pane | `Prefix + x` |
| Zoom pane | `Prefix + z` |
| Copy mode | `Prefix + [` |
| Paste | `Prefix + ]` |
| Help | `Prefix + ?` |

### Status Line Indicators

- `[0]` — Session name
- `0:bash*` — Window number:name (asterisk = active)
- `-` — Last window indicator
- `#` — Activity in window
- `!` — Bell in window
- `~` — Silence in window
- `M` — Marked pane
- `Z` — Zoomed pane

### Special Variables

Use in configuration or scripts:

- `#{session_name}` — Current session name
- `#{window_name}` — Current window name
- `#{pane_current_path}` — Current pane path
- `#{pane_pid}` — Pane process ID
- `#{host}` — Hostname

---

## Tips & Best Practices

### Workflow Tips

1. **Name your sessions** — Easier to remember and attach
2. **Use zoom mode** — `Prefix + z` for focused work
3. **Learn copy mode** — Essential for scrollback review
4. **Script session creation** — Automate your workspace setup
5. **Use mouse mode** — For easier pane resizing and selection

### Common Workflows

**Development Setup:**

```bash
# Terminal 1: Editor
# Terminal 2: Server/logs
# Terminal 3: Tests
# Terminal 4: Git/shell
```

**System Administration:**

```bash
# Window 1: SSH to server
# Window 2: Logs monitoring
# Window 3: Backup scripts
```

### Recommended Config Additions

```bash
# Vi-like pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resizing panes
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Quick window selection
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3

# Copy to system clipboard (Linux)
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'

# Don't exit copy mode after selection
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe 'xclip -in -selection clipboard'
```

---

## Additional Resources

- Official documentation: `man tmux`
- GitHub: https://github.com/tmux/tmux
- Wiki: https://github.com/tmux/tmux/wiki

---

