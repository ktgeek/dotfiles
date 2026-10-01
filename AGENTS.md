# AGENTS.md

Guidance for AI coding assistants working in this repository. (`CLAUDE.md` in this repo is a
symlink to this file, kept so tools that specifically look for that name still find it.)

## Working agreements

- **Plan before changing anything.** Any change to this repo starts with a written plan, agreed
  before edits begin. If your tooling has a dedicated planning or read-only mode, use it; if not,
  write the plan out and get agreement first. Every plan must include a checklist of discrete
  steps, so work can be paused and resumed — by this session or a different assistant — without
  losing the thread. Keep the checklist updated as steps complete.
- **Commits are atomic and as small as possible.** One logical change per commit: each commit
  should stand on its own, be independently revertible, and leave the configs in a working state.
  Don't bundle unrelated fixes — e.g. an Emacs change and a zsh change are two commits, even from
  the same session. Follow the existing message style (see Conventions below).
- **Keep this file current.** It's a living document. Any change that affects what's described
  here — new Makefile targets, restructured config, changed conventions — updates this file in
  the same change. If work invalidates something written here, fix the text; don't leave it
  stale. Per-tool detail (zsh, Emacs, Ghostty, the Claude Code payload) lives in the matching
  `.claude/skills/*-config` skill instead of this file — a resolved "Known leftovers" item or a
  changed gotcha updates that skill, not this one. See "Where the detail lives" below.

## What this repo is

Keith Garner's personal dotfiles, tracked in git.

**This is a private repository on a personal server in Keith's house — not generally accessible to
anyone else.** `origin` is a self-hosted bare repo reached over SSH; there is no GitHub/GitLab/forge
remote.

Practical consequences: there's no PR workflow, no CI, and no external reviewer — changes land as
direct commits to `main`, pushed to that self-hosted origin. This is also why most personal
details (hostnames, mail address) are committed in the clear: that's intentional for this repo, not
an oversight to clean up.

A public, generic copy is also shared from this repo (`make publish-public`, see README.md) — a
history-free snapshot pushed to a separate GitHub remote. A handful of tracked files that are
personal but not secret-enough to drop entirely (`.ssh/config-personal`, `.gitconfig-work`,
`.gitconfig-joba`, `procmailrc.m4`, `procmail-base.m4`) are marked `export-ignore` in
`.gitattributes` specifically so they're excluded from that snapshot while staying tracked here.
Anything new added to this repo that's personal-but-not-secret enough to keep private-but-tracked
needs the same treatment — don't assume "committed here" still means "safe to be public" without
checking `.gitattributes`. An identifying name can also leak through a *reference* to an
export-ignored file — its filename spelled out in the `Makefile`, `.gitattributes` itself, or prose
in `README.md`/`AGENTS.md`/a skill doc — even when the export-ignored file's own contents never
ship; a generic filename (like `.gitconfig-work`, not `.gitconfig-<employer>`) avoids the problem
at the source.

## The symlink model

The central fact about this repo: `Makefile` targets `ln -sf` each config from the repo root
(`$SRC`, i.e. `${PWD}`) into `$HOME`. Consequences:

- Editing a file under `~/` edits the repo file directly. Check with `ls -l ~/.zshrc` before
  assuming it's a copy.
- Adding a brand-new dotfile requires a matching `install-*` target in `Makefile`, plus adding it
  to the `all` / `install-mac` / `install-linux` prerequisite lists if it should install by default.
- `make` must be run **from the repo root** — `SRC=${PWD}` — or it creates broken links.

## Commands

From `Makefile`:

- `make install-mac` runs `install-homebrew` and `install-homebrew-packages` before `all`,
  since `install-emacs` needs `emacs` on `PATH`.
- `make install-linux` runs `install-linux-packages` — the apt analog of
  `install-homebrew-packages`'s Brewfile — plus `install-oh-my-posh`, since there's no apt
  package for it.
- Byte-compile elisp (convention noted at the top of `.elisp/common-config.el`):
  `cd .elisp && emacs -Q --batch -f batch-byte-compile *.el` — `*.elc` is gitignored
- Verifying a change (there's no test suite): `zsh -ic exit` for shell config, `ssh -G <host>` for
  `.ssh/config`. For elisp, a fresh `emacs` (or `emacs -nw`) is the reliable check — **`emacs -Q
  --batch -l ~/.emacs` alone is not**: `common-config.el` only loads via the `after-init-hook` that
  `.emacs` registers, and plain `--batch -l` never fires that hook, so real errors inside
  `common-config.el`/`customize-*.el` are silently skipped and the run looks clean. To actually
  exercise that code from the CLI, fire the hook explicitly:
  `emacs --batch -l ~/.emacs --eval "(run-hooks 'after-init-hook)"`. On macOS, `emacs` on PATH is
  the emacs-plus-app bundle via a Homebrew symlink, so these commands behave the same on both
  platforms — see the `emacs-config` skill.

Targets with side effects beyond symlinking need consent before running: `install-defaults` (sudo
`defaults write`), `install-mac-sudo-touchid` (writes `/etc/pam.d/sudo_local`), `install-homebrew`
(curls and executes the Homebrew installer, then `xcode-select --install` — both guarded to no-op
if already present, so re-running `install-mac` on a configured machine is safe),
`install-homebrew-packages` (taps `d12frosted/emacs-plus` and runs a long `brew install` plus the
`emacs-plus-app` cask), `install-oh-my-posh` (curls and executes the oh-my-posh install script),
`install-linux-packages` (sudo `apt update` / `apt install`), `publish-public` (force-pushes a
public snapshot to a shared GitHub remote — see "Publishing a public snapshot" in README.md).

## Where the detail lives

The per-tool references were moved out of this file so they load only when needed. **Load the
matching skill before editing any of these** — each is nothing but gotchas and ordering
constraints that will bite otherwise:

- `zsh-config` — anything under `.zsh/` (Zim module order, fzf-tab/autosuggestions Tab
  dispatch, the `tput` shim, `.zshenv` vs `.zshrc` placement)
- `emacs-config` — `.emacs` and anything under `.elisp/` (Custom-vs-`setq` clobbering,
  `load-path` shadowing, the `lexical-binding` cookie requirement)
- `ghostty-config` — `.config/ghostty/`, `bin/ghostty-terminfo`, `.tmux.conf`
- `claude-code-payload` — `claude/`, `bin/claude-merge-settings`, `install-claude`

## Conventions

- Commit messages: lowercase, `area: what changed` (e.g. `ssh: remove defunct hosts`), imperative subject line.
  Subject aims for 50 characters and must fit in 72; bodies wrap at 72 — see the Length section of the
  `commit-style` skill, not restated here. A body is optional — trivial changes stay subject-only, but
  anything with a non-obvious reason gets a body explaining *why*, not a restatement of the diff.
  The `area` plays the role of a Conventional Commits scope — e.g. `zsh`, `emacs`, `ssh`, `tmux`, `ghostty`, `claude`,
  `docs`, `packages` — but this repo departs from that default in two ways: no `type` prefix (sorting single-author
  config edits into `feat`/`fix`/`chore` adds ceremony and no signal), and the area is written bare rather than
  parenthesized, and is effectively required rather than optional. Everything else in the `commit-style` skill —
  Description, Body, Footers, Breaking changes, and its own Length and Precedence rules — still applies here.
- Commits authored by Claude get a trailing `Co-Authored-By: Claude <noreply@anthropic.com>` line —
  no session-link trailer.
