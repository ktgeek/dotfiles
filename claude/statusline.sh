#!/bin/sh
# statusLine.command wrapper: pipes the statusline JSON Claude Code feeds on stdin into oh-my-posh
# with this payload's theme. It is a script rather than an inline command so the "degrade
# gracefully if the binary is missing" guard below has somewhere to live - relevant because
# install-claude is opt-in and separate from install-mac/install-linux, so a machine could have
# one without the other.
command -v oh-my-posh >/dev/null 2>&1 || exit 0

oh-my-posh claude --config "$HOME/.claude/statusline.omp.json"
