#!/bin/sh
# PreToolUse hook (Edit|Write|NotebookEdit): force a permission prompt for writes
# inside the invocation tree, while leaving Claude Code's own files under ~/.claude
# to proceed silently. Emits nothing (-> no decision) for anything else.
#
# Two exceptions, both about edit-gate-toggle.sh's per-session sentinel
# ($HOME/.local/state/claude-edit-gate/<session_id> - see edit-gate-common.sh):
#   - this session's OWN sentinel, if present, silences the ask below entirely -
#     that's the whole point of the toggle (typed prompt, not Shift+Tab, so Keith
#     can stay in auto mode - see the plan this shipped with). edit_gate_is_open
#     fails closed (treats the gate as NOT open) on a missing session_id, rather
#     than resolving to the sentinel directory itself - see its own comment for
#     why that distinction matters.
#   - a write INTO the sentinel directory always asks regardless, even though it's
#     outside the cwd and wouldn't otherwise match the "inside the project tree"
#     rule below - otherwise the model could create or remove a sentinel itself
#     (e.g. via Write) and quietly flip its own edit gate.
. "$HOME/.claude/hooks/edit-gate-common.sh"

input=$(cat)

gate_open="false"
edit_gate_is_open "$input" && gate_open="true"

# NotebookEdit's tool_input key is notebook_path, not file_path - falling back to it keeps this
# one filter covering all three matched tools instead of needing a per-tool branch.
printf '%s' "$input" | jq -c --arg gate_dir "$EDIT_GATE_DIR" --argjson gate_open "$gate_open" '
  . as $i
  | ($i.tool_input.file_path // $i.tool_input.notebook_path // "") as $f
  | if ($f | startswith($gate_dir + "/"))
    then {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask",
                               permissionDecisionReason: "write into the edit-gate sentinel directory"}}
    elif $gate_open
    then empty
    elif ($f | startswith($i.cwd + "/")) and (($f | startswith(env.HOME + "/.claude/")) | not)
    then {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask",
                               permissionDecisionReason: "Edit inside the project tree"}}
    else empty
    end'
