# Sourced by edit-gate-toggle.sh, write-scope-ask.sh, and statusline.sh (not a hook itself - no
# shebang, no exec bit). Keeps the sentinel directory AND the "is this session's gate open"
# question in one place, rather than each caller re-deriving them - a session_id-extraction
# copy that skipped the empty-session_id guard is exactly how this went wrong the first time
# (see the review that caught it): write-scope-ask.sh and statusline.sh each had their own copy
# of this logic, and only one of the three ever got the guard.
#
# Deliberately lives outside ~/.claude: write-scope-ask.sh lets writes under ~/.claude through
# silently (that's where Claude Code's own working files live), so a sentinel directory there
# would be a gate the model could flip off by writing to its own config, unnoticed. This path
# gets its own "always ask" carve-out in write-scope-ask.sh instead, and its own autoMode.
# soft_deny line for the Bash side (see claude/settings-gating.json).
EDIT_GATE_DIR="$HOME/.local/state/claude-edit-gate"

# edit_gate_sentinel <session_id> -> path to that session's sentinel file. A session is
# "ungated" for the rest of its life (no expiry - see AGENTS.md plan) exactly when this file
# exists; session IDs are unique, so a sentinel left behind by an ended session does no harm.
edit_gate_sentinel() {
	printf '%s/%s' "$EDIT_GATE_DIR" "$1"
}

# edit_gate_is_open <hook-input-json> -> exit 0 (true) if the session that produced this hook
# call has its edit gate open, exit 1 (false) otherwise. Fails CLOSED on a missing/empty
# session_id rather than falling through to edit_gate_sentinel(""), which would resolve to
# "$EDIT_GATE_DIR/" - the sentinel directory itself - and read as "open" forever once ANY
# session has ever toggled the gate on, since the directory persists by design. That exact
# collapse is what let one session's toggle silently disable every other session's write
# prompt; guarding it here, once, means every caller gets the fix instead of needing its own
# copy of the check.
edit_gate_is_open() {
	session_id=$(printf '%s' "$1" | jq -r '.session_id // empty')
	[ -n "$session_id" ] || return 1
	[ -e "$(edit_gate_sentinel "$session_id")" ]
}
