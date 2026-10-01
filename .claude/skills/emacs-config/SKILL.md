---
name: emacs-config
description: Emacs bootstrap/config architecture for this repo — .emacs vs .elisp/, Custom-vs-setq clobbering, load-path shadowing, the lexical-binding cookie requirement, and the emacs-plus-app flavor. Load before editing .emacs or anything under .elisp/.
---

# Emacs architecture

- `.emacs` is bootstrap only: prepends `/opt/homebrew/bin` to `PATH`/`exec-path` (works around
  native-comp linker errors on GUI launch), calls `package-initialize`, adds `~/.elisp` to
  `load-path`, optionally loads `~/.site-lisp/load-site.el`, sets frame/server config, and holds
  the `custom-set-variables` block including `package-selected-packages`.
- Real configuration is deferred to `after-init-hook` → `(load "common-config")`, so ELPA packages
  exist first. Anything depending on a package belongs in `.elisp/`, not `.emacs`.
- **A variable set via Custom in `.emacs` and also `setq`'d in a `customize-*.el` file will end up
  with the `customize-*.el` value**, since that loads later via `after-init-hook` — Custom's write
  silently has no effect. Hit this with `whitespace-style`: `.emacs` set it via Custom, but
  `customize-whitespace.el` unconditionally `setq`'d it too, clobbering the Custom value every
  startup. Fixed by merging both into the one `setq` in `customize-whitespace.el` and dropping the
  Custom entry — the general rule going forward: a variable a `customize-*.el` file already
  manages belongs there, not in `.emacs`'s Custom block.
- `.elisp/common-config.el` is the hub: it loads the per-language `customize-*.el` files
  (`customize-ruby`, `customize-js`, `customize-cc`, `customize-git`, `customize-whitespace`, …).
  A new language config is a new `customize-<lang>.el` plus a `(load ...)` line there.
- Per-mode convention, from `customize-ruby.el`: define a `ktg-<mode>-mode-hook` function, then
  `add-hook` it.
- Packages come from ELPA/MELPA (`package-selected-packages` in `.emacs`) — no vendored `.el`
  files remain under `.elisp/` any more. There used to be a handful (`yaml-mode.el`,
  `cmake-mode.el`, `blank-mode.el`, `follow-mouse.el`); all were removed once confirmed unused or
  superseded by a built-in/ELPA equivalent. **The hazard that killed the first of them:** `.emacs`
  prepends `~/.elisp` to `load-path`, so *any* file dropped there — even one with the same name as
  an ELPA package — silently wins over the installed package with no error. That's exactly what
  happened to `yaml-mode.el`: a vendored 2006 v0.0.3 copy shadowed the ELPA `yaml-mode` package
  for years. Before adding a new file under `.elisp/`, check it doesn't collide with anything in
  `package-selected-packages`.
- `.emacs` and every file `common-config.el` loads (or that `.emacs` loads directly, like
  `customize-macemacs.el`) start with a `lexical-binding: t` file-local cookie — Emacs 30+ warns at
  startup on any loaded source file missing one, since nothing here is byte-compiled (`*.elc` is
  gitignored). A new `customize-<lang>.el` needs the cookie too.
- `install-emacs` restores ELPA packages itself: after symlinking `.emacs`, it runs
  `emacs --batch -l ~/.emacs --eval "(progn (package-refresh-contents)
  (package-install-selected-packages t))"`, so a fresh machine gets everything
  `package-selected-packages` in `.emacs` lists installed automatically as part of `make` /
  `make install-mac` / `make install-linux` — no manual `M-x` steps needed. This is guarded on
  `command -v emacs`: on a Linux box without emacs installed (`install-linux-packages` doesn't
  include it — there's no cross-distro package name/PPA this repo picks for it), the batch step
  is skipped with a message instead of failing `make install-linux`, while `.emacs`/`.elisp`
  still get symlinked so the config is ready the moment emacs is installed later. macOS is
  unaffected — `install-homebrew-packages` guarantees emacs is on `PATH` before `all` runs.
- `customize-css.el`'s `scss-mode` hook targets the `scss-mode` built into Emacs's own
  `css-mode.el`, not the (now largely redundant) MELPA package of the same name — don't add
  `scss-mode` to `package-selected-packages`.
- `git-commit-mode` comes from the `magit` package (Magit 4.0 folded the standalone `git-commit`
  package into it); `customize-git.el` gets it with `(require 'git-commit)`, which enables
  `global-git-commit-mode` by default.

### Emacs flavor

- The Emacs on macOS is the **emacs-plus-app** Homebrew cask, `/Applications/Emacs.app`, callable
  from the CLI at `/Applications/Emacs.app/Contents/MacOS/bin/emacs`. `/opt/homebrew/bin/emacs`
  and `/opt/homebrew/bin/emacsclient` are Homebrew symlinks into that bundle, so plain
  `emacs` / `emacsclient` work on PATH. (The config previously supported Aquamacs; that support —
  and all Aquamacs references repo-wide — was removed once the emacs-plus-app migration finished.)
- **Guiding constraint: the Emacs config must behave the same on Linux and macOS.** Prefer
  portable elisp in `.elisp/common-config.el`; use a platform conditional only when something
  genuinely can't be portable.
- Platform-conditional load in `.emacs`: `customize-macemacs`, when `window-system` is `ns` — the
  live macOS path under emacs-plus-app (unbinds `s-q`/`s-w`, disables `recentf-mode`, wires up
  `dash-at-point` on `C-c d` / `C-c e` for Dash.app lookups).

**Known leftovers (open items — don't silently fix; update this list when resolved):**

- The ohmyzsh `gnu-utils` Zim module and the `.zshenv` gnubin `MYPATH` entries are a similar
  trial (see the `zsh-config` skill): `gnu-utils` is active; only one commented `MYPATH` line
  remains in `.zshenv` (the generic `$HOMEBREW_PREFIX/libexec/gnubin` catch-all) — the four
  tool-specific `MYPATH` lines (coreutils/gnu-tar/findutils/make) were deleted outright in
  `0206daa`, leaving only their `MANPATH` counterparts active. If `gnu-utils`'s interactive-only
  coverage (see the `zsh-config` skill) turns out to be a problem, reverting means uncommenting that
  one remaining line *and* re-adding the four deleted per-tool lines, then dropping the
  `gnu-utils` `zmodule` line.
- `.rar` extraction/creation is deliberately unsupported on both platforms: `unrar` is
  proprietary and not in homebrew-core (macOS) or the default repos (multiverse-only on
  Ubuntu). Zim's `archive` module looks for `unrar`/`rar` by name, so it does not
  handle `.rar` out of the box here.

