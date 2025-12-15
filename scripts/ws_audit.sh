#!/usr/bin/env bash
# Simple workstation info collector

set -e

HOSTNAME=$(hostname)
OUTFILE="ws_${HOSTNAME}_info.txt"

echo "Collecting info for $HOSTNAME..."

{
  echo "===== WORKSTATION INFO ====="
  echo "Hostname: $HOSTNAME"
  echo "Date: $(date)"
  echo

  echo "=== OS & Kernel ==="
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS: $PRETTY_NAME"
  else
    echo "OS: (no /etc/os-release, unknown)"
  fi
  echo "Kernel: $(uname -r)"
  echo "Uptime: $(uptime -p || uptime)"
  echo

  echo "=== Hostname & Domain ==="
  echo "Short hostname: $(hostname)"
  echo "DNS domain: $(hostname -d 2>/dev/null || echo 'N/A')"
  echo "FQDN: $(hostname -f 2>/dev/null || echo 'N/A')"

  if grep -q '^search' /etc/resolv.conf 2>/dev/null; then
    echo "Search domains (resolv.conf): $(grep '^search' /etc/resolv.conf | cut -d ' ' -f2-)"
  else
    echo "Search domains: (none in resolv.conf)"
  fi
  echo

  echo "=== Network ==="
  if command -v ip >/dev/null 2>&1; then
    ip -brief addr show | sed 's/^/  /'
  else
    echo "  'ip' command not found"
  fi
  echo

  echo "=== CPU ==="
  if command -v lscpu >/dev/null 2>&1; then
    CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/Model name/ {print $2}' | sed 's/^[ \t]*//')
    CPU_CORES=$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/ {print $2}' | sed 's/^[ \t]*//')
    echo "CPU model: ${CPU_MODEL:-unknown}"
    echo "CPU cores: ${CPU_CORES:-unknown}"
  else
    echo "CPU info: lscpu not available"
  fi
  echo

  echo "=== RAM ==="
  if command -v free >/dev/null 2>&1; then
    free -h | sed 's/^/  /'
  else
    echo "  'free' command not available"
  fi
  echo

  echo "=== Disks & Mounts ==="
  if command -v lsblk >/devnull 2>&1; then
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | sed 's/^/  /'
  else
    echo "  'lsblk' command not available"
  fi
  echo

  echo "=== GPU (if any) ==="
  if command -v lspci >/dev/null 2>&1; then
    lspci | grep -iE 'vga|3d|nvidia' || echo "  (no dedicated GPU detected)"
  else
    echo "  'lspci' not available"
  fi
  echo

  echo "=== Local Human Users (UID >= 1000) ==="
  awk -F: '$3 >= 1000 && $3 < 65534 {printf "  %-15s UID=%s GID=%s HOME=%s SHELL=%s\n", $1,$3,$4,$6,$7}' /etc/passwd
  echo

  echo "=== Sudo Users and Their Groups ==="
  SUDO_MEMBERS=""
  if getent group sudo >/dev/null 2>&1; then
    SUDO_LINE=$(getent group sudo)
    SUDO_MEMBERS=$(echo "$SUDO_LINE" | awk -F: '{print $4}')
    if [ -z "$SUDO_MEMBERS" ]; then
      echo "  Group 'sudo' exists but has no listed members."
    else
      echo "  Members of 'sudo': $SUDO_MEMBERS"
      echo
      for u in $(echo "$SUDO_MEMBERS" | tr ',' ' '); do
        if id "$u" >/dev/null 2>&1; then
          echo "  User: $u"
          id "$u" | sed 's/^/    /'
          echo
        else
          echo "  User: $u (listed in sudo group, but no local account found)"
          echo
        fi
      done
    fi
  else
    echo "  Group 'sudo' does not exist on this system."
  fi
  echo

  echo "=== User Cron Jobs (per-user crontabs) ==="
  ANY_USER_CRON=0
  # Loop over all "human" users (UID >= 1000, < 65534)
  while IFS=: read -r uname _ uid _ _ home _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
      if crontab -u "$uname" -l >/tmp/.ws_cron_$$ 2>/dev/null; then
        if [ $ANY_USER_CRON -eq 0 ]; then
          ANY_USER_CRON=1
        fi
        echo "  --- User: $uname ---"
        sed 's/^/    /' /tmp/.ws_cron_$$
        echo
        rm -f /tmp/.ws_cron_$$
      fi
    fi
  done < /etc/passwd

  if [ $ANY_USER_CRON -eq 0 ]; then
    echo "  No per-user crontabs found for local human users."
  fi
  echo

  echo "=== Non-default System Cron Jobs (/etc/crontab and /etc/cron.d) ==="
  SYS_CRON_TEMP=/tmp/.ws_syscron_$$
  : > "$SYS_CRON_TEMP"

  # We consider as "interesting" any cron line where:
  #   - the user field is NOT root
  #   OR
  #   - the command contains /home, /usr/local, /opt, /srv, /data
  FILES_TO_CHECK=""
  [ -f /etc/crontab ] && FILES_TO_CHECK="/etc/crontab"
  if [ -d /etc/cron.d ]; then
    FILES_TO_CHECK="$FILES_TO_CHECK /etc/cron.d/*"
  fi

  for f in $FILES_TO_CHECK; do
    [ -f "$f" ] || continue
    awk '
      $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/ {
        # /etc/crontab and /etc/cron.d format:
        # m h dom mon dow user command...
        if (NF >= 7) {
          user = $6
          cmd = ""
          for (i = 7; i <= NF; i++) {
            cmd = cmd " " $i
          }
          if (user != "root" || cmd ~ /(\/home\/|\/usr\/local\/|\/opt\/|\/srv\/|\/data\/)/) {
            print FILENAME ":" $0
          }
        }
      }
    ' "$f" >> "$SYS_CRON_TEMP"
  done

  if [ -s "$SYS_CRON_TEMP" ]; then
    sed 's/^/  /' "$SYS_CRON_TEMP"
  else
    echo "  No non-default-looking system cron jobs found."
  fi

  rm -f "$SYS_CRON_TEMP"
  echo

  echo "===== END OF REPORT ====="
} > "$OUTFILE"

echo "Done. Wrote: $OUTFILE"
