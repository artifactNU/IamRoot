#!/usr/bin/env bash
# check-apt-health.sh
# Purpose: Read-only diagnostics for APT/dpkg health on Debian/Ubuntu
# Usage:   ./check-apt-health.sh [--verbose|-v] [--json]
# Exit:    0 OK, 1 WARN, 2 DEGRADED

set -euo pipefail

VERBOSE=0
JSON=0

for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --json) JSON=1 ;;
    --help|-h)
      cat <<'EOF'
check-apt-health.sh [--verbose|-v] [--json]
Read-only health checks for APT/dpkg.
Exit codes: 0 OK, 1 WARN, 2 DEGRADED
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
now_iso() { date -Is 2>/dev/null || date; }

STATUS="OK"
EXIT_CODE=0
REASONS=()

set_status() {
  local new="$1"
  case "$new" in
    OK) return 0 ;;
    WARN)
      if [[ "$STATUS" == "OK" ]]; then STATUS="WARN"; EXIT_CODE=1; fi
      ;;
    DEGRADED)
      STATUS="DEGRADED"; EXIT_CODE=2
      ;;
  esac
}
add_reason() { REASONS+=("$1"); }

if ! have dpkg || ! have apt-get; then
  echo "ERROR: dpkg/apt-get not found (is this Debian/Ubuntu?)" >&2
  exit 2
fi

# ---- Checks ----

LOCK_FILES=(
  "/var/lib/dpkg/lock"
  "/var/lib/dpkg/lock-frontend"
  "/var/cache/apt/archives/lock"
)

lock_present() {
  local f
  for f in "${LOCK_FILES[@]}"; do
    [[ -e "$f" ]] && echo "yes" && return 0
  done
  echo "no"
}

who_holds_locks() {
  # Read-only: list processes holding common lock files (if lsof/fuser exists)
  local out=""
  if have lsof; then
    for f in "${LOCK_FILES[@]}"; do
      [[ -e "$f" ]] || continue
      out+=$(lsof "$f" 2>/dev/null | awk 'NR>1 {print $1"("$2")"}' | sort -u | tr '\n' ' ')
    done
  elif have fuser; then
    for f in "${LOCK_FILES[@]}"; do
      [[ -e "$f" ]] || continue
      out+=$(fuser "$f" 2>/dev/null | tr ' ' '\n' | awk 'NF{print "pid(" $1 ")"}' | tr '\n' ' ')
    done
  fi
  echo "${out:-unknown}"
}

dpkg_audit() {
  # dpkg --audit prints problems to stdout; empty output => ok
  local out
  out="$(dpkg --audit 2>/dev/null || true)"
  if [[ -n "$out" ]]; then
    echo "issues"
    return 0
  fi
  echo "ok"
}

half_configured_pkgs() {
  # packages in weird states (iF, iU, etc.)
  dpkg -l 2>/dev/null | awk '
    $1 ~ /^(iF|iU|iH|pF|pU|hF|rc)$/ {print $2}
  ' | head -n 50
}

held_packages() {
  if have apt-mark; then
    apt-mark showhold 2>/dev/null || true
  else
    echo ""
  fi
}

broken_deps_sim() {
  # Simulate fixing broken deps; if apt reports it would do something, treat as warn.
  # This is read-only because of -s (simulate).
  local out
  out="$(apt-get -s -o Debug::NoLocking=1 -f install 2>/dev/null || true)"
  if echo "$out" | grep -qE '^(The following packages will be (REMOVED|upgraded|NEWLY installed))'; then
    echo "would-change"
  elif echo "$out" | grep -qiE 'broken|unmet dependencies|E:'; then
    echo "errors"
  else
    echo "ok"
  fi
}

unattended_status() {
  if have systemctl; then
    systemctl is-active unattended-upgrades 2>/dev/null || true
  else
    echo "unknown"
  fi
}

# ---- Evaluate ----

LOCK="$(lock_present)"
LOCK_HOLDERS=""

if [[ "$LOCK" == "yes" ]]; then
  LOCK_HOLDERS="$(who_holds_locks)"
  # lock present can be normal if apt is running; make it WARN (not DEGRADED)
  set_status WARN
  add_reason "dpkg/apt lock present (holders: ${LOCK_HOLDERS})"
fi

AUDIT="$(dpkg_audit)"
if [[ "$AUDIT" != "ok" ]]; then
  # dpkg --audit output indicates inconsistent state; often more serious
  set_status DEGRADED
  add_reason "dpkg reports problems (dpkg --audit)"
fi

HELD="$(held_packages)"
if [[ -n "$HELD" ]]; then
  set_status WARN
  add_reason "held packages present"
fi

BROKEN_SIM="$(broken_deps_sim)"
if [[ "$BROKEN_SIM" == "would-change" ]]; then
  set_status WARN
  add_reason "apt -f install would change packages (simulated)"
elif [[ "$BROKEN_SIM" == "errors" ]]; then
  set_status DEGRADED
  add_reason "apt reports broken dependencies (simulated)"
fi

UA="$(unattended_status)"
if [[ "$UA" == "active" ]]; then
  # purely informational; in verbose output it’s useful for “lock present”
  : # no status change
fi

# ---- Output ----

emit_text() {
  echo "APT/dpkg Health: ${STATUS}"
  echo "Timestamp: $(now_iso)"
  echo "Lock present: ${LOCK}"
  if [[ "$LOCK" == "yes" ]]; then
    echo "Lock holders: ${LOCK_HOLDERS}"
  fi
  echo "dpkg --audit: ${AUDIT}"
  echo "unattended-upgrades: ${UA}"

  if [[ -n "$HELD" ]]; then
    echo
    echo "Held packages:"
    # shellcheck disable=SC2001
    echo "$HELD" | sed 's/^/  - /'
  fi

  if ((VERBOSE)); then
    echo
    echo "Broken/half-configured packages (top 50):"
    local hc
    hc="$(half_configured_pkgs || true)"
    if [[ -n "$hc" ]]; then
      # shellcheck disable=SC2001
      echo "$hc" | sed 's/^/  - /'
    else
      echo "  (none detected)"
    fi

    echo
    echo "Suggested next commands (read-only unless you run them without -s):"
    echo "  dpkg --audit"
    echo "  apt-get -s -f install"
    echo "  apt-mark showhold"
    echo "  tail -n 200 /var/log/dpkg.log"
    echo "  journalctl -u unattended-upgrades --since \"-2h\""
  fi

  if ((${#REASONS[@]} > 0)); then
    echo
    echo "Reasons:"
    for r in "${REASONS[@]}"; do
      echo " - $r"
    done
  fi
}

json_escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e $'s/\t/\\t/g' -e $'s/\r/\\r/g' -e $'s/\n/\\n/g'; }

emit_json() {
  local reasons_json="[]"
  if ((${#REASONS[@]} > 0)); then
    reasons_json="["
    local first=1
    for r in "${REASONS[@]}"; do
      if ((first)); then first=0; else reasons_json+=", "; fi
      reasons_json+="\"$(printf "%s" "$r" | json_escape)\""
    done
    reasons_json+="]"
  fi

  cat <<EOF
{
  "status": "$(printf "%s" "$STATUS" | json_escape)",
  "exit_code": ${EXIT_CODE},
  "timestamp": "$(now_iso | json_escape)",
  "lock_present": "$(printf "%s" "$LOCK" | json_escape)",
  "lock_holders": "$(printf "%s" "${LOCK_HOLDERS:-}" | json_escape)",
  "dpkg_audit": "$(printf "%s" "$AUDIT" | json_escape)",
  "unattended_upgrades": "$(printf "%s" "$UA" | json_escape)",
  "held_packages": "$(printf "%s" "${HELD:-}" | json_escape)",
  "broken_deps_sim": "$(printf "%s" "$BROKEN_SIM" | json_escape)",
  "reasons": ${reasons_json}
}
EOF
}

if ((JSON)); then
  emit_json
else
  emit_text
fi

exit "$EXIT_CODE"
