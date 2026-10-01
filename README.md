# dotfiles

Keith's personal configs for zsh, Emacs, git, ssh, tmux, and a handful of other tools,
for macOS and Ubuntu/Debian. Installed by symlinking files out of this repo into `$HOME`.

The private, self-hosted copy of this repo has no GitHub, no PRs, no CI — changes land as direct
commits to `main`. A generic, public-safe snapshot (excluding personal/home-network content —
see "Publishing a public snapshot" below) is also published via `make publish-public`.

For the exhaustive rationale behind specific decisions (why oh-my-posh instead of p10k, why
Zim instead of a submodule, ordering constraints in `.zshrc`, etc.), see `AGENTS.md` — it's
written for AI assistants and goes deeper than this file needs to.

## New machine

```
git clone <your-dotfiles-remote> ~/dotfiles
cd ~/dotfiles
make install-mac        # or: make install-linux
```

**`make` must be run from the repo root.** The Makefile sets `SRC=${PWD}`, read from the
environment — `make -C ~/dotfiles` or `make -f ~/dotfiles/Makefile` from elsewhere leaves `PWD`
pointing at the wrong directory, and every `ln -sf $(SRC)/…` silently creates dangling symlinks.

### What each target pulls in

- `all` — zsh, emacs, vim, git, sqlite, tmux, irbrc, rspec
- `install-mac` — Homebrew (itself, then its packages), `all`, plus keybindings, lsd config,
  `defaults write` tweaks, TouchID-for-sudo
- `install-linux` — `all`, plus `.toprc`, an apt package list, oh-my-posh

### This asks for network, sudo, or otherwise needs your consent

- `install-homebrew` — curls the Homebrew installer (skipped if `brew` is already on `PATH`),
  runs `xcode-select --install` (skipped if already present)
- `install-homebrew-packages` — taps `d12frosted/emacs-plus` and installs ~30 formulae plus the
  `emacs-plus-app` cask
- `install-linux-packages` — `sudo apt update && sudo apt install …`
- `install-defaults` — two `sudo defaults write` calls
- `install-mac-sudo-touchid` — writes `/etc/pam.d/sudo_local`
- `install-oh-my-posh` — `curl | bash` into `~/bin` (Linux only; macOS gets it from Homebrew)
- `install-emacs` — hits ELPA/MELPA over the network to restore `package-selected-packages`
- `install-claude` — merges gating rules and the oh-my-posh statusline config into
  `~/.claude/settings.json` (backs up the previous copy first) and, if there are local
  `autoMode.soft_deny` rules or hook commands (any event — `PreToolUse`, `UserPromptSubmit`) the
  repo doesn't know about, prompts once per item to keep or drop it

### After `make` finishes

- **First zsh login needs network.** `.zshrc` self-installs Zim (the plugin manager) on first
  run if it's missing — no completions, syntax highlighting, or autosuggestions until that
  succeeds. Every other optional tool (`vivid`, `lsd`, `bat`) degrades silently offline; Zim and
  oh-my-posh don't.
- Create `~/.zsh/.zshenv-local` and `~/.zsh/.zshrc-local` for anything machine-specific — they're
  sourced last and deliberately not tracked.
- Pick a Nerd Font in the terminal, or the prompt (oh-my-posh, `kgarner.omp.json`) renders as
  broken glyphs — same requirement for the Ghostty config's `font-family` list.

### Opt-in targets (not part of any aggregate — run by hand)

`install-ssh`, `install-etags`, `install-mac-code`, `procmail`, `install-toprc`
(only `install-linux` pulls it in as a prerequisite). `install-lsd` is wired into `install-mac`
by default now; still opt-in on Linux. `install-ghostty` symlinks `.config/ghostty` into
`~/.config`; `install-ghostty-terminfo` is a one-time step that makes `xterm-ghostty` resolvable
to processes Ghostty didn't launch itself (e.g. tmux) — see `bin/ghostty-terminfo` for the
remote-host equivalent. `install-claude` ports Claude Code's working-style memory and
permission-gating settings into `~/.claude` — kept opt-in because it **fails outright if
`~/.claude/CLAUDE.md` already exists** and isn't a symlink into this repo's `claude/` directory
(move it aside first); see `AGENTS.md` for the full merge behavior. `publish-public` pushes a
public snapshot — see "Publishing a public snapshot" below.

## Publishing a public snapshot

This repo stays private and self-hosted, but a generic, public-safe copy can be shared without
dragging along either git history or personal content: `make publish-public` builds a snapshot of
the current `main` via `git archive` and force-pushes it as a single commit to
`git@github.com:ktgeek/dotfiles.git` (override with `PUBLIC_REMOTE=`/`PUBLIC_BRANCH=`). Because
`git push` only ever transfers objects reachable from the ref it pushes, no history — not this
repo's, not a previous public snapshot's — ever leaves this machine.

A handful of tracked files are marked `export-ignore` in `.gitattributes`, so `git archive` omits
them from that snapshot even though they stay tracked and installed here (needed for disaster
recovery and reuse across Keith's own machines, just not for outside eyes): `.ssh/config-personal`,
`.gitconfig-work`, `.gitconfig-joba`, `procmailrc.m4`, `procmail-base.m4`. This is a different
mechanism from the untracked `-local` files (`.zshenv-local`, `.zshrc-local`,
`.config/ghostty/config-local`) — those are for genuinely single-machine overrides that were never
tracked at all; `export-ignore`d files are common across all of Keith's machines and fully
version-controlled, just excluded from what gets published.

## Where things live

| Path | What it is |
|---|---|
| `Makefile` | the installer — symlinks everything below into `$HOME` |
| `.zsh/.zshenv` | env only: `PATH`, `HISTFILE`, pager setup, chruby bootstrap |
| `.zsh/.zshrc` | interactive only: Zim init, aliases, completion, oh-my-posh |
| `.zsh/.zimrc` | list of Zim modules/plugins (order matters — see AGENTS.md) |
| `.zsh/kgarner.omp.json` | the oh-my-posh prompt theme |
| `.emacs` | Emacs bootstrap only: PATH fix, `package-initialize`, the Custom block |
| `.elisp/common-config.el` | the real Emacs config hub, loaded from `after-init-hook` |
| `.elisp/customize-*.el` | per-language Emacs config, loaded by `common-config.el` |
| `.gitconfig` | git config; personal identity (`user.email`) is set directly here |
| `.gitconfig-work` / `.gitconfig-joba` | work git identity, `includeIf`-gated on a second work directory; tracked here but not meant to leave this machine's repo |
| `.ssh/config` | generic host settings and hardened cipher defaults |
| `.ssh/config-personal` | home-network host aliases/LAN topology; tracked here but not meant to leave this machine's repo |
| `procmailrc.m4`, `procmail-base.m4` | mail filtering rules |
| `.tmux.conf` | tmux config (`C-a` prefix) |
| `.vimrc` | vim |
| `.config/lsd/config.yaml` | `lsd` (modern `ls`) config |
| `.config/ghostty/config` | Ghostty terminal config, ported from iTerm2 |
| `.toprc` | Linux `top` layout (unused on macOS) |
| `.irbrc` / `.rspec` / `.sqliterc` | Ruby / RSpec / sqlite3 REPL config |
| `bin/` | `etags`, `vstags` — symlinked to `~/bin`; `ghostty-terminfo`, `claude-merge-settings` — run from the repo, not installed |
| `Library/KeyBindings/DefaultKeyBinding.dict` | macOS-wide emacs-style text editing keys |
| `AGENTS.md` (`CLAUDE.md` → symlink) | the deep-dive doc for AI assistants |
| `claude/user-CLAUDE.md` | Claude Code working-style memory, symlinked to `~/.claude/CLAUDE.md` |
| `claude/settings-gating.json` | the permission-gating keys (plus `statusLine`) merged into `~/.claude/settings.json` |
| `claude/statusline.omp.json` | the oh-my-posh theme for Claude Code's statusline, symlinked to `~/.claude/statusline.omp.json` |
| `claude/statusline.sh` | wraps that theme with the oh-my-posh invocation, so it can add the edit-gate badge; symlinked to `~/.claude/statusline.sh` |
| `claude/hooks/*.sh` | `PreToolUse`/`UserPromptSubmit` hooks (write-scope, `gh api` write-gating, the edit-gate toggle), glob-symlinked to `~/.claude/hooks/` |

### I want to change…

- the prompt → `.zsh/kgarner.omp.json`
- `PATH` or an env var → `.zsh/.zshenv`
- an alias or completion behavior → `.zsh/.zshrc`
- which zsh plugins load → `.zsh/.zimrc`, then run `zimfw install`
- Emacs behavior for a language → `.elisp/customize-<lang>.el`
- the Emacs package list → `package-selected-packages` in `.emacs`
- an ssh host → `.ssh/config` (generic) or `.ssh/config-personal` (home-network/LAN)
- something specific to one machine → `~/.zsh/.zshrc-local` (untracked, not this repo)

## How the install works

`ln -sf` from the repo into `$HOME` — **editing `~/.zshrc` edits this repo directly.** Run
`ls -l ~/.zshrc` if that's ever in doubt. A brand-new dotfile needs its own `install-*` target,
plus adding to `all` / `install-mac` / `install-linux` if it should install by default.

Two things in the tree don't follow the symlink rule: `Library/KeyBindings/DefaultKeyBinding.dict`
is **copied**, not linked, so an edit to the repo file needs `make install-keybindings` re-run
to take effect; and `~/.procmailrc` is **generated** by `m4` from `procmailrc.m4` /
`procmail-base.m4`, not linked at all.

## Checking a change

No test suite — spot-check by area:

- zsh: `zsh -ic exit` (a real-PTY run, e.g. `script -q /dev/null zsh -i -c exit`, is the more
  reliable check — a plain `zsh -ic exit` prints two spurious `can't change option: zle` warnings
  from fzf's key-bindings script saving/restoring shell options outside a real terminal; not a
  config bug)
- ssh: `ssh -G <host>`
- Emacs: open a fresh `emacs` (or `emacs -nw`). `emacs -Q --batch -l ~/.emacs` looks clean but
  tests nothing real, because `common-config.el` only loads via `after-init-hook`, which plain
  `--batch -l` never fires. Use:
  `emacs --batch -l ~/.emacs --eval "(run-hooks 'after-init-hook)"`
- elisp byte-compile check: `cd .elisp && emacs -Q --batch -f batch-byte-compile *.el`
- Makefile target: `make -n <target>` to preview before running

Commits: lowercase `area: what changed`, imperative subject, one logical change per commit.

## Open items

Known and deliberate — a running list, not a to-do backlog to attack blindly.

- [ ] The ohmyzsh `gnu-utils` Zim module and the `.zshenv` gnubin `PATH` entries are a similar
      trial — `gnu-utils` is active; the four tool-specific `PATH` lines (coreutils/gnu-tar/
      findutils/make) were deleted outright, leaving only one generic commented `PATH` line to
      uncomment plus those four to re-add if reverting. `gnu-utils` only reaches interactive
      shells, so a script or cron job still sees BSD `ls`/`sed`/`tar`.
- [ ] `.rar` is deliberately unsupported — `unrar` is proprietary and not in homebrew-core or
      Ubuntu's default repos. Not a bug, just a known gap.
