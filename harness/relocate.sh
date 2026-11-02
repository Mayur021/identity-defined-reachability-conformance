#!/usr/bin/env bash
# IDR-P3 adjudicator. Decides the relocation property from two vantage records.
#
# P3 is the property most easily faked, because showing that access still works
# after a move proves nothing on its own: an operator may have changed something
# to make it work. The claim is conjunctive and this script refuses to collapse
# it. Access at both ends is necessary and not sufficient. The fingerprints must
# also be identical, and the two locations must actually differ in public egress
# as seen from outside, or no relocation happened and there is nothing to judge.
#
# Each vantage directory is produced at its own location and holds three things:
#
#   vantage   the output of harness/egress.sh, carrying observed_egress
#   fp/       a fingerprint directory from harness/fingerprint.sh
#   access    three lines, written by whatever drove the access attempt:
#               access: reachable | absent
#               reenrolment: yes | no
#               new_credential: yes | no
#
# The two directories are moved to one host for adjudication. Nothing here
# touches a network, so it can run anywhere after the fact.
#
# Usage: relocate.sh <vantage-dir-1> <vantage-dir-2>
# Exit 0 = PASS. 1 = FAIL. 2 = NOT_ESTABLISHED.
set -uo pipefail
D1="${1:?usage: relocate.sh <vantage-dir-1> <vantage-dir-2>}"
D2="${2:?usage: relocate.sh <vantage-dir-1> <vantage-dir-2>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

ne(){ echo "RESULT: NOT_ESTABLISHED. $1"; exit 2; }
fail(){ echo "RESULT: FAIL. $1"; exit 1; }

for d in "$D1" "$D2"; do
  [ -f "$d/vantage" ] || ne "$d has no vantage record. Run harness/egress.sh at that location."
  [ -d "$d/fp" ]      || ne "$d has no fp/ directory. Run harness/fingerprint.sh at that location."
  [ -f "$d/access" ]  || ne "$d has no access record."
done

field(){ sed -n "s/^$2: *//p" "$1" | head -1; }

E1=$(field "$D1/vantage" observed_egress)
E2=$(field "$D2/vantage" observed_egress)
echo "location 1 observed egress: ${E1:-MISSING}"
echo "location 2 observed egress: ${E2:-MISSING}"

if [ -z "$E1" ] || [ -z "$E2" ]; then
  ne "an observed_egress line is missing."
fi
if [ "$E1" = "NOT_ESTABLISHED" ] || [ "$E2" = "NOT_ESTABLISHED" ]; then
  ne "egress was not established at one of the locations, so the move is asserted rather than observed."
fi

for d in "$D1" "$D2"; do
  src=$(field "$d/vantage" observer_source)
  [ "$src" = "external" ] || ne "$d records observer_source '$src'. P3 requires an external observer; a client reporting its own address is reporting what it believes."
done

if [ "$E1" = "$E2" ]; then
  ne "public egress is identical at both locations, so no relocation occurred. There is no property here to pass or fail."
fi

A1=$(field "$D1/access" access)
A2=$(field "$D2/access" access)
echo "location 1 access: ${A1:-MISSING}"
echo "location 2 access: ${A2:-MISSING}"
[ "$A1" = "reachable" ] || fail "the service was not reachable at location 1, so the relationship was never established to survive anything."
[ "$A2" = "reachable" ] || fail "the service was not reachable at location 2. The relationship did not survive the move."

RE=$(field "$D2/access" reenrolment)
NC=$(field "$D2/access" new_credential)
echo "location 2 reenrolment: ${RE:-MISSING}   new_credential: ${NC:-MISSING}"
[ -n "$RE" ] && [ -n "$NC" ] || ne "location 2 does not record whether re-enrolment or a new credential was used."
[ "$RE" = "no" ] || fail "the identity re-enrolled at location 2. That is a new relationship, not a surviving one."
[ "$NC" = "no" ] || fail "a new credential was issued at location 2. That is a new relationship, not a surviving one."

echo "--- configuration invariance ---"
bash "$HERE/compare.sh" "$D1/fp" "$D2/fp"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS. Access held across a move that external observers confirm, and nothing in the access-relevant configuration was touched."
  exit 0
fi
if [ "$rc" -eq 3 ]; then
  ne "a fingerprint does not match its own manifest, so it was altered after capture and cannot be used as evidence."
fi
if [ "$rc" -eq 2 ]; then
  ne "the fingerprint comparison reported an excepted component that did not move. P3 permits no exceptions, so this means compare.sh was invoked wrongly."
fi
fail "the access-relevant configuration changed across the move. Access succeeding does not evidence the property; the point of the test is that nobody touched anything."
