# Identity-Defined Reachability: properties and acceptance criteria

Implementation-neutral. Each property is written so a third party can decide pass or
fail from recorded evidence, without reading any implementation's source or
configuration format.

Nine properties. Five are negatives. A negative result is only as strong as the
discovery that produced it, so every negative property carries a mandatory
`discovery` block and a claim made without one is not a pass, it is an absence of
evidence. See `METHOD.md`.

Derived from the distinctions stated in the IDR post series and its comment thread:
absence by default, entitlement as the unit of access, no adjacency from permission,
controlled alternative ingress, survival across relocation, revocation, authority
that stays conditional for the life of the session, an actor a path can be attributed
to, and delegation that does not widen what is reachable.

---

## IDR-P1 — Absence by default

**Property.** Knowledge of a protected service's name or address does not create a
usable path to it.

**Why it is not trivial.** Most access-control tests start from a reachable service
and ask who may use it. This asks whether the path exists at all before any identity
is asserted.

**Acceptance criteria**

- From a vantage point with no enrolled identity, a discovery sweep against the
  protected service's address and name returns no usable path.
- The sweep covers, at minimum: the service's real address and port, the service's
  DNS name, and the fabric entry point's address.
- A "usable path" means any response from which the protected service can be
  identified or interacted with. A refused connection, a timeout, and no route are
  all passes. A banner, a redirect, a TLS handshake completing against the protected
  service, or any protocol-level response attributable to it are failures.
- The default-deny claim is four separate negatives and each is judged on its own:
  **no service route**, **no application session**, **no permitted data packet**, and
  **no service visibility**. A sweep that evidences three of the four does not pass
  this property, it passes the three it covered. Visibility in particular is missed
  most often, because a service that refuses every connection while still being
  enumerable has not met the claim.
- The service MUST be confirmed running and serving during the sweep window, proved
  by a successful request from an entitled identity inside the same window. Without
  that control, the negative is indistinguishable from a service that was down.

**Evidence required.** Discovery block. Sweep output. In-window positive control.

---

## IDR-P2 — Entitlement gates the path

**Property.** A valid identity that is not entitled to a service has no path to it.

**Distinct from P1.** P1 tests the anonymous case. This tests the case that matters
operationally: an identity the system accepts, with no entitlement to this service.

**Acceptance criteria**

- Two identities are enrolled and both authenticate successfully to the fabric.
- Identity A holds a policy binding it to the service. Identity B holds none.
- A reaches the service. B does not, under the same discovery method as P1, from the
  same vantage point, within the same window.
- The denial for B is observable as an absence of path, not as an application-layer
  rejection. If B completes a transport connection to the service and is refused by
  the service itself, that is a failure of this property regardless of the outcome.

**Evidence required.** Enrolment records for both. Policy state. Discovery block.
Paired A and B results from one window.

---

## IDR-P3 — The relationship survives relocation

**Property.** An authorised service relationship persists across a change of network
location, without any change to routing, firewall, NAT or VPN configuration.

**This is the property most easily faked.** Showing that access still works after a
move proves nothing on its own: an operator may have changed something to make it
work. The claim is conjunctive and both halves must be evidenced.

**Acceptance criteria**

- Identity A reaches the service from network location 1.
- The client moves to network location 2. Locations 2 and 1 MUST differ in observed
  public egress address, and the difference MUST be recorded from an external
  observer rather than asserted.
- Identity A reaches the service from location 2, with no re-enrolment and no new
  credential.
- **Configuration invariance.** A fingerprint of the access-relevant configuration is
  captured immediately before the move and immediately after the second successful
  access. The two fingerprints MUST be identical. The fingerprint covers, at minimum:
  the controller's policy and service state, the host firewall ruleset, the host
  routing table, and the set of active tunnel or VPN interfaces.
- Any fingerprint difference, in either direction, is a failure of this property even
  if access succeeded. The point of the test is that nothing was touched.

**Evidence required.** Externally observed egress address at both locations. Paired
fingerprints with their hashes. Access results at both locations. Timestamps.

---

## IDR-P4 — Permission does not confer adjacency

**Property.** An identity entitled to one service has no path to other services on
that service's network.

**Acceptance criteria**

- At least one additional service exists on the same network segment as the
  protected service and is confirmed running during the window.
- Identity A, entitled only to the protected service, reaches it.
- From the same session, a discovery sweep of the neighbouring segment returns no
  usable path to the neighbouring service.
- The sweep method and its address range MUST be recorded. A sweep that did not cover
  the neighbour's address does not evidence this property.

**Evidence required.** Topology statement. Discovery block including the swept range.
Positive control on the neighbour from inside its own segment.

---

## IDR-P5 — Revocation removes the path

**Property.** Withdrawing an entitlement removes the path, without any change to
routing, firewall, NAT or VPN configuration.

**Acceptance criteria**

- Identity A reaches the service.
- The entitlement is withdrawn at the policy layer only.
- Identity A no longer reaches the service, under the P1 discovery method.
- Configuration invariance holds as in P3: the network-layer fingerprint before
  withdrawal and after the failed access MUST be identical. Only the policy state may
  differ, and that difference MUST be shown.
- The time between withdrawal and loss of path is recorded. A property that only
  holds after a long convergence delay is a different property and should be reported
  as such rather than rounded to a pass.

**Evidence required.** Paired fingerprints. Policy state before and after. Timing.

---

## IDR-P6 — Alternative ingress is controlled

**Property.** No path to the protected service exists by any route other than an
authorised relationship.

**Weakest property by construction.** It quantifies over all paths, and a test can
only cover the paths it looked for. It is stated here so that its bound is stated
with it, not so that anyone can claim it absolutely.

**Acceptance criteria**

- The enumerated ingress surface is recorded in advance: every address, interface and
  name by which the protected service or its host could be addressed.
- A sweep from an unentitled vantage point covers that enumerated surface and returns
  no usable path.
- The report states plainly that the property holds **for the enumerated surface**
  and makes no claim beyond it.

**Evidence required.** The enumeration itself, as a checked-in artifact. Discovery
block. Sweep output.

---

## IDR-P7 — Authority remains conditional throughout the session

**Property.** Reachability stays conditional on identity, policy and context for the
life of the interaction, not only at establishment. A condition that would have
denied the path at establishment, arising mid-session, withdraws it.

**Distinct from P5.** P5 tests withdrawal an operator performs. This tests withdrawal
nobody performs: posture degrades, context leaves the permitted set, or a compromise
signal is raised, and the path must close without anyone acting. It is the property
that separates continuous evaluation from evaluation at establishment, which is the
common failure this exists to catch: posture checked once at session setup, after
which the established session carries traffic indefinitely.

Raised by Philip Griffiths as a core IDR design principle: "When authority is
withdrawn, enforcement must stop traffic on existing paths as well as prevent new
ones. Updating the policy record alone is insufficient."

**Acceptance criteria**

- Identity A establishes a session that policy permits, and traffic flows.
- A condition changes such that policy would no longer permit the path. The condition
  MUST be one the deployment already claims to consume: device posture, context, or a
  signal from a compromise or session-revocation feed.
- **No operator action is taken.** The absence of one is evidenced from the audit
  trail, not asserted. If a human or a script withdrew the entitlement, this is P5.
- Traffic on the **already established** session stops. A new connection being refused
  while the existing one continues is a failure of this property, and it is the exact
  shape the property exists to detect.
- The interval is recorded from the condition becoming observable to the deployment,
  to the last byte delivered on the established session. Policy-record update time is
  recorded separately where it differs, because updating the record is not the control.
- Configuration invariance holds as in P3 and P5: only policy and context state may
  differ, and the network layer MUST be unchanged.

**Evidence required.** The condition and the time it became observable. Last byte on
the pre-existing session. Audit trail showing no operator action. Paired fingerprints.
Policy-record update time where it is a separate number.

---

## IDR-P8 — A path is bound to a distinguishable actor

**Property.** A granted path is bound to an actor the deployment can tell apart from
other actors, not to a credential several of them share.

**Why this is not covered by P2.** P2 asks whether an unentitled identity is refused.
This asks whether "identity" is doing the work the architecture assumes. The mapping
between actor and identity is not one to one, and it breaks in both directions.

*Many actors to one identity.* A shared credential collapses entitlement to the union
of everything its users need. The grant is correct for the credential and wrong for
every actor behind it, and the record names a credential rather than an actor, so
after an incident nobody can say which actor acted.

*One actor to many identities.* An actor holding several credentials reaches the union
of their entitlements. Every policy decision is evaluated correctly and separately,
and the aggregate is still wrong, because no decision was ever taken about the actor.
This is the harder direction to see: nothing is misconfigured, nothing is refused that
should be allowed, and no single grant is wrong. It is also unbounded, since the
reachable set grows with every credential the actor accumulates rather than with any
decision anyone made.

Both directions are silent failures. The path opens and the work completes.

**Acceptance criteria**

*Direction one, many actors to one identity.*

- Two actors the deployment intends to distinguish, for example two agent tasks, two
  workload instances, or two automation jobs, each attempt the same service.
- The enforcement point's own record attributes the two attempts to two identities. If
  both resolve to one identity, the property fails regardless of whether access was
  correct.
- Attribution comes from the enforcement point, not from a field the calling actor
  populates. An actor naming itself is reporting what it claims.
- Entitlement is withdrawn for one actor and the other retains its path. If revoking
  one removes the path for both, that evidences a shared credential and the property
  fails.

*Direction two, one actor to many identities.*

- The credentials available to a single actor are enumerated, and the enumeration is
  recorded. An actor's reachable set is the union of what all of them can reach, so an
  unenumerated credential makes the result NOT_ESTABLISHED rather than a pass.
- That union is compared against the reachability the deployment intended for the
  actor. A union wider than the intent fails the property even though every individual
  grant is correct.
- Withdrawing the actor's entitlement removes the path under every credential it
  holds, not only the one used to establish the session under test. A path surviving
  under a second credential is a failure and is the specific shape this direction
  exists to catch.

**Evidence required.** Enforcement-point records for both attempts. The field used for
attribution and which party writes it. A revocation that affects exactly one actor. The
credential enumeration for the single-actor direction, with its method, and the
intended reachability it was compared against.

---

## IDR-P9 — Delegation does not widen reachability

**Property.** An identity that invokes another does not thereby extend its own
reachable set, and the invoked identity does not inherit the caller's.

**Why it belongs here.** Reachability is argued for on the grounds that autonomous
activity moves faster than human approval. Autonomous activity is usually a chain. If
each hop carries the caller's authority, the reachable set is the union across the
chain and it grows with every step, which is the opposite of what the architecture
claims to do.

**Acceptance criteria**

- Identity A is entitled to service S1, identity B to S2, neither to the other's.
- A invokes B.
- During and after the invocation, B has no path to S1 and A has no path to S2, under
  the P1 discovery method.
- Where the deployment supports explicit delegation, the delegated authority is
  narrower than or equal to the delegator's, and the narrowing is evidenced rather
  than asserted.
- **The chain's extent is recorded, with its source.** Which steps were treated as
  part of the chain, and which party declared that. Where the extent comes from the
  invoking agent's own plan, the result is NOT_ESTABLISHED rather than PASS: the fold
  was computed over a set the gated party chose. See the note on chain extent below.

**Evidence required.** Entitlement state for both identities. Sweeps from each vantage
during the chain. The extent declaration and who authored it.

---

## A note on chain extent, for whatever consumes these properties

A reachability decision that folds a multi-step chain to its highest-impact class
depends on knowing the chain's extent. Where the agent supplies its own plan, the
fold is computed over a set chosen by the party being gated, so the fold is only as
trustworthy as the extent declaration underneath it.

This is out of scope for the nine properties above, which test paths rather than
chains. It is recorded here because any framework that cites a chain-fold rule as a
control inherits the extent problem with it, and the properties should not be read
as covering something they do not touch.

This is not an original observation here. It is recorded as open in Bharti and
Agnihotri, *Declared vs. Observed: Measuring the Binding Gap in MCP Tool
Declarations*, doi.org/10.5281/zenodo.22649163, section 4, CC BY 4.0.


## What these properties do not cover

Stated here so the set is not read as a completeness claim. Each of these is a real
question and none of the nine touches it.

**Enrolment.** Every property begins after an identity exists. Enrolment itself is
typically a one-time token, and whoever holds it becomes the identity it names. That
is a bearer credential at the front of an architecture built to remove bearer
credentials. Replay, reuse and post-expiry use of an enrolment token are testable and
are not tested here.

**Where the trust went.** Reachability governed by topology fails one segment at a
time. Reachability governed by a control plane fails all at once, because the control
plane is what grants every path. The trade is a broad low-value surface for a narrow
total one, which is a good trade only if the narrow one is defended accordingly. These
properties assume a correct control plane and evidence nothing about it.

**Behaviour under control-plane partition.** Continuous conditionality implies a
dependency on the evaluator being reachable. If established sessions survive an
unreachable controller then authority is not continuously conditional; if they do not
then a control-plane outage is a total outage. Both are defensible, they are different
systems, and the difference is measurable. Nothing here measures it.

**Visibility for the defender.** A path that exists only between two authorised
endpoints is not on a wire anyone can capture. Evidence then comes from the control
plane, making it the sole witness to its own enforcement. These properties consume that
record rather than corroborate it.

**Scope of action within an authorised path.** An entitled identity doing something it
should not is outside reachability entirely. The reachable graph bounds what can be
attempted, not what is done inside it.

## Scope of a passing result

A full pass evidences that these properties hold **for the implementation and
configuration under test, at the recorded commit, under the recorded discovery
method**. It does not evidence that they hold for the model in general, that the
implementation is free of other defects, or that any path outside the enumerated
surface was examined.
