---
name: ghostty-config
description: Ghostty terminal config for this repo, ported field-by-field from iTerm2 — verified option names/defaults, the config-local include, and the bin/ghostty-terminfo tool for making xterm-ghostty resolvable on remote hosts. Load before editing .config/ghostty/config, bin/ghostty-terminfo, or the Ghostty-related lines in .tmux.conf.
---

# Ghostty

Replaced iTerm2 as the terminal (macOS first; Linux to follow). Config lives at
`.config/ghostty/config`, symlinked by the opt-in `install-ghostty` target — one file serves both
platforms, since `~/.config/ghostty/config` is read on Linux (XDG) and on macOS (Ghostty reads
the XDG path *and* `~/Library/Application Support/com.mitchellh.ghostty/config`, XDG first, so
the tracked file wins as long as nothing writes to the Application Support one). One caveat:
macOS's own "Open Configuration" menu item prefers the Application Support path when the XDG
file is absent — a UI quirk in *which file the menu opens*, not a load-order problem for Ghostty
itself.

- The config was ported field-by-field from iTerm2's `Default` profile
  (`~/Library/Preferences/com.googlecode.iterm2.plist`), diffed against iTerm2's own shipped
  defaults to separate "actually customized" from "just what iTerm2 ships." Comments in the
  config file cite the iTerm2 setting each line replaces.
- The 16-color ANSI palette is no longer hand-spelled-out: `theme = Vibrant Ink` (one of the
  ~300 named themes Ghostty ships — see `ghostty +list-themes`, and read a theme's own file at
  `Ghostty.app/Contents/Resources/ghostty/themes/<name>` on macOS) supplies it, replacing the
  original iTerm2-`Default`-profile ANSI ramp, which read as too flat/limited (pure `0xCC`/`0xFF`
  primaries). Any `background`/`foreground`/`palette`/`cursor-*`/`selection-*` set explicitly in
  the main config overrides that same field from the theme (confirmed via
  `ghostty +show-config --default --docs`, the `theme` option's doc comment) — so a theme and
  hand-picked overrides coexist freely; there's no need to re-spell out fields that already match
  the theme. This file currently overrides only `foreground`, `cursor-color`, and `cursor-text`
  (they differ from Vibrant Ink's own values); `background`, `selection-background`, and
  `selection-foreground` were dropped because they were already byte-for-byte identical to
  Vibrant Ink's own values. To check what a theme actually contains before choosing one, read its
  file directly, or diff `ghostty +show-config --changes-only` before/after setting `theme =` in
  the tracked config — `+show-config` reads the live symlinked config, so edits are visible
  immediately with no reload needed.
- Option names and defaults were verified against the *installed* `ghostty +show-config
  --default` (1.3.1 stable), not against `ghostty-org/ghostty`'s `main` branch, which is
  well ahead of any release and documents options/values that don't exist yet — e.g. `main`'s
  `copy-on-select` takes `false/true/clipboard/primary/both`, but 1.3.1 only has
  `false/true/clipboard`. Re-run `ghostty +show-config --default` after any Ghostty upgrade
  before trusting an unfamiliar option name against the docs site or `main`.
- There is no `bold-is-bright` option — bright-bold is `bold-color = bright`.
- `background-blur` and the `keybind = super+u=toggle_background_opacity` line are effectively
  macOS-only (blur needs a cooperating Linux compositor to do anything; the toggle action is
  documented macOS-only) — a knowing exception to the "same on both platforms" preference
  elsewhere in this repo, made because the underlying iTerm2 behavior (`Blur`, Cmd-U to toggle
  transparency) was itself macOS-only.
- `config-file = ?config-local` is the last line, mirroring `.zshenv-local`/`.zshrc-local`:
  an optional (`?`) include for machine-specific overrides, resolved relative to the tracked
  config file (i.e. inside the repo, since `~/.config/ghostty` is a symlink into it).
  `.config/ghostty/config-local` is gitignored, same pattern as the zsh `-local` files.
- `selection-word-chars` is deliberately left at Ghostty's default rather than porting iTerm2's
  empty `WordCharacters` (which made double-click select only alphanumeric runs) — the config
  has a comment recording the iTerm2 value in case that behavior is ever wanted back.
- Not portable, and deliberately dropped rather than silently lost: iTerm2's `Semantic History`
  (click-a-path-to-open-in-Sublime — Ghostty only has `link-url` for clickable URLs, no
  open-in-editor equivalent), Smart Selection Rules (no Ghostty feature), the iTerm2 `tmux`
  profile (Ghostty has no profiles; its only real difference from `Default` — font and `TERM` —
  is covered by the tmux terminfo fix below), per-pane titles, and
  `TripleClickSelectsFullWrappedLines: False` (Ghostty always selects the full wrapped line).
- `bin/ghostty-terminfo` (not installed anywhere, run from the repo root) makes `xterm-ghostty`
  resolvable to processes Ghostty didn't launch directly — tmux started from a login shell,
  `ssh -t` back into a box. `local` compiles it into `~/.terminfo`; `push HOST...` does the
  `infocmp -x xterm-ghostty | ssh HOST tic -x -` dance per host. Both need a *description* to
  feed `tic`, and `xterm-ghostty` usually isn't in the system terminfo db — only Ghostty's own
  bundled copy has it (`/Applications/Ghostty.app/Contents/Resources/terminfo` on macOS) — so the
  script tries the system db first, then that bundle path via `TERMINFO=`, and fails loudly
  naming both attempts rather than half-succeeding. `install-ghostty-terminfo` wraps the `local`
  case only, since it's the one subcommand that needs no argument.
  - `push` falls back to copying Ghostty's *precompiled* `xterm-ghostty` entry when the remote
    has no `tic` at all — hit on `titanium`, an OpenWrt 25.12 box running this repo's zsh setup,
    where a missing terminfo entry showed up as doubly-echoed characters at the zsh prompt
    (`TERM=xterm-ghostty zsh -fc 'zmodload zsh/terminfo; print ${terminfo[colors]}'` came back
    empty). Root cause is the same one the `tput` shim in the `zsh-config` skill already documents: OpenWrt's ncurses
    is built `--without-progs`, so `tic`/`infocmp`/`tput` don't exist and no package adds them.
    The compiled terminfo format is endian-independent, so the bundled file
    (`.../Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty`) is portable to copy as-is —
    no `tic` needed on either end for that path. It's written to both possible destination
    layouts (`~/.terminfo/x/xterm-ghostty` and `~/.terminfo/78/xterm-ghostty`, plus the `ghostty`
    alias at `g/`/`67/`), since a remote's ncurses picks letter- or hex-named terminfo dirs at its
    own build time and nothing on the wire says which; titanium turned out to use letters
    (`MIXEDCASE_FILENAMES`). Verified afterward with the same `zsh/terminfo` trick, since the
    remote has no `infocmp` to ask directly. `local` has no equivalent fallback — a tic-less
    machine is told to run `push` from the machine that has Ghostty instead, since there's
    nothing to compile *from* on that end.
- `.tmux.conf` sets `default-terminal "tmux-256color"` plus `terminal-features
  ",xterm-ghostty:RGB:clipboard:hyperlinks:usstyle:sync"` (needs tmux ≥ 3.2) for truecolor,
  OSC 52 clipboard, OSC 8 hyperlinks, underline styling, and synchronized-update passthrough,
  declared explicitly rather than relying on tmux's live terminal auto-detection (tmux has no
  built-in profile for "ghostty" the way it does for xterm/screen/iTerm). Each capability is
  confirmed present in the installed `xterm-ghostty` terminfo entry (`infocmp -x
  xterm-ghostty`: `Tc`, `Ms`, `Setulc`, `Smulx`, `Sync`) rather than guessed — same caveat as
  the option verification above: re-run `infocmp -x xterm-ghostty` after a Ghostty upgrade
  before trusting this list, since a changed terminfo entry would leave it silently stale. It
  also sets `set-clipboard on` (tmux's `external` default ignores OSC 52 from programs inside a
  pane - the only clipboard path that works over SSH with no `xclip`/`xsel`/`wl-copy`
  installed; tradeoff: any program in a pane can now write the real clipboard via OSC 52, e.g.
  `cat` on an untrusted file) and `focus-events on` (Ghostty reports focus; this is what lets it
  reach apps like Emacs).

