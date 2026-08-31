#!/bin/sh
# Map agent lifecycle events to Agent Keyboard status.
# Usage: notify.sh <agent> [event-name]
AGENT=${1:?agent}
EVENT=${2:-}
INPUT=""
ROOT="$(cd "$(dirname "$0")" && pwd)"

extract_json_field() {
  local key="$1"
  printf '%s' "$INPUT" | tr '\n' ' ' | sed -n "s/.*\\\"${key}\\\"[[:space:]]*:[[:space:]]*\\\"\\([^\\\"]*\\)\\\".*/\\1/p"
}

if [ ! -t 0 ]; then
  INPUT=$(/usr/bin/python3 "$ROOT/stdin-peek.py" 2>/dev/null || true)
fi
# Cursor dual-loads ~/.claude/settings.json. Never post those as Claude,
# and never remap them onto Cursor — ~/.cursor/hooks.json owns F4.
if [ "$AGENT" != "cursor" ]; then
  if printf '%s' "$INPUT" | grep -q '"cursor_version"'; then
    printf '%s\n' '{}'
    exit 0
  fi
fi
if [ "$AGENT" = "claude" ] && [ -z "$INPUT" ] && [ -z "${CLAUDECODE:-}${CLAUDE_CODE:-}" ]; then
  printf '%s\n' '{}'
  exit 0
fi
if [ -z "$EVENT" ] && [ -n "$INPUT" ]; then
  EVENT=$(extract_json_field "hook_event_name")
  if [ -z "$EVENT" ]; then
    EVENT=$(extract_json_field "event_name")
  fi
  if [ -z "$EVENT" ]; then
    EVENT=$(extract_json_field "event")
  fi
  if [ -z "$EVENT" ]; then
    EVENT=$(extract_json_field "name")
  fi
fi
EVENT_KEY=$(printf '%s' "$EVENT" | tr 'A-Z' 'a-z' | tr '-' '_' | tr '.' '_')
STATUS=running
case "$EVENT_KEY" in
  sessionstart|session_start|on_session_start|userpromptsubmit|user_prompt_submit|beforesubmitprompt|pre_llm_call|running|thinking|afteragentthought)
    STATUS=running ;;
  pretooluse|pre_tool_use|posttooluse|post_tool_use|pre_tool_call|post_tool_call|beforeshellexecution|beforemcpexecution|tool)
    STATUS=tool ;;
  permissionrequest|pre_approval_request|notification|approval)
    STATUS=approval ;;
  stop|stop_completed|post_llm_call|on_session_end|afteragentresponse|session_idle|done|completed)
    STATUS=done ;;
  posttoolusefailure|stopfailure|stop_error|error|failed)
    STATUS=error ;;
  idle)
    STATUS=idle ;;
esac
if [ "$AGENT" = "cursor" ]; then
  case "$EVENT_KEY" in
    sessionstart|session_start)
      printf '%s\n' '{}'
      exit 0 ;;
    afteragentresponse)
      STATUS=running ;;
    pretooluse|pre_tool_use)
      TOOL=$(printf '%s' "$INPUT" | tr '\n' ' ' | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
      case "$TOOL" in
        Read|Grep|Glob|Ripgrep|ReadFile|SemanticSearch) STATUS=running ;;
        *) STATUS=tool ;;
      esac
      ;;
    stop)
      STOP_STATUS=$(printf '%s' "$INPUT" | tr '\n' ' ' | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr 'A-Z' 'a-z')
      case "$STOP_STATUS" in
        error|aborted|failed) STATUS=error ;;
        *) STATUS=done ;;
      esac
      ;;
  esac
fi
"$ROOT/agent-status.sh" "$AGENT" "$STATUS" || true
printf '%s\n' '{}'
exit 0
