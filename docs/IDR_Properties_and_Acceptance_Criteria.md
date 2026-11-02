% Identity-Defined Reachability: Properties and Acceptance Criteria
% Mayur Agnihotri, StraightArc Technologies Pvt. Ltd.
% Draft 0.2, 2 November 2026

## Status of this document

This is the delivery rendering, written to be read as one file. Where it differs from
the repository, **the repository is normative**: `properties/IDR-PROPERTIES.md` for the
properties and their acceptance criteria, `fixtures/idr.yaml` for the machine-readable
form, and `METHOD.md` for what a negative means here. Rebuild the .docx with `make doc`.

## Provenance

Derived from the Identity-Defined Reachability post series and from the CSA blog
*AI-Speed Risk Requires Identity-Defined Reachability* (Philip Griffiths, 2 July
2026). Written from those public sources alone and before reviewing any non-public
material, so that where these properties agree with existing practitioner work the
agreement is independent rather than inherited.

Draft 0.2 adds three things that come from a later and also public source, the CSA
blog *Identity-Defined Reachability: Reducing Exposure and Connectivity Friction in an
Age of Machine-Speed Attack* (Philip Griffiths, 30 October 2026). Two of its four
evaluation questions ask for something Draft 0.1 did not test: that a withdrawal
preserves unrelated authorised communication and lands inside a bound declared in
advance, and that enforcement is evidenced during failure. The first two became
criteria on P5 and P7. The third became P10. They are marked here because the
independence that applies to Draft 0.1 does not apply to them: they are derived from
his published questions and are his in origin.

Offered as a contribution to the CSA ZT5 Identity-Defined Reachability deliverable.

## Purpose

Identity-defined reachability makes claims that are mostly negatives: a path is
absent, an unentitled identity has none, permission confers no adjacency. Negatives
are the hardest class of claim to evidence and the easiest to assert.

This document defines ten properties and the criteria under which each can be judged
to hold. Each is written so a third party can decide pass or fail from recorded
evidence, without reading any implementation's source or configuration format. An
implementation is then a row in a results table rather than the argument itself.

## How to read a result

Three outcomes, not two.

**PASS.** The acceptance criteria were met and the required evidence exists.

**FAIL.** The property does not hold.

**NOT_ESTABLISHED.** The evidence needed to judge was never produced. A negative with
no discovery method recorded, or with no positive control inside the measurement
window, falls here. It is not a soft fail and it must never be rounded to a pass.

The outcome is not new. ISAE 3000 modifies a conclusion either for material deviation
or for the inability to obtain sufficient appropriate evidence, and BSI's A5 Audit
Methodology states it in those terms: the modification gives a qualified, adverse or
disclaimed conclusion. NOT_ESTABLISHED is the disclaimed case. What this document does
is hold reachability to it, because "we looked and found nothing" and "nothing is
there" are different claims and only the first is ever evidenced.

## The ten properties

### P1. Absence by default

Knowledge of a protected service's name or address does not create a usable path.

The default-deny claim is four separate negatives and each is judged on its own: no
service route, no application session, no permitted data packet, and no service
visibility. A sweep that evidences three of the four passes three, not the property.
Visibility is missed most often, because a service that refuses every connection while
remaining enumerable has not met the claim.

*Criteria.* From a vantage point with no enrolled identity, a discovery sweep against
the service address, the service name and the fabric entry point returns no usable
path. A refused connection, a timeout and no route are passes. A banner, a redirect, a
completed TLS handshake against the protected service, or any protocol response
attributable to it are failures. The service must be confirmed serving during the
window by a successful request from an entitled identity, or the negative is
indistinguishable from a service that was down.

### P2. Entitlement gates the path

A valid identity that is not entitled to a service has no path to it.

Distinct from P1, which tests the anonymous case. This tests the case that matters
operationally: an identity the system accepts, with no entitlement to this service.

*Criteria.* Two identities enrol and both authenticate. A holds a policy binding it to
the service, B holds none. A reaches the service, B does not, under the same discovery
method, from the same vantage point, in the same window. The denial for B must be an
absence of path. If B completes a transport connection and is refused by the service
itself, the property fails regardless of the outcome the user sees.

### P3. The relationship survives relocation

An authorised relationship persists across a change of network location, without any
change to routing, firewall, NAT or VPN configuration.

This is the property most easily faked. Showing access still works after a move proves
nothing on its own, because someone may have changed something to make it work. The
claim is conjunctive and both halves need evidence.

*Criteria.* Identity A reaches the service from location 1, moves to location 2, and
reaches it again with no re-enrolment and no new credential. The two locations must
differ in public egress address and that difference must be recorded by an external
observer, not asserted by the client. A fingerprint of the access-relevant
configuration is captured immediately before the move and immediately after the second
access, and the two must be identical. Any drift fails the property even where access
behaved exactly as predicted, because the point of the test is that nothing was
touched.

### P4. Permission does not confer adjacency

An identity entitled to one service has no path to other services on that service's
network.

*Criteria.* At least one neighbouring service exists on the same segment and is
confirmed running during the window. Identity A, entitled only to the protected
service, reaches it, and from the same session a sweep of the neighbouring segment
returns no usable path. The swept range must be recorded; a sweep that did not cover
the neighbour's address does not evidence this property.

### P5. Revocation removes the path

Withdrawing an entitlement removes the path, without any change to routing, firewall,
NAT or VPN configuration.

*Criteria.* Identity A reaches the service. The entitlement is withdrawn at the policy
layer only. A no longer reaches the service under the P1 discovery method.
Configuration invariance holds as in P3: the network-layer fingerprint before
withdrawal and after the failed access must be identical, and only the policy state may
differ. The interval between withdrawal and loss of path is recorded. A property that
holds only after a long convergence delay is a different property and is reported as
such rather than rounded to a pass.

A note on what to measure. "How quickly can the path be withdrawn" is usually answered
with policy propagation time. That is the easy number and not the one that matters.
What matters is when the already established session stops carrying traffic, because
the connection that is already up is the one an out-of-scope action is travelling on.
Both numbers belong in the evidence, timestamped from the same clock.

Two further criteria, added in Draft 0.2. The bound is declared before the run, so the
interval has something to be judged against: a deployment claiming withdrawal inside a
stated period is held to it, and one stating no period has its time recorded while the
within-bound claim resolves to NOT_ESTABLISHED. And unrelated authorised communication
survives: a second entitled identity with its own relationship holds a path across the
window and is measured in it. Losing the bystander is a failure even where A's path
closed exactly as intended, because a withdrawal that takes bystanders with it is a
different control and an availability owner will reverse it.

### P6. Alternative ingress is controlled

No path to the protected service exists by any route other than an authorised
relationship.

This is the weakest property by construction. It quantifies over all paths and a test
covers only what it looked for. It is stated here so that its bound is stated with it.

*Criteria.* The ingress surface is enumerated in advance and checked in as an artifact:
every address, interface and name by which the service or its host could be addressed.
A sweep from an unentitled vantage point covers that surface and returns no usable path.
The result is recorded as a pass for the enumerated surface and makes no claim beyond it.

### P7. Authority remains conditional throughout the session

Reachability stays conditional on identity, policy and context for the life of the
interaction, not only at establishment. A condition that would have denied the path at
establishment, arising mid-session, withdraws it.

Distinct from P5, which tests withdrawal an operator performs. This tests withdrawal
nobody performs: posture degrades, context leaves the permitted set, or a compromise
signal is raised, and the path must close without anyone acting. It separates
continuous evaluation from evaluation at establishment, which is the common failure it
exists to catch: posture checked once at setup, after which the session carries traffic
indefinitely.

*Criteria.* Identity A establishes a permitted session and traffic flows. A condition
the deployment already consumes changes such that policy would no longer permit the
path. No operator action is taken, and the absence of one is evidenced from the audit
trail rather than asserted. Traffic on the already established session stops: a new
connection being refused while the existing one continues is a failure, and it is the
exact shape this property exists to detect. The interval is recorded from the condition
becoming observable to the last byte delivered, with policy-record update time recorded
separately where it differs, because updating the record is not the control.
Configuration invariance holds as in P3 and P5. The declared bound and the bystander
requirement carry over from P5 unchanged.

### P8. A path is bound to a distinguishable actor

A granted path is bound to an actor the deployment can tell apart from others, not to a
credential several of them share.

Not covered by P2, which asks whether an unentitled identity is refused. This asks
whether identity is doing the work the architecture assumes. The mapping between actor
and identity is not one to one, and it breaks in both directions.

Many actors to one identity: a shared credential collapses entitlement to the union of
everything its users need, the grant is correct for the credential and wrong for every
actor behind it, and the record names a credential rather than an actor.

One actor to many identities: an actor holding several credentials reaches the union of
their entitlements. Every decision is evaluated correctly and separately and the
aggregate is still wrong, because no decision was ever taken about the actor. This is
the harder direction to see. Nothing is misconfigured and no single grant is wrong, and
the reachable set grows with every credential the actor accumulates rather than with
any decision anyone made.

*Criteria, first direction.* Two actors the deployment intends to distinguish attempt
the same service. The enforcement point's record attributes them to two identities; if
both resolve to one, the property fails whether or not access was correct. Attribution
comes from the enforcement point, never from a field the caller populates. Entitlement
is withdrawn for one and the other retains its path; if both lose it, that evidences a
shared credential.

*Criteria, second direction.* The credentials available to a single actor are
enumerated and the enumeration recorded, since an unenumerated credential makes the
result NOT_ESTABLISHED. The union of what they reach is compared against the
reachability intended for that actor, and a union wider than the intent fails the
property even where every individual grant is correct. Withdrawing the actor's
entitlement removes the path under every credential it holds, not only the one used to
establish the session under test.

### P9. Delegation does not widen reachability

An identity that invokes another does not extend its own reachable set, and the invoked
identity does not inherit the caller's.

Reachability is argued for on the grounds that autonomous activity outpaces human
approval, and autonomous activity is usually a chain. If each hop carries the caller's
authority, the reachable set is the union across the chain and grows with every step.

*Criteria.* A is entitled to S1, B to S2, neither to the other's. A invokes B. During
and after, B has no path to S1 and A none to S2. Where explicit delegation exists, the
delegated authority is narrower than or equal to the delegator's and the narrowing is
evidenced. The chain's extent is recorded with its source; where the extent comes from
the invoking agent's own plan the result is NOT_ESTABLISHED, because the fold was
computed over a set the gated party chose.

### P10. Enforcement holds when the control plane does not

The deployment declares in advance what becomes of an authorised path when the
evaluator is unreachable, and then does that.

Continuous conditionality implies a dependency on the evaluator being reachable. If an
established path survives an unreachable controller then authority is not continuously
conditional for the length of the outage. If it does not, a control-plane outage is a
total outage. Both are defensible and they are different systems. What is not
defensible is leaving it undeclared, which lets one deployment claim continuous
evaluation in the architecture document and availability in the runbook. This property
has no preferred answer. It tests the declaration.

*Criteria.* Before the run the deployment declares `fail_closed` or `fail_static`, and
the maximum period it claims a path may carry traffic without a fresh decision. The
declaration is captured before the partition and is not written once the behaviour is
known. Identity A establishes a permitted session and traffic flows. The evaluator is
made unreachable from the enforcement point, by a method recorded and effected outside
the set the fingerprint covers. Traffic on the already established session is observed
against the declaration, and under `fail_static` the observation window exceeds the
declared maximum or the run evidences only that nothing has happened yet. A path is
attempted by an entitled identity during the partition and the result is recorded
against the declaration rather than scored. The evaluator is restored, and under
`fail_static` the first decision after restoration is shown to have been taken rather
than assumed. Configuration invariance holds as in P3.

The easy way to produce a clean-looking `fail_closed` is to sever the data path along
with the control plane. That evidences nothing about the control plane and is a
NOT_ESTABLISHED, not a pass.

## Prior art

These properties were reconciled against existing practitioner material before
publication. Where an equivalent already existed, it is credited in the contribution
sent to that author rather than restated here.

## Method

### What a negative means here

Eight of the ten properties turn on a negative. Each recorded negative carries the sweep that
produced it: the target list and its hash, timeouts, retry count, vantage point, and the
versions of the tools used. A negative without that block records as NOT_ESTABLISHED.

The positive control is not optional. A sweep returning nothing is indistinguishable
from a service that was not running, so every negative property requires a successful
access by an entitled identity inside the same measurement window.

### Configuration invariance

P3 and P5 make conjunctive claims, and the second half is what the fingerprint exists
to evidence. It captures routing table, host firewall ruleset, tunnel and VPN
interfaces, listening sockets, resolver configuration, and controller policy state.

It deliberately excludes anything that moves on its own: interface counters, conntrack
entries, ARP caches, socket states, lease timers, and firewall packet counters.
Including them would fail every run for reasons unrelated to the property.

The output is a per-component digest plus a combined digest. Identical combined digests
across a pair means the second half of the claim holds.

### Relocation is observed, not asserted

For P3 the two locations must differ in public egress address as recorded by an external
observer. A client reporting its own address is reporting what it believes, which is the
thing under test.

## Harness status

Every script is tested in both directions, and CI proves it on each push.

`fingerprint.sh` and `compare.sh` implement configuration invariance. Two captures with
no change between them produce an identical combined digest. A single added route
produces drift, names the component that changed, prints the difference and exits
non-zero.

`discover.sh` implements the sweep and emits the discovery block automatically. Against
closed targets it reports no path over the swept surface. Against a live listener it
reports the path, which is the positive control working.

`egress.sh` records the public egress address at a vantage point as reported by several
independent external observers, which must agree. One observer answering, or two
disagreeing, is NOT_ESTABLISHED rather than a majority vote, because a split answer means
something in the path is rewriting the view and that is the thing P3 is trying to see.

`relocate.sh` adjudicates P3 from two vantage records after the fact, offline. It treats
the claim as conjunctive and refuses to collapse it: access at both ends is necessary and
not sufficient, identical egress at both locations means no relocation occurred and there
is nothing to judge, and any drift in the access-relevant configuration fails the property
whatever access did.

`compare.sh` re-derives each capture from its own manifest before comparing anything, so a
component file edited after capture is refused as evidence rather than scored.

What remains lab work for P3 is the part no script can take over: two vantage points with
genuinely different public egress. The rest of it is now script work.

No runs are recorded. The results table is empty by design until one is.

## Out of scope: chain extent

A reachability decision that folds a multi-step chain to its highest-impact class
depends on knowing the chain's extent. Where the agent supplies its own plan, the fold
is computed over a set chosen by the party being gated, so the fold is only as
trustworthy as the extent declaration underneath it.

This is outside the ten properties above, which test paths rather than chains. It is
recorded because any framework that cites a chain-fold rule as a control inherits the
extent problem with it, and these properties should not be read as covering something
they do not touch.

This is not an original observation here. It is recorded as open in Bharti and
Agnihotri, *Declared vs. Observed: Measuring the Binding Gap in MCP Tool
Declarations*, doi.org/10.5281/zenodo.22649163, section 4, CC BY 4.0.


## What these properties do not cover

Stated so the set is not read as a completeness claim.

**Enrolment.** Every property begins after an identity exists. Enrolment is typically a
one-time token, and whoever holds it becomes the identity it names: a bearer credential
at the front of an architecture built to remove them. Not tested here.

**Where the trust went.** Topology-governed reachability fails one segment at a time.
Control-plane-governed reachability fails all at once. The trade is a broad low-value
surface for a narrow total one, good only if the narrow one is defended accordingly.
These properties assume a correct control plane.

**Visibility for the defender.** A path between two authorised endpoints is not on a
wire anyone can capture, so evidence comes from the control plane, making it sole
witness to its own enforcement. These properties consume that record rather than
corroborate it.

**Scope of action within an authorised path.** An entitled identity misusing its
entitlement is outside reachability. The graph bounds what can be attempted, not what is
done inside it.

## Scope of a passing result

A full pass evidences that these properties hold for the implementation and
configuration under test, at the recorded commit, under the recorded discovery method.
It does not evidence that they hold for the model in general, that the implementation is
free of other defects, or that any path outside the enumerated surface was examined.

## Licence

Apache-2.0. Attribution requested, not required.
