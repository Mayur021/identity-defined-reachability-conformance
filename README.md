# Identity-Defined Reachability conformance

An implementation-neutral property set, with acceptance criteria and an evidence
harness, for the claims made by identity-defined reachability: that a usable path to
a protected service is absent by default, that entitlement rather than topology is
the unit of access, that an authorised relationship survives a change of network
location without touching the network, and that permission to one service confers no
adjacency to its neighbours. Three further properties cover what a withdrawal does
to everything it was not aimed at, whether it lands inside a bound stated in advance,
and what becomes of an authorised path when the evaluator cannot be reached.

The properties are the artifact. Any implementation is one row in `RESULTS.md`.

## Why

Identity-defined reachability makes claims that are mostly negatives: a path is absent,
an unentitled identity has none, permission confers no adjacency. Negatives are the
hardest class of claim to evidence and the easiest to assert. "Dark needs to be
testable", in Philip Griffiths' phrase, and a negative is only as good as the sweep
that produced it.

This repository exists so that a third party can decide pass or fail from recorded
evidence, without reading anyone's configuration.

## Provenance

The properties derive from the identity-defined reachability post series and from the
CSA blog [AI-Speed Risk Requires Identity-Defined
Reachability](https://cloudsecurityalliance.org/articles/ai-speed-risk-requires-identity-defined-reachability)
(Philip Griffiths, 2 July 2026), together with the public discussion on those posts.

Two of them are his directly. The default-deny formulation behind P1, that no
authorised identity should mean no service route, no application session, no permitted
data packet and no service visibility, is four separate negatives rather than one, and
each is judged on its own here. P7, authority remaining conditional for the life of the
session rather than only at establishment, he raised as a core design principle.

The properties are stated independently of any implementation, which is the point of
writing them down separately from the argument they support.

## Layout

| Path | What it is |
|---|---|
| `properties/IDR-PROPERTIES.md` | Ten properties with acceptance criteria. Implementation-neutral. |
| `fixtures/idr.yaml` | The same ten as machine-readable fixtures with expected outcomes and failure conditions. |
| `harness/fingerprint.sh` | Configuration-invariance capture for P3, P5, P7 and P10. |
| `harness/compare.sh` | Fingerprint comparison, after re-deriving each capture from its own manifest. Exit 0 identical, 1 drift, 2 an excepted component did not move, 3 the capture was altered after it was written. |
| `harness/egress.sh` | Externally observed public egress for P3, from several independent observers that must agree. |
| `harness/relocate.sh` | P3 adjudicator over two vantage records. Decides the conjunctive claim, offline. |
| `harness/environment.sh` | Captures what was tested, by whom, on what, and the limits that bound the run. |
| `harness/discover.sh` | Discovery sweep for the negative properties. Emits the discovery block. |
| `harness/session_watch.py` | Established-session liveness for P5 and P7. Records last byte delivered. |
| `METHOD.md` | What a negative means here, and what it does not. |
| `RESULTS.md` | Run table. Empty until a run is recorded. |

## The three outcomes

`PASS`, `FAIL`, and `NOT_ESTABLISHED`. The third is not a soft fail. It records that
the evidence required to judge the property was not produced: no discovery block, no
in-window positive control, or an egress address asserted rather than observed.
Rounding NOT_ESTABLISHED to PASS is the specific failure this suite exists to
prevent.

## Status

Properties and fixtures: complete, ten of each.

Harness: every script is written and tested in both directions, and CI proves it on
each push. The fingerprint returns an identical digest across two captures with no
change and detects a single added route. `compare.sh` re-derives each capture from its
own manifest before comparing anything, and refuses a capture whose component file was
edited after it was written, which the recorded digests alone would not have caught.
The discovery sweep reports no path against closed targets and detects a live listener
as a positive control. The session watch records last-byte-delivered when an
established connection is torn down mid-flight, and exits 2 rather than reporting a
false end when the session never established. `egress.sh` returns NOT_ESTABLISHED on a
single observer and on disagreement between observers, and an address only when
independent observers agree. `relocate.sh` decides P3 across all seven of its branches.

**What is still lab work, and what is not.** P3 needs two vantage points with
genuinely different public egress. That has not changed and no script can change it.
What has changed is that the rest of P3 is now script work: `egress.sh` produces the
externally observed vantage record at each location, and `relocate.sh` adjudicates the
pair offline afterwards. The remaining step is to run the first at two places and carry
the two directories to one host. A run is still a run.

No runs recorded. `RESULTS.md` is empty by design until one is.


## Relationship to the AISVS C9 action-class suite

The method here is inherited rather than invented. It comes from
[`aisvs-c9-action-class-conformance`](https://github.com/Mayur021/aisvs-c9-action-class-conformance),
an independent conformance suite for the action-class and reversibility controls in
OWASP AISVS C9, and the conventions carry
over unchanged:

- three outcomes, with NOT_ESTABLISHED a first-class result rather than a soft fail
- fixtures that declare expected outcomes and explicit failure conditions, so a run is
  judged against the fixture and not against the runner's opinion
- a results table whose provenance columns (self-reported, re-runnable, run origin,
  artifact hash) are what separate evidence from an assertion
- a negative is only as strong as the discovery that produced it

They are deliberately separate repositories. Different standard, different body, and
the C9 suite publishes an N of M that belongs to action-class scenarios alone. Adding
reachability properties to it would move that denominator for an unrelated reason.

One technical point does bridge them. AISVS C9.2.10 folds a multi-step chain to the
highest-impact classification present anywhere in it. Any reachability framework that
cites that fold as a control inherits an open question with it: the rule says nothing
about who establishes the chain's extent, and where the agent supplies its own plan the
fold is computed over a set the gated party chose. That is recorded in
`properties/IDR-PROPERTIES.md` as explicitly outside the ten properties, so they are
not read as covering something they do not test.

That open edge is not an original observation here. It is stated in Bharti and
Agnihotri, [Declared vs. Observed: Measuring the Binding Gap in MCP Tool
Declarations](https://doi.org/10.5281/zenodo.22649163), section 4, CC BY 4.0.

## Licence

Apache-2.0.
