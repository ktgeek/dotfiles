#!/bin/sh
# statusLine.command wrapper: oh-my-posh's `claude` segment type has no way to test whether a
# file exists, so it can't read the edit-gate sentinel (see edit-gate-common.sh) on its own.
# This reads the same statusline JSON Claude Code feeds any statusline command, pulls out
# .session_id, and exports CLAUDE_EDIT_GATE=off when that session's sentinel is present -
# statusline.omp.json's ungated badge segment keys off that env var. Then re-emits the exact
# same JSON to oh-my-posh, unchanged.
#
# Same "hard dependency, degrade gracefully if the binary is missing" guard the fragment's old
# inline command used - relevant because install-claude is opt-in and separate from
# install-mac/install-linux, so a machine could have one without the other.
command -v oh-my-posh >/dev/null 2>&1 || exit 0

. "$HOME/.claude/hooks/edit-gate-common.sh"

input=$(cat)

if edit_gate_is_open "$input"; then
	export CLAUDE_EDIT_GATE=off
fi

printf '%s' "$input" | oh-my-posh claude --config "$HOME/.claude/statusline.omp.json"
