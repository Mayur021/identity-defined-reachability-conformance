#!/usr/bin/env bash
# Discovery harness for the negative properties (P1, P2, P4, P6).
#
# The point of this script is not that it probes. Anything can probe. The point is
# that it emits the discovery block alongside the result, so a reader can tell what
# "no path" actually covered. A negative produced without this block is recorded as
# NOT_ESTABLISHED, not PASS.
#
# Usage: discover.sh <label> <outdir> <target-spec-file>
# target-spec-file: one target per line, "host port proto class"
#   proto: tcp|udp|dns|http
#   class: protected | fabric
#     protected = the guarded surface. A path here fails the property.
#     fabric    = the entry point a client must reach to ask for anything at all.
#                 Reachable by design; its presence is not a finding. It is swept and
#                 recorded anyway, because "we did not look" and "we looked and it was
#                 open as expected" are different statements.
set -uo pipefail
LABEL="${1:?usage: discover.sh <label> <outdir> <targets-file>}"
OUT="${2:?usage: discover.sh <label> <outdir> <targets-file>}"
SPEC="${3:?usage: discover.sh <label> <outdir> <targets-file>}"
TIMEOUT="${IDR_TIMEOUT:-5}"
RETRIES="${IDR_RETRIES:-2}"
mkdir -p "$OUT"; D="$OUT/disc_$LABEL"; mkdir -p "$D"
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- the discovery block: what this sweep actually did ---
{
  echo "label: $LABEL"
  echo "started_at: $(ts)"
  echo "vantage_host: $(hostname)"
  echo "vantage_egress_declared: ${IDR_EGRESS:-NOT_DECLARED}"
  echo "timeout_seconds: $TIMEOUT"
  echo "retries: $RETRIES"
  echo "targets_file_sha256: $(sha256sum "$SPEC" | cut -d' ' -f1)"
  echo "target_count: $(grep -cvE '^\s*(#|$)' "$SPEC")"
  echo "tools:"
  for t in curl nc dig nmap openssl; do
    if ! command -v "$t" >/dev/null 2>&1; then echo "  $t: absent"; continue; fi
    case "$t" in
      curl|nmap|openssl) v=$("$t" --version 2>/dev/null | head -1) ;;
      dig)               v=$(dig -v 2>&1 | head -1) ;;
      nc)                v=$( { nc -h; } 2>&1 | head -1) ;;
    esac
    [ -z "$v" ] && v="present, version not reported"
    echo "  $t: $v"
  done
  echo "  bash: $BASH_VERSION"
} > "$D/discovery_block"

probe(){ # host port proto -> prints verdict
  local h=$1 p=$2 pr=$3 i out
  for i in $(seq 1 "$RETRIES"); do
    case "$pr" in
      tcp)  timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null && { echo "PATH_PRESENT tcp_connect"; return; } ;;
      http) out=$(curl -sS -m "$TIMEOUT" -o /dev/null -w '%{http_code}' "http://$h:$p/" 2>&1)
            [ "$out" != "000" ] && [ -n "$out" ] && { echo "PATH_PRESENT http_$out"; return; } ;;
      dns)  command -v dig >/dev/null 2>&1 && { out=$(dig +time=$TIMEOUT +tries=1 +short "@$h" "$p" 2>/dev/null); [ -n "$out" ] && { echo "PATH_PRESENT dns_answer"; return; }; } ;;
      udp)  command -v nc >/dev/null 2>&1 && nc -u -z -w "$TIMEOUT" "$h" "$p" 2>/dev/null && { echo "PATH_PRESENT udp_open"; return; } ;;
    esac
  done
  echo "NO_PATH"
}

: > "$D/results"
present=0; total=0
fabric_present=0; fabric_total=0
while read -r h p pr cls; do
  case "$h" in ''|\#*) continue;; esac
  cls="${cls:-protected}"
  v=$(probe "$h" "${p:-0}" "${pr:-tcp}")
  printf '%s %s %s [%s] -> %s\n' "$h" "$p" "$pr" "$cls" "$v" >> "$D/results"
  if [ "$cls" = "fabric" ]; then
    fabric_total=$((fabric_total+1))
    case "$v" in PATH_PRESENT*) fabric_present=$((fabric_present+1));; esac
  else
    total=$((total+1))
    case "$v" in PATH_PRESENT*) present=$((present+1));; esac
  fi
done < "$SPEC"

echo "finished_at: $(ts)" >> "$D/discovery_block"
{
  echo "protected_targets_probed: $total"
  echo "protected_paths_present: $present"
  echo "fabric_targets_probed: $fabric_total"
  echo "fabric_paths_present: $fabric_present   # reachable by design, not a finding"
  if [ "$total" -eq 0 ]; then echo "sweep_outcome: NOT_ESTABLISHED  # no protected target was swept"
  elif [ "$present" -eq 0 ]; then echo "sweep_outcome: NO_PATH_OVER_PROTECTED_SURFACE"
  else echo "sweep_outcome: PATH_PRESENT_ON_PROTECTED_SURFACE"; fi
} > "$D/summary"
cat "$D/summary"
echo "discovery block: $D/discovery_block"
