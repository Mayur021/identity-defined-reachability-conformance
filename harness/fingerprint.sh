#!/usr/bin/env bash
# Configuration-invariance fingerprint for IDR-P3 and IDR-P5.
#
# The claim under test is conjunctive: the relationship survived AND nothing was
# changed to make it survive. Access succeeding is only half. This captures the
# access-relevant network configuration so that the before and after can be
# compared byte for byte.
#
# What is deliberately excluded: anything that moves on its own. Interface
# counters, ARP caches, conntrack, socket state and DHCP lease timers all change
# without anyone configuring anything, and including them would make every run
# fail for the wrong reason. What is included is only state a human or a tool had
# to deliberately change.
#
# Usage: fingerprint.sh <label> <outdir>
set -uo pipefail
LABEL="${1:?usage: fingerprint.sh <label> <outdir>}"
OUT="${2:?usage: fingerprint.sh <label> <outdir>}"
mkdir -p "$OUT"
D="$OUT/fp_$LABEL"
mkdir -p "$D"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
echo "$(ts)" > "$D/captured_at"

# 1. Routing table. Normalised: metrics and expiry stripped, sorted.
{ ip -4 route show 2>/dev/null; ip -6 route show 2>/dev/null; } \
  | sed -E 's/ (expires|metric) [0-9]+(sec)?//g' | LC_ALL=C sort > "$D/routes"

# 2. Host firewall. nftables preferred, iptables fallback. Counters zeroed,
#    because packet counts move on their own and are not configuration.
if command -v nft >/dev/null 2>&1; then
  nft --stateless list ruleset 2>/dev/null > "$D/firewall" || : > "$D/firewall"
  echo nftables > "$D/firewall_backend"
else
  { iptables-save -c 2>/dev/null; ip6tables-save -c 2>/dev/null; } \
    | sed -E 's/^\[[0-9]+:[0-9]+\]//' > "$D/firewall" || : > "$D/firewall"
  echo iptables > "$D/firewall_backend"
fi

# 3. Tunnel and VPN interfaces present. Names and kinds only, not counters.
ip -d link show 2>/dev/null \
  | awk '/^[0-9]+:/{name=$2} /(tun|tap|wireguard|vti|ipip|gre|vxlan|ppp)/{print name, $1}' \
  | LC_ALL=C sort -u > "$D/tunnels"

# 4. Anything listening. A new listener is a configuration change.
(ss -tulpnH 2>/dev/null || netstat -tulpn 2>/dev/null) \
  | awk '{print $1, $5}' | LC_ALL=C sort -u > "$D/listeners"

# 5. Resolver configuration.
{ cat /etc/resolv.conf 2>/dev/null | grep -vE '^\s*#'; } | LC_ALL=C sort > "$D/resolver"

# 6. Controller policy and service state, if the operator supplies a command that
#    prints it. Implementation-specific by nature, so it is injected rather than
#    assumed. Set IDR_POLICY_DUMP to a command that writes policy state to stdout.
if [ -n "${IDR_POLICY_DUMP:-}" ]; then
  eval "$IDR_POLICY_DUMP" 2>/dev/null | LC_ALL=C sort > "$D/policy"
else
  echo "NOT_CAPTURED: set IDR_POLICY_DUMP" > "$D/policy"
fi

# Per-component and combined digests.
: > "$D/SHA256"
for f in routes firewall tunnels listeners resolver policy; do
  printf '%s  %s\n' "$(sha256sum < "$D/$f" | cut -d' ' -f1)" "$f" >> "$D/SHA256"
done
COMBINED=$(LC_ALL=C sort "$D/SHA256" | sha256sum | cut -d' ' -f1)
echo "$COMBINED" > "$D/COMBINED_SHA256"
echo "fingerprint $LABEL -> $COMBINED"
