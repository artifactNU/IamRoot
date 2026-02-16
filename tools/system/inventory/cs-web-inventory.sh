#!/usr/bin/env bash
# cs-web-inventory.sh
# Purpose: Read-only web server inventory for CentOS Stream webservers
# Output: cs_web_inventory_<hostname>_<timestamp>.md
# NOTE:
# Informational commands are allowed to fail (|| true) to avoid false exits under `set -e`, especially on RHEL.


set -euo pipefail

HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
TS="$(date -Is | tr ':' '-')"
OUTFILE="cs_web_inventory_${HOSTNAME}_${TS}.md"

have() { command -v "$1" >/dev/null 2>&1; }

md_h1() { echo "# $*"; echo; }
md_h2() { echo "## $*"; echo; }
md_h3() { echo "### $*"; echo; }
md_h4() { echo "#### $*"; echo; }
md_kv() { echo "- **$1:** $2"; }
md_code() { echo '```'; cat; echo '```'; echo; }
md_note() { echo "> $*"; echo; }

# OS detection
OS_PRETTY="unknown"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_PRETTY="${PRETTY_NAME:-unknown}"
fi

# --- Extractors ---

apache_conf_files() {
  if [ -d /etc/httpd ]; then
    find /etc/httpd -type f -name "*.conf" -print0 2>/dev/null
  fi
}

nginx_conf_files() {
  if [ -d /etc/nginx ]; then
    find /etc/nginx -type f -name "*.conf" -print0 2>/dev/null
  fi
}

apache_domains() {
  local any=0
  local f line
  local results=()

  while IFS= read -r -d '' f; do
    any=1
    while IFS= read -r line; do
      line="${line%;}"
      [ -n "$line" ] && results+=("$line")
    done < <(
      awk '
        /^[[:space:]]*#/ {next}
        /^[[:space:]]*ServerName[[:space:]]+/ {print $2}
        /^[[:space:]]*ServerAlias[[:space:]]+/ {
          for (i=2; i<=NF; i++) {
            if ($i !~ /^#/) print $i
          }
        }
      ' "$f" 2>/dev/null
    )
  done < <(apache_conf_files)

  [ "$any" -eq 0 ] && return 1
  printf '%s\n' "${results[@]}" | sort -u
}

nginx_domains() {
  local any=0
  local f line
  local results=()

  while IFS= read -r -d '' f; do
    any=1
    while IFS= read -r line; do
      line="${line%;}"
      [ -n "$line" ] && results+=("$line")
    done < <(
      awk '
        /^[[:space:]]*#/ {next}
        /^[[:space:]]*server_name[[:space:]]+/ {
          for (i=2; i<=NF; i++) {
            if ($i !~ /^#/) print $i
          }
        }
      ' "$f" 2>/dev/null
    )
  done < <(nginx_conf_files)

  [ "$any" -eq 0 ] && return 1
  printf '%s\n' "${results[@]}" | sort -u
}

archive_latest_files() {
  local d base max n
  for d in /etc/letsencrypt/archive/*; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    max=""
    for n in "$d"/cert*.pem; do
      [ -f "$n" ] || continue
      n="${n##*/cert}"
      n="${n%.pem}"
      if [ -z "$max" ] || [ "$n" -gt "$max" ]; then
        max="$n"
      fi
    done
    if [ -n "$max" ]; then
      echo "# $base (latest: $max)"
      printf '%s\n' \
        "$d/cert${max}.pem" \
        "$d/chain${max}.pem" \
        "$d/fullchain${max}.pem" \
        "$d/privkey${max}.pem"
    fi
  done
}

live_cert_files() {
  if [ -d /etc/letsencrypt/live ]; then
    find /etc/letsencrypt/live -maxdepth 2 \( -type l -o -type f \) \
      \( -name "*.crt" -o -name "*.pem" \) -printf '%p -> %l\n' 2>/dev/null
  fi
}

certbot_renewal_summary() {
  local f
  local any=0
  for f in /etc/letsencrypt/renewal/*.conf; do
    [ -f "$f" ] || continue
    any=1
    echo "- **$(basename "$f")**"
    awk -F= '
      /^[[:space:]]*domains[[:space:]]*=/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        print "  - domains: " $2
      }
      /^[[:space:]]*authenticator[[:space:]]*=/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        print "  - authenticator: " $2
      }
      /^[[:space:]]*installer[[:space:]]*=/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
        print "  - installer: " $2
      }
    ' "$f"
  done

  [ "$any" -eq 0 ] && return 1
  return 0
}

cron_hits_for_renewal() {
  local paths=(
    /etc/crontab
    /etc/cron.d
    /etc/cron.daily
    /etc/cron.weekly
    /etc/cron.monthly
    /var/spool/cron
    /var/spool/cron/crontabs
  )
  local found=0
  for p in "${paths[@]}"; do
    if [ -f "$p" ]; then
      if grep -Eiq 'certbot|letsencrypt|acme\.sh' "$p" 2>/dev/null; then
        found=1
        echo "# $p"
        grep -Ein 'certbot|letsencrypt|acme\.sh' "$p" 2>/dev/null
      fi
    elif [ -d "$p" ]; then
      if grep -ERiq 'certbot|letsencrypt|acme\.sh' "$p" 2>/dev/null; then
        found=1
        echo "# $p"
        grep -ERin 'certbot|letsencrypt|acme\.sh' "$p" 2>/dev/null
      fi
    fi
  done

  [ "$found" -eq 0 ] && return 1
  return 0
}

systemd_renewal_timers() {
  if have systemctl; then
    local timers
    timers="$(systemctl list-timers --all 2>/dev/null)"
    if printf '%s\n' "$timers" | grep -Eqi 'certbot|letsencrypt|acme\.sh'; then
      printf '%s\n' "$timers" | awk 'NR==1 || /certbot|letsencrypt|acme\.sh/ {print}'
      return 0
    fi
    return 1
  fi
  return 1
}

echo "Collecting CentOS Stream web inventory for ${HOSTNAME}..."

{
  md_h1 "CentOS Stream Web Server Inventory"

  md_h2 "Summary"
  md_kv "Hostname" "$HOSTNAME"
  md_kv "Date" "$(date -Is)"
  md_kv "Operating system" "$OS_PRETTY"
  md_kv "Kernel" "$(uname -r 2>/dev/null || echo 'unknown')"
  md_kv "Uptime" "$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')"
  echo

  md_h2 "Web Services"
  if have systemctl; then
    for svc in httpd nginx certbot; do
      if systemctl list-unit-files | grep -q "^${svc}\.service"; then
        md_h3 "${svc} service status"
        systemctl status "$svc" --no-pager 2>/dev/null | md_code || true
      fi
    done
  else
    md_note "systemctl not available."
  fi

  md_h2 "Apache HTTPD"
  if have httpd; then
    md_kv "Version" "$(httpd -v 2>/dev/null | head -n1)"
    echo

    if have apachectl; then
      md_h3 "Virtual host map (apachectl -S)"
      if apachectl -S >/dev/null 2>&1; then
        apachectl -S 2>/dev/null | md_code
      else
        md_note "apachectl -S returned no virtual host map (this can be normal on RHEL)."
      fi

      md_h3 "Loaded modules"
      apachectl -M 2>/dev/null | md_code || true
    fi

    md_h3 "Configuration directories"
    [ -d /etc/httpd ] && find /etc/httpd -maxdepth 1 -mindepth 1 -print | md_code
    [ -d /etc/httpd/conf.d ] && find /etc/httpd/conf.d -maxdepth 1 -mindepth 1 -print | md_code

    md_h3 "Detected Apache sites"
    APACHE_SITES="$(apache_domains || true)"
    if [ -n "${APACHE_SITES:-}" ]; then
      while IFS= read -r line; do
        echo "${line/#/- }"
      done <<< "$APACHE_SITES"
      echo
    else
      md_note "No Apache ServerName/ServerAlias entries found in /etc/httpd."
    fi
  else
    md_note "Apache HTTPD not installed."
  fi

  md_h2 "Nginx"
  if have nginx; then
    md_kv "Version" "$(nginx -v 2>&1)"
    echo

    md_h3 "Configuration directories"
    [ -d /etc/nginx ] && find /etc/nginx -maxdepth 1 -mindepth 1 -print | md_code
    [ -d /etc/nginx/conf.d ] && find /etc/nginx/conf.d -maxdepth 1 -mindepth 1 -print | md_code
    [ -d /etc/nginx/sites-enabled ] && find /etc/nginx/sites-enabled -maxdepth 1 -mindepth 1 -print | md_code

    md_h3 "Detected Nginx sites"
    NGINX_SITES="$(nginx_domains || true)"
    if [ -n "${NGINX_SITES:-}" ]; then
      while IFS= read -r line; do
        echo "${line/#/- }"
      done <<< "$NGINX_SITES"
      echo
    else
      md_note "No Nginx server_name entries found in /etc/nginx."
    fi

    md_h3 "Full configuration (nginx -T)"
    if nginx -T >/dev/null 2>&1; then
      nginx -T 2>&1 | md_code || true
    else
      md_note "nginx -T not permitted or failed."
    fi
  else
    md_note "Nginx not installed."
  fi

  md_h2 "Hosted Websites (combined)"
  COMBINED_SITES="$( (apache_domains || true; nginx_domains || true) | sort -u )"
  if [ -n "${COMBINED_SITES:-}" ]; then
    while IFS= read -r line; do
      echo "${line/#/- }"
    done <<< "$COMBINED_SITES"
    echo
  else
    md_note "No sites discovered in Apache/Nginx configuration."
  fi

  md_h2 "TLS / Certificate Renewal"

  if have certbot; then
    md_kv "Certbot" "$(certbot --version 2>/dev/null || echo 'installed')"
  else
    md_kv "Certbot" "not installed"
  fi

  md_h3 "Renewal configuration (/etc/letsencrypt/renewal)"
  if [ -d /etc/letsencrypt/renewal ]; then
    if certbot_renewal_summary; then
      echo
    else
      md_note "No renewal configuration files found."
    fi
  else
    md_note "/etc/letsencrypt/renewal not present."
  fi

  md_h3 "Systemd timers for renewal"
  if systemd_renewal_timers; then
    systemd_renewal_timers | md_code
  else
    md_note "systemd not available or no timers found."
  fi

  md_h3 "Cron-based renewal"
  if cron_hits_for_renewal; then
    cron_hits_for_renewal | md_code
  else
    md_note "No certbot/acme.sh entries found in cron locations."
  fi

  md_h3 "Certificates on disk"
  if have certbot; then
    md_h4 "Certbot inventory (certbot certificates)"
    certbot certificates 2>/dev/null | md_code || true
  fi

  if [ -d /etc/letsencrypt/live ]; then
    md_h4 "Live certificate files (/etc/letsencrypt/live)"
    LIVE_FILES="$(live_cert_files || true)"
    if [ -n "${LIVE_FILES:-}" ]; then
      printf '%s\n' "$LIVE_FILES" | md_code
    else
      md_note "No live certificate files found (only symlinks are expected here)."
    fi
  else
    md_note "No /etc/letsencrypt/live directory found."
  fi

  if [ -d /etc/letsencrypt/archive ]; then
    md_h4 "Archive certificate files (/etc/letsencrypt/archive)"
    archive_latest_files 2>/dev/null | md_code
  else
    md_note "No /etc/letsencrypt/archive directory found."
  fi

  echo "---"
  md_note "End of report."
} >"$OUTFILE"

echo "Done. Wrote: $OUTFILE"
