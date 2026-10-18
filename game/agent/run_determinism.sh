#!/usr/bin/env bash
# Shim (RFC-034 034k, F188): the bench lives in the kit (addons/agent_kit/determinism/det_run.sh).
#   agent/run_determinism.sh CASE|all [MODE...] [--no-window]   MODE: fixed fixed2 stress window
#   agent/run_determinism.sh quick [--no-window]                 the quick cases against agent/det_baseline.txt
#   agent/run_determinism.sh table [CASE...]                     verdict + table from agent/out/det/
# The cases (with their arguments) are in agent/det_cases.txt, the config in agent/det.cfg.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../addons/agent_kit/determinism/det_run.sh" "$HERE/det_cases.txt" "$@"
