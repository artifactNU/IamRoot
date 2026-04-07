# Cron Cheat Sheet

Reference for scheduling recurring commands with `cron` and `crontab`.

---

## Table of Contents

- [Cron Basics](#cron-basics)
- [Crontab Management](#crontab-management)
- [Cron Time Format](#cron-time-format)
- [Scheduling Patterns](#scheduling-patterns)
- [Special Strings](#special-strings)
- [Environment & Shell Behavior](#environment--shell-behavior)
- [Logging & Output](#logging--output)
- [System-Wide Cron Locations](#system-wide-cron-locations)
- [Cron Security](#cron-security)
- [Troubleshooting](#troubleshooting)

---

## Cron Basics

- `cron` is a daemon that executes scheduled jobs.
- Per-user jobs are managed through `crontab`.
- Jobs run in a non-interactive shell with a minimal environment.
- Always use absolute paths in cron commands.

---

## Crontab Management

- Edit current user's crontab  
  `crontab -e`

- List current user's crontab  
  `crontab -l`

- Remove current user's crontab  
  `crontab -r`  
  Dangerous: removes all jobs for that user.

- Prompt before removing crontab (if supported)  
  `crontab -i -r`

- Edit another user's crontab (root)  
  `sudo crontab -u <user> -e`

- List another user's crontab (root)  
  `sudo crontab -u <user> -l`

---

## Cron Time Format

A cron entry has 5 schedule fields plus a command:

`* * * * * <command>`

| Field | Meaning | Allowed Values |
|------|---------|----------------|
| 1 | Minute | `0-59` |
| 2 | Hour | `0-23` |
| 3 | Day of month | `1-31` |
| 4 | Month | `1-12` or `jan-dec` |
| 5 | Day of week | `0-7` (`0` or `7` = Sunday, or `sun-sat`) |

Common operators:

- `*` every value
- `,` list: `1,15,30`
- `-` range: `1-5`
- `/` step: `*/10`

---

## Scheduling Patterns

- Every minute  
  `* * * * * /path/to/job.sh`

- Every 5 minutes  
  `*/5 * * * * /path/to/job.sh`

- Hourly at minute 0  
  `0 * * * * /path/to/job.sh`

- Daily at 02:30  
  `30 2 * * * /path/to/job.sh`

- Weekdays at 08:00  
  `0 8 * * 1-5 /path/to/job.sh`

- First day of month at 03:15  
  `15 3 1 * * /path/to/job.sh`

- Every Sunday at midnight  
  `0 0 * * 0 /path/to/job.sh`

- Run every 10 minutes during business hours  
  `*/10 9-17 * * 1-5 /path/to/job.sh`

---

## Special Strings

Most cron implementations support shortcuts:

- `@reboot` run once at boot
- `@yearly` once per year
- `@monthly` once per month
- `@weekly` once per week
- `@daily` once per day
- `@hourly` once per hour

Examples:

- Start a monitor at boot  
  `@reboot /usr/local/bin/start-monitor.sh`

- Daily cleanup  
  `@daily /usr/local/bin/cleanup.sh`

---

## Environment & Shell Behavior

Cron does not load your interactive shell profile by default.

Useful crontab variables:

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=admin@example.com
CRON_TZ=UTC
```

Best practices:

- Use full paths for commands (`/usr/bin/find`, `/usr/bin/python3`)
- Quote arguments carefully
- Redirect output explicitly
- Source environment files only when needed

Example with environment setup:

```cron
0 1 * * * . /etc/profile && /opt/app/bin/nightly-job.sh >> /var/log/nightly-job.log 2>&1
```

---

## Logging & Output

- Send stdout and stderr to a log file  
  `*/15 * * * * /opt/scripts/task.sh >> /var/log/task.log 2>&1`

- Discard all output  
  `*/15 * * * * /opt/scripts/task.sh > /dev/null 2>&1`

- Split stdout and stderr  
  `*/15 * * * * /opt/scripts/task.sh >> /var/log/task.out 2>> /var/log/task.err`

On many Linux systems, cron logs are in one of:

- `/var/log/syslog`
- `/var/log/cron`
- `journalctl -u cron`
- `journalctl -u crond`

---

## System-Wide Cron Locations

- `/etc/crontab` (system crontab format includes user field)
- `/etc/cron.d/` (package/app-specific schedules)
- `/etc/cron.hourly/`
- `/etc/cron.daily/`
- `/etc/cron.weekly/`
- `/etc/cron.monthly/`

Format in `/etc/crontab` and `/etc/cron.d/*`:

`* * * * * <user> <command>`

Example:

```cron
15 2 * * * root /usr/local/sbin/rotate-backups.sh
```

---

## Cron Security

- Restrict who can use cron with:
  - `/etc/cron.allow`
  - `/etc/cron.deny`
- Prefer dedicated service accounts over `root` when possible.
- Keep script files non-writable by untrusted users.
- Use full paths to avoid `PATH` hijacking.

---

## Troubleshooting

- Job did not run:
  - Check daemon status: `systemctl status cron` or `systemctl status crond`
  - Check cron logs (`syslog`, `cron`, or `journalctl`)
  - Verify crontab syntax with `crontab -l`

- Command works manually but fails in cron:
  - Missing environment variables (`PATH`, `HOME`, credentials)
  - Different shell (`sh` vs `bash`)
  - Relative paths failing

- `%` character causes unexpected behavior:
  - `%` is treated as newline by cron
  - Escape as `\%` when needed

- Overlapping runs:
  - Use file locks to prevent concurrency
  - Example: `flock -n /tmp/job.lock /opt/scripts/job.sh`

- Time appears wrong:
  - Check system timezone and `CRON_TZ`
  - Watch DST transitions for local-time schedules

---

## Quick Validation Pattern

Use this pattern during setup:

```cron
* * * * * date >> /tmp/cron-test.log 2>&1
```

If `/tmp/cron-test.log` updates every minute, scheduler and logging are working.
