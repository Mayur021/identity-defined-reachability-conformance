#!/usr/bin/env bash
# Externally observed public egress, for IDR-P3.
#
# P3 requires the two locations to differ in public egress address, and requires
# that difference to come from an external observer rather than from the client's
# own claim. A client reporting its own address is reporting what it believes,
# which is the thing under test, so `ip addr` is not evidence here.
#
# One observer is a single point of trust, so this asks several independent ones
# and records every answer. They must agree. Disagreement is NOT_ESTABLISHED
# rather than a quiet majority vote, because a split answer means something in
# the path is rewriting the view and that is exactly what P3 is trying to see.
#
# What this does NOT prove: that the observer is honest, or that the address is
# not shared with other tenants behind the same NAT. It proves that something
# outside the host, asked independently more than once, reported the same source
# address. That is the strongest claim available without a cooperating listener,
# and OBSERVER_URLS exists so a lab with one can point this at it.
#
# Usage: egress.sh <vantage-id> <outdir>
# Exit 0 = observed and the observers agree. 2 = NOT_ESTABLISHED.
set -uo pipefail
ID="${1:?usage: egress.sh <vantage-id> <outdir>}"
OUT="${2:?usage: egress.sh <vantage-id> <outdir>}"
DIR="$OUT/egress_$ID"; mkdir -p "$DIR"

# Override in a lab that runs its own observer. Space separated.
OBSERVERS="${OBSERVER_URLS:-https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com}"
TIMEOUT="${EGRESS_TIMEOUT:-10}"

: > "$DIR/observations"
seen=""
count=0
for url in $OBSERVERS; do
  host=$(printf '%s' "$url" | sed -E 's#^[a-z]+://([^/]+).*#\1#')
  body=$(curl -4 -sS --max-time "$TIMEOUT" "$url" 2>"$DIR/err_$host" | tr -d '[:space:]')
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if printf '%s' "$body" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "$ts	$url	$body" >> "$DIR/observations"
    seen="$seen $body"
    count=$((count + 1))
  else
    echo "$ts	$url	NO_ANSWER" >> "$DIR/observations"
  fi
done

uniq_addrs=$(printf '%s\n' $seen | sort -u)
n_uniq=$(printf '%s\n' $uniq_addrs | grep -c . )

{
  echo "vantage_id: $ID"
  echo "captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "observers_asked: $(printf '%s' "$OBSERVERS" | wc -w)"
  echo "observers_answered: $count"
  echo "observer_source: external"
} > "$DIR/vantage"

if [ "$count" -lt 2 ]; then
  echo "observed_egress: NOT_ESTABLISHED" >> "$DIR/vantage"
  echo "reason: fewer than two independent observers answered" >> "$DIR/vantage"
  cat "$DIR/vantage"
  echo "RESULT: NOT_ESTABLISHED. One observer is a single point of trust and zero is nothing."
  exit 2
fi

if [ "$n_uniq" -ne 1 ]; then
  echo "observed_egress: NOT_ESTABLISHED" >> "$DIR/vantage"
  echo "reason: observers disagree" >> "$DIR/vantage"
  printf 'addresses_seen: %s\n' "$(printf '%s' "$uniq_addrs" | tr '\n' ' ')" >> "$DIR/vantage"
  cat "$DIR/vantage"
  echo "RESULT: NOT_ESTABLISHED. Observers disagree, so something in the path is rewriting the view."
  exit 2
fi

ADDR=$(printf '%s\n' $uniq_addrs | head -1)
echo "observed_egress: $ADDR" >> "$DIR/vantage"
sha256sum "$DIR/observations" | awk '{print "observations_sha256: "$1}' >> "$DIR/vantage"
cat "$DIR/vantage"
echo "RESULT: egress observed externally by $count independent observers, in agreement."
exit 0
