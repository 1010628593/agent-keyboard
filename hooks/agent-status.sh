#!/bin/sh
# Notify the Agent Keyboard daemon of a status change.
# Usage: agent-status.sh <agent> <status> [context]
#   ./hooks/agent-status.sh codex running 0.42
#   ./hooks/agent-status.sh f2 approval
set -eu
AGENT=${1:?agent id or slot}
STATUS=${2:?status}
CONTEXT=${3:-0}
HOST=${AGENT_KEYBOARD_URL:-http://127.0.0.1:7420/event}
exec curl -sS -X POST "$HOST" \
  -H 'content-type: application/json' \
  -d "{\"agent\":\"${AGENT}\",\"status\":\"${STATUS}\",\"context\":${CONTEXT}}"
