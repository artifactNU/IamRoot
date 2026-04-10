# systemd Cheat Sheet

Reference for managing services, units, timers, and logs with systemd and journald.

---

## Table of Contents

- [Service Management](#service-management)
- [Listing Units](#listing-units)
- [Inspecting Units](#inspecting-units)
- [Targets (Runlevels)](#targets-runlevels)
- [Timers](#timers)
- [Journal & Logs](#journal--logs)
- [User Units](#user-units)
- [Analyzing Boot Performance](#analyzing-boot-performance)
- [Writing Unit Files](#writing-unit-files)
- [Troubleshooting](#troubleshooting)

---

## Service Management

- Start a service  
  `systemctl start <unit>`

- Stop a service  
  `systemctl stop <unit>`

- Restart a service (stop + start)  
  `systemctl restart <unit>`

- Reload configuration without restarting  
  `systemctl reload <unit>`  
  Only works if the service supports it (e.g., nginx, sshd).

- Reload or restart (prefers reload if supported)  
  `systemctl reload-or-restart <unit>`

- Check service status  
  `systemctl status <unit>`  
  Shows active state, last log lines, and PID.

- Enable a service at boot  
  `systemctl enable <unit>`

- Enable and start immediately  
  `systemctl enable --now <unit>`

- Disable a service from starting at boot  
  `systemctl disable <unit>`

- Disable and stop immediately  
  `systemctl disable --now <unit>`

- Mask a unit (prevent any start, even manually)  
  `systemctl mask <unit>`  
  Symlinks the unit file to `/dev/null`. Use to hard-block a service.

- Unmask a unit  
  `systemctl unmask <unit>`

- Send a signal to a service  
  `systemctl kill <unit>`  
  Defaults to `SIGTERM`. Use `--signal=SIGKILL` to force.

- Reload systemd manager configuration (after editing unit files)  
  `systemctl daemon-reload`

---

## Listing Units

- List all active units  
  `systemctl`

- List all units (including inactive)  
  `systemctl list-units --all`

- List only services  
  `systemctl list-units --type=service`

- List failed units  
  `systemctl list-units --state=failed`

- List enabled/disabled unit files  
  `systemctl list-unit-files`

- List unit files of a specific type  
  `systemctl list-unit-files --type=timer`

- List units that depend on a given unit  
  `systemctl list-dependencies <unit>`

- List reverse dependencies (what requires this unit)  
  `systemctl list-dependencies --reverse <unit>`

---

## Inspecting Units

- Show full unit file  
  `systemctl cat <unit>`

- Show effective properties of a running unit  
  `systemctl show <unit>`

- Show a specific property  
  `systemctl show <unit> --property=MainPID`

- Find the unit file on disk  
  `systemctl show <unit> --property=FragmentPath`

- Edit a unit file (creates an override drop-in)  
  `systemctl edit <unit>`  
  Creates `/etc/systemd/system/<unit>.d/override.conf`. Preferred over editing the original.

- Edit the full unit file directly  
  `systemctl edit --full <unit>`

- Verify unit file syntax  
  `systemd-analyze verify <unit-file>`

---

## Targets (Runlevels)

Targets replace SysV runlevels. Common equivalents:

| SysV Runlevel | systemd Target         |
|---------------|------------------------|
| 0             | `poweroff.target`      |
| 1             | `rescue.target`        |
| 3             | `multi-user.target`    |
| 5             | `graphical.target`     |
| 6             | `reboot.target`        |

- Show current default target  
  `systemctl get-default`

- Set default target  
  `systemctl set-default multi-user.target`

- Switch to a target immediately (without rebooting)  
  `systemctl isolate rescue.target`  
  ⚠ Only targets with `AllowIsolate=yes` can be used here.

- Reach rescue mode  
  `systemctl rescue`

- Power off  
  `systemctl poweroff`

- Reboot  
  `systemctl reboot`

---

## Timers

Timers are the systemd equivalent of cron jobs. Each timer needs a matching `.service` unit.

- List all timers and their next trigger time  
  `systemctl list-timers`

- List all timers including inactive  
  `systemctl list-timers --all`

### Timer Unit Directives

```ini
[Timer]
# Run at a fixed time (calendar expression)
OnCalendar=*-*-* 02:00:00       # daily at 02:00
OnCalendar=Mon *-*-* 08:00:00   # every Monday at 08:00

# Run relative to system boot or service activation
OnBootSec=10min
OnUnitActiveSec=1h

# Persist missed runs (e.g., if system was off)
Persistent=true

# Run the matching .service unit, or specify explicitly
Unit=myjob.service
```

Common `OnCalendar` shorthands:

| Shorthand  | Equivalent                  |
|------------|-----------------------------|
| `hourly`   | `*-*-* *:00:00`             |
| `daily`    | `*-*-* 00:00:00`            |
| `weekly`   | `Mon *-*-* 00:00:00`        |
| `monthly`  | `*-*-01 00:00:00`           |

- Validate a calendar expression  
  `systemd-analyze calendar "Mon *-*-* 08:00:00"`

---

## Journal & Logs

journald is the logging backend for systemd. Logs are binary and queried with `journalctl`.

- Show all logs (newest last)  
  `journalctl`

- Follow live log output  
  `journalctl -f`

- Show logs for a specific unit  
  `journalctl -u <unit>`

- Follow logs for a unit  
  `journalctl -f -u <unit>`

- Show logs since last boot  
  `journalctl -b`

- Show logs from a previous boot  
  `journalctl -b -1`  
  Use `-b -2` for two boots ago, etc.

- List available boots  
  `journalctl --list-boots`

- Show logs since a time  
  `journalctl --since "2026-03-01 00:00:00"`

- Show logs in a time range  
  `journalctl --since "2026-03-01" --until "2026-03-02"`

- Show only error-level and above  
  `journalctl -p err`  
  Priority levels: `emerg alert crit err warning notice info debug`

- Show kernel messages (like dmesg)  
  `journalctl -k`

- Output as JSON  
  `journalctl -u <unit> -o json-pretty`

- Show disk usage of the journal  
  `journalctl --disk-usage`

- Vacuum old logs by size  
  `journalctl --vacuum-size=500M`

- Vacuum old logs by time  
  `journalctl --vacuum-time=30d`

---

## User Units

Each user can manage their own units without `sudo`. User units live in `~/.config/systemd/user/`.

- All `systemctl` commands work with `--user`  
  `systemctl --user start <unit>`  
  `systemctl --user enable --now <unit>`  
  `systemctl --user status <unit>`

- Show user journal  
  `journalctl --user -u <unit>`

- Enable lingering (keep user units running after logout)  
  `loginctl enable-linger <username>`

---

## Analyzing Boot Performance

- Show overall boot time summary  
  `systemd-analyze`

- Show time each unit took to start  
  `systemd-analyze blame`

- Show critical chain (longest path through the dependency graph)  
  `systemd-analyze critical-chain`

- Show critical chain for a specific unit  
  `systemd-analyze critical-chain <unit>`

- Generate an SVG of the boot sequence  
  `systemd-analyze plot > boot.svg`

- Check unit file for errors  
  `systemd-analyze verify <unit-file>`

---

## Writing Unit Files

Unit files live in:

| Path                              | Purpose                                  |
|-----------------------------------|------------------------------------------|
| `/lib/systemd/system/`            | Vendor / package-installed units         |
| `/etc/systemd/system/`            | Site-local overrides and custom units    |
| `~/.config/systemd/user/`         | Per-user units                           |
| `/etc/systemd/system/<unit>.d/`   | Drop-in override directory               |

### Minimal Service Unit

```ini
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/myapp --config /etc/myapp/config.toml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### Common `[Unit]` Directives

| Directive       | Meaning                                              |
|-----------------|------------------------------------------------------|
| `Description=`  | Human-readable name shown in status output           |
| `After=`        | Start after these units (ordering, not dependency)   |
| `Requires=`     | Hard dependency — fails if dependency fails          |
| `Wants=`        | Soft dependency — starts it but does not fail        |
| `ConditionPathExists=` | Only start if a path exists               |

### Common `[Service]` Directives

| Directive            | Meaning                                                           |
|----------------------|-------------------------------------------------------------------|
| `Type=simple`        | Default. Process started by `ExecStart` is the main process      |
| `Type=forking`       | Service forks; parent exits. Use `PIDFile=` to track child       |
| `Type=oneshot`       | Runs to completion; useful for scripts                           |
| `Type=notify`        | Service signals readiness via `sd_notify()`                      |
| `ExecStart=`         | Command to start the service                                     |
| `ExecStop=`          | Command to stop (optional; default is SIGTERM)                   |
| `ExecReload=`        | Command to reload config                                         |
| `Restart=`           | When to restart: `no on-success on-failure on-abnormal always`   |
| `RestartSec=`        | Delay before restarting                                          |
| `User=` / `Group=`   | Run as this user/group                                           |
| `WorkingDirectory=`  | Set working directory                                            |
| `EnvironmentFile=`   | Load env vars from a file                                        |
| `StandardOutput=`    | Where to send stdout: `journal` `syslog` `null` `file:<path>`    |

### Hardening Directives (Sandboxing)

```ini
[Service]
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/myapp
CapabilityBoundingSet=
```

Run `systemd-analyze security <unit>` to get a security score and improvement suggestions.

---

## Troubleshooting

- A service failed to start — check status and logs  
  `systemctl status <unit>`  
  `journalctl -u <unit> -n 50 --no-pager`

- Service not found  
  `systemctl cat <unit>` — confirms the file exists and is valid  
  `systemctl daemon-reload` — required after adding or editing unit files

- Changes to unit file not taking effect  
  `systemctl daemon-reload` then `systemctl restart <unit>`

- Service keeps restarting  
  `journalctl -u <unit> -f` — watch live  
  Check `Restart=` and `RestartSec=` in the unit; use `systemctl stop` to break the loop

- Unit masked unexpectedly  
  `systemctl unmask <unit>`  
  Check `/etc/systemd/system/<unit>` for a symlink to `/dev/null`

- Show all failed units at a glance  
  `systemctl --failed`

- Dependency problems (unit won't start due to a dependency)  
  `systemctl list-dependencies <unit>`  
  `journalctl -b -p err` — find errors since last boot

- Check security exposure of a unit  
  `systemd-analyze security <unit>`
