#!/usr/bin/env bash
# Environment capture. Runs once per run, before anything else.
#
# A result whose conditions cannot be reconstructed is not evidence, it is an
# anecdote. This records what was true when the properties were exercised, so a
# reader can tell whether a later run differs because the implementation changed
# or because the bench did.
#
# IMPLEMENTATION and IMPL_VERSION are required. The suite cannot guess what it was
# pointed at, and a row in RESULTS.md without them means nothing.
#
# Usage: IMPLEMENTATION=<name> IMPL_VERSION=<ver> environment.sh <outdir>
set -uo pipefail
OUT="${1:?usage: environment.sh <outdir>}"; mkdir -p "$OUT"
F="$OUT/environment"
: "${IMPLEMENTATION:?set IMPLEMENTATION, e.g. openziti}"
: "${IMPL_VERSION:?set IMPL_VERSION, e.g. v1.6.20}"

{
  echo "captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "# what was tested"
  echo "implementation: $IMPLEMENTATION"
  echo "implementation_version: $IMPL_VERSION"
  echo "deployment_shape: ${DEPLOYMENT_SHAPE:-NOT_DECLARED}"
  echo
  echo "# who ran it"
  echo "runner: ${RUNNER_NAME:-NOT_DECLARED}"
  echo "runner_is_suite_author: ${RUNNER_IS_AUTHOR:-NOT_DECLARED}"
  echo "run_origin: ${RUN_ORIGIN:-NOT_DECLARED}"
  echo
  echo "# which suite"
  echo "suite_commit: $(git -C "$(dirname "$0")/.." rev-parse HEAD 2>/dev/null || echo NOT_A_GIT_CHECKOUT)"
  echo "suite_dirty: $(git -C "$(dirname "$0")/.." status --porcelain 2>/dev/null | wc -l) files modified"
  echo
  echo "# the bench"
  echo "os: $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || uname -s)"
  echo "kernel: $(uname -r)"
  echo "arch: $(uname -m)"
  echo "container_runtime: $(docker --version 2>/dev/null || echo none)"
  echo "vantage_host: $(hostname)"
  echo
  echo "# limits that bound what this run can evidence"
  echo "distinct_public_egress_available: ${EGRESS_POINTS:-NOT_DECLARED}"
  echo "posture_signals_configured: ${POSTURE_CONFIGURED:-NOT_DECLARED}"
} > "$F"
cat "$F"
