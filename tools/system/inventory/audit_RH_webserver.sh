#!/usr/bin/env bash
# audit_webserver_md.sh
# Purpose: Read-only web server audit for CentOS / RHEL-family systems
# Output: web_audit_<hostname>_<timestamp>.md

set -euo pipefail

HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
TS="$(date -Is | tr ':' '-')"
OUTFILE="web_audit_${HOSTNAME}_${TS}.md"

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

echo "Collecting web server audit for ${HOSTNAME}..."

{
  md_h1 "Web Server Audit Report"

  md_h2 "Summary"
  md_kv "Hostname" "$HOSTNAME"
  md_kv "Date" "$(date -Is)"
  md_kv "Operating system" "$OS_PRETTY"
  md_kv "Kernel" "$(uname -r)"
  md_kv "Uptime" "$(uptime -p 2>/dev/null || uptime)"
  echo

  #######################################
  md_h2 "Network Exposure"
  #######################################

  md_h3 "Listening Ports"
  if have ss; then
    ss -tulpen | md_code
  else
    md_note "\`ss\` not available."
  fi

#######################################
md_h2 "Firewall"
#######################################

if have firewall-cmd; then
  if systemctl is-active firewalld >/dev/null 2>&1; then
    md_kv "firewalld status" "active"

    md_h3 "Active Firewall Zones"
    firewall-cmd --get-active-zones | md_code

    md_h3 "Firewall Rules"

    # firewalld CLI differs between EL8 and EL9
    if firewall-cmd --help 2>&1 | grep -q -- '--list-all-zones'; then
      # EL9+ (newer firewalld)
      firewall-cmd --list-all-zones | md_code
    else
      # EL7 / EL8 (older firewalld)
      firewall-cmd --list-all | md_code

      md_note "Older firewalld detected; showing rules for the default/active zone only."
    fi
  else
    md_note "firewalld installed but not running."
  fi
else
  md_note "firewalld not installed."
fi


  #######################################
  md_h2 "SELinux"
  #######################################

  if have getenforce; then
    md_kv "SELinux mode" "$(getenforce)"

    if have sestatus; then
      md_h3 "SELinux Status"
      sestatus | md_code
    fi

    if have semanage; then
      md_h3 "SELinux httpd-related booleans"
      semanage boolean -l 2>/dev/null | awk '/httpd/ {print}' | md_code
    else
      md_note "\`semanage\` not available."
    fi
  else
    md_note "SELinux not available."
  fi

  #######################################
  md_h2 "Web Server Software"
  #######################################

  if have httpd; then
    md_h3 "Apache HTTPD"
    httpd -v | md_code

    if have apachectl; then
      md_h4 "Loaded Modules"
      apachectl -M 2>/dev/null | md_code
    fi

    md_h4 "Configuration Directories"
    # shellcheck disable=SC2012
    ls -l /etc/httpd | md_code
    # shellcheck disable=SC2012
    [ -d /etc/httpd/conf.d ] && ls -l /etc/httpd/conf.d | md_code
  fi

  if have nginx; then
    md_h3 "Nginx"
    nginx -v 2>&1 | md_code

    md_h4 "Configuration Directories"
    # shellcheck disable=SC2012
    ls -l /etc/nginx | md_code
    # shellcheck disable=SC2012
    [ -d /etc/nginx/conf.d ] && ls -l /etc/nginx/conf.d | md_code
  fi

  #######################################
  md_h2 "PHP"
  #######################################

  if have php; then
    md_kv "PHP version" "$(php -v | head -n1)"

    md_h3 "Loaded PHP Modules"
    php -m | md_code

    # shellcheck disable=SC2012
    [ -d /etc/php.d ] && md_h3 "PHP Configuration Files" && ls -l /etc/php.d | md_code
  else
    md_note "PHP not installed."
  fi

  #######################################
  md_h2 "Databases"
  #######################################

  FOUND_DB=0
  for svc in mariadb mysql postgresql; do
    if systemctl list-unit-files | grep -q "^${svc}\.service"; then
      FOUND_DB=1
      md_h3 "$svc service status"
      systemctl status "$svc" --no-pager | md_code
    fi
  done

  [ "$FOUND_DB" -eq 0 ] && md_note "No common database services detected."

  #######################################
  md_h2 "TLS / Certificates"
  #######################################

  CERT_DIRS=(/etc/letsencrypt /etc/pki/tls)
  FOUND_CERT=0

  for d in "${CERT_DIRS[@]}"; do
    if [ -d "$d" ]; then
      FOUND_CERT=1
      md_h3 "Certificates under $d"
      find "$d" -maxdepth 3 -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | md_code
    fi
  done

  [ "$FOUND_CERT" -eq 0 ] && md_note "No standard certificate directories found."

  #######################################
  md_h2 "Web Content"
  #######################################

  for d in /var/www /srv; do
    if [ -d "$d" ]; then
      md_h3 "Contents of $d"
      # shellcheck disable=SC2012
      ls -l "$d" | md_code
    fi
  done

  #######################################
  md_h2 "Logs"
  #######################################

  for d in /var/log/httpd /var/log/nginx; do
    if [ -d "$d" ]; then
      md_h3 "Logs in $d"
      # shellcheck disable=SC2012
      ls -lh "$d" | md_code
    fi
  done

  echo "---"
  md_note "End of web server audit."
} >"$OUTFILE"

echo "Done. Wrote: $OUTFILE"
