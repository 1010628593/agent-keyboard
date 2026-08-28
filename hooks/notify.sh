#!/bin/sh
# Map an agent lifecycle event to Agent Keyboard status, then POST :7420.
# Usage:
#   notify.sh <agent> [event-name]
#   echo '{"hook_event_name":"PreToolUse"}' | notify.sh claude
set -eu
AGENT=${1:?agent id or slot}
EVENT=${2:-}
ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -z "$EVENT" ] && [ ! -t 0 ]; then
  payload=$(cat)
  EVENT=$(printf '%s' "$payload" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  if [ -z "$EVENT" ]; then
    EVENT=$(printf '%s' "$payload" | sed -n 's/.*"event"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  fi
fi

STATUS=running
case "$EVENT" in
  SessionStart|session_start|on_session_start|UserPromptSubmit|user_prompt_submit|beforeSubmitPrompt|pre_llm_call|running|thinking)
    STATUS=running ;;
  PreToolUse|pre_tool_use|pre_tool_call|post_tool_call|beforeShellExecution|beforeMCPExecution|tool)
    STATUS=tool ;;
  PermissionRequest|pre_approval_request|Notification|approval)
    STATUS=approval ;;
  Stop|post_llm_call|on_session_end|afterAgentResponse|session.idle|done|completed)
    STATUS=done ;;
  PostToolUseFailure|StopFailure|error|failed)
    STATUS=error ;;
  idle)
    STATUS=idle ;;
esac

exec "$ROOT/agent-status.sh" "$AGENT" "$STATUS"
