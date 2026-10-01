#!/bin/sh
# UserPromptSubmit hook: lets Keith flip write-scope-ask.sh's edit prompt off for the rest of
# THIS session by typing a magic whole-line prompt, without leaving auto mode (Shift+Tab to
# acceptEdits would do that, and he wants to stay in auto mode - see the plan this shipped
# with). Recognizes exactly:
#
#   edit-gate off   - create this session's sentinel; write-scope-ask.sh goes quiet for it
#   edit-gate on    - remove it; back to asking on every edit
#   edit-gate       - report current state, changes nothing
#
# Any other prompt: emits nothing (-> no decision, falls through to the model as normal).
# Whitespace-only differences (leading/trailing space) are tolerated; anything else - a prompt
# that merely *mentions* "edit-gate", extra words - is treated as ordinary prompt text, not a
# command, so this can never misfire on something Keith typed for the model.
. "$HOME/.claude/hooks/edit-gate-common.sh"

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

[ -n "$session_id" ] || exit 0

sentinel=$(edit_gate_sentinel "$session_id")

case "$prompt" in
"edit-gate off")
	mkdir -p "$EDIT_GATE_DIR"
	: >"$sentinel"
	reason="edit gate is now OFF for this session - write-scope-ask.sh will stay quiet on edits until 'edit-gate on'"
	;;
"edit-gate on")
	rm -f "$sentinel"
	reason="edit gate is now ON for this session - edits inside the project tree will prompt again"
	;;
"edit-gate")
	if [ -e "$sentinel" ]; then
		reason="edit gate is currently OFF for this session"
	else
		reason="edit gate is currently ON for this session"
	fi
	;;
*)
	exit 0
	;;
esac

jq -cn --arg reason "$reason" '{decision: "block", reason: $reason}'
