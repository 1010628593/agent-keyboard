#!/bin/sh
# Cycle the default Codex slot through every Agent scene.
# Requires: agent-keyboard serve  (or pass --direct after starting nothing)
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python -m agent_keyboard send "${1:-codex}" idle
sleep 1
python -m agent_keyboard send "${1:-codex}" running --context 0.35
sleep 2
python -m agent_keyboard send "${1:-codex}" tool --context 0.55
sleep 2
python -m agent_keyboard send "${1:-codex}" approval --context 0.55
sleep 2
python -m agent_keyboard send "${1:-codex}" done
sleep 3
python -m agent_keyboard send "${1:-codex}" error
sleep 2
python -m agent_keyboard send "${1:-codex}" idle
