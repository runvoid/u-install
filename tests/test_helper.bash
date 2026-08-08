#!/usr/bin/env bash
# Shared setup for u-install bats tests.
#
# The library derives every path (config file, package database) from $HOME,
# so pointing $HOME at a per-test temp directory fully isolates the tests and
# lets us exercise the pure helper functions without touching the real system.

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export PROJECT_ROOT

setup() {
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "$HOME"
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/u-install.sh"
}
