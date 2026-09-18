# Method

## Why this file exists

Five of the nine properties are negatives. A negative result carries no information
unless the reader can tell what was looked for. "No path was found" and "no path
exists" are different claims, and only the first is ever evidenced.

So every negative in this suite is recorded with the sweep that produced it: the
target list and its hash, the timeouts, the retry count, the vantage point, and the
versions of the tools used. `harness/discover.sh` emits that block automatically and
refuses to be useful without it.

A negative recorded without a discovery block resolves to **NOT_ESTABLISHED**. It is
not a pass and it is not a failure. It is an absence of evidence, and the report says
so in those words.

## The positive control is not optional

A sweep returning nothing is indistinguishable from a service that was not running.
Every negative property therefore requires a successful access by an entitled
identity **inside the same measurement window**. Without it the run is
NOT_ESTABLISHED regardless of how thorough the sweep was.

## Configuration invariance

IDR-P3 and IDR-P5 make conjunctive claims. P3 is not "access survived relocation",
it is "access survived relocation **and nothing was changed to make it survive**".
P5 is not "access stopped", it is "access stopped **and only the policy changed**".

`harness/fingerprint.sh` captures the access-relevant configuration so the two halves
can be evidenced separately: routing table, host firewall ruleset, tunnel and VPN
interfaces, listening sockets, resolver configuration, and the controller's policy
state via an injected dump command.

What it deliberately excludes is anything that moves on its own. Interface counters,
conntrack entries, ARP caches, socket states and lease timers all change without
anyone configuring anything. Including them would make every run fail for a reason
that has nothing to do with the property. Firewall packet counters are stripped for
the same reason.

The result is a per-component digest plus a combined digest. Identical combined
digests across the pair means the property's second half holds. Any drift fails the
property **even if access behaved exactly as predicted**, because the point of the
test is that nobody touched anything.

Both directions are tested in `harness/`: two captures with no change produce an
identical digest, and a single added route produces drift, names the component, and
exits non-zero.


## Measuring the established session

P5 and P7 both turn on when the session that was already carrying traffic stops, not
on a new connection being refused. `harness/session_watch.py` holds one established
connection, writes on a fixed interval, and records the instant of the last byte that
actually made it. That instant is differenced against the moment the condition became
observable.

**A false positive to control for.** A server that closes its own connection produces
exactly the same signal as revocation. Anything without keep-alive, any idle timeout,
any worker recycling, and the watch will report a session end that policy had nothing
to do with. Two controls are required: the probe target must hold a long-lived
connection, demonstrated by a baseline run of at least the intended measurement
duration with no condition change, and that baseline run is recorded alongside the
result. Without the baseline the measurement is NOT_ESTABLISHED.

The watch exits 2 when the session never established, so a target that was unreachable
from the start cannot be mistaken for one that was revoked.

## Relocation has to be observed, not asserted

For P3 the two locations must differ in public egress address, and that difference
must come from an external observer rather than from the client's own claim. A client
reporting its own address is reporting what it believes, which is the thing under
test.

## What a pass means

A full pass evidences that these properties hold for **the implementation and
configuration under test, at the recorded commit, under the recorded discovery
method**. It does not evidence that they hold for the model in general, nor that any
path outside the enumerated surface was examined.

IDR-P6 can never return an unqualified pass. It quantifies over all paths and a sweep
covers only what it looked for, so its result is always `PASS_FOR_ENUMERATED_SURFACE`
with the enumeration checked in alongside it.
