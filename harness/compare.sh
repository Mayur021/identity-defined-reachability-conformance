#!/usr/bin/env bash
# Compare two fingerprints.
#
# P3 requires every component identical. P5 and P7 permit exactly one class of
# difference: the policy or context state that was deliberately changed. Those
# fixtures declare it as `except`, so the comparison has to honour it or the tool
# contradicts its own specification.
#
# An excepted component that did NOT change is reported too. For P5 that is a
# failure of a different kind: the revocation was supposed to change policy, and
# if policy is byte-identical then nothing was revoked.
#
# Before comparing anything it re-derives each component digest from the file on
# disk and checks it against the manifest written at capture time. A fingerprint
# is evidence about a moment that has passed, and the only thing standing between
# it and an edit afterwards is that check. Without it a component file can be
# changed while the recorded digests still agree, which is the failure this whole
# suite exists to catch in other people's tooling.
#
# Usage: compare.sh <fp_a> <fp_b> [--except policy,context]
# Exit 0 = invariance holds. 1 = unexpected drift. 2 = an excepted component did
# not move. 3 = a capture does not match its own manifest and cannot be used.
set -uo pipefail
A="${1:?usage: compare.sh <fp_a> <fp_b> [--except a,b]}"
B="${2:?usage: compare.sh <fp_a> <fp_b> [--except a,b]}"
EXCEPT=""
[ "${3:-}" = "--except" ] && EXCEPT="${4:-}"

# Re-derive the capture rather than trust what it says about itself.
verify(){
  local d="$1" bad="" h f now
  if [ ! -f "$d/SHA256" ]; then
    echo "INTEGRITY: $d has no SHA256 manifest. It was not written by fingerprint.sh."
    return 1
  fi
  while read -r h f; do
    [ -n "$f" ] || continue
    if [ ! -f "$d/$f" ]; then bad="$bad $f(missing)"; continue; fi
    now=$(sha256sum < "$d/$f" | cut -d' ' -f1)
    [ "$now" = "$h" ] || bad="$bad $f"
  done < "$d/SHA256"
  if [ -n "$bad" ]; then
    echo "INTEGRITY: $d does not match its own manifest. Altered since capture:$bad"
    return 1
  fi
  local recomputed recorded
  recomputed=$(LC_ALL=C sort "$d/SHA256" | sha256sum | cut -d' ' -f1)
  recorded=$(cat "$d/COMBINED_SHA256" 2>/dev/null)
  if [ "$recomputed" != "$recorded" ]; then
    echo "INTEGRITY: $d combined digest does not match its components."
    echo "           recorded   $recorded"
    echo "           recomputed $recomputed"
    return 1
  fi
  printf '%s' "$recomputed"
  return 0
}

ha=$(verify "$A") || { echo "$ha"; echo "RESULT: NOT_ESTABLISHED. The capture cannot be used as evidence."; exit 3; }
hb=$(verify "$B") || { echo "$hb"; echo "RESULT: NOT_ESTABLISHED. The capture cannot be used as evidence."; exit 3; }
echo "A $(basename "$A") $ha"
echo "B $(basename "$B") $hb"
[ -n "$EXCEPT" ] && echo "permitted to differ: $EXCEPT"

is_excepted(){ case ",$EXCEPT," in *",$1,"*) return 0;; *) return 1;; esac; }

unexpected=0; excepted_unchanged=""
for f in routes firewall tunnels listeners resolver policy; do
  if cmp -s "$A/$f" "$B/$f"; then
    is_excepted "$f" && excepted_unchanged="$excepted_unchanged $f"
  else
    if is_excepted "$f"; then
      echo "--- $f differs, permitted ---"
      diff -u "$A/$f" "$B/$f" | sed -n '1,20p'
    else
      echo "--- $f differs, NOT permitted ---"
      diff -u "$A/$f" "$B/$f" | sed -n '1,25p'
      unexpected=1
    fi
  fi
done

if [ "$unexpected" -eq 1 ]; then
  echo "RESULT: DRIFT outside the permitted set. Property FAILS regardless of access outcome."
  exit 1
fi
if [ -n "$excepted_unchanged" ]; then
  echo "RESULT: NOT_ESTABLISHED. Permitted component(s)$excepted_unchanged did not change,"
  echo "        so the change under test did not happen. Nothing was evidenced."
  exit 2
fi
echo "RESULT: invariance holds. Only the permitted set moved."
exit 0
