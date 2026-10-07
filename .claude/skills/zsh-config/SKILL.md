---
name: zsh-config
description: zsh/Zim shell architecture for this repo — .zshenv vs .zshrc placement, Zim module order, the oh-my-zsh plugin gating, fzf-tab/zsh-autosuggestions Tab dispatch, the tput shim, and oh-my-posh prompt setup. Load before editing anything under .zsh/.
---

# zsh architecture

- `ZDOTDIR=~/.zsh`. `install-zsh` links `.zsh/.zshenv` into `~/.zsh` and then links that into
  `$HOME`, so zsh finds it before `ZDOTDIR` is set.
- `.zsh/.zshenv` — env only: `PATH` assembly (`MYPATH` first: `~/bin`, `/usr/local/*`, then
  Homebrew), chruby bootstrap. The `MYPATH` + `/bin:/usr/bin:/sbin:/usr/sbin` prefix is only
  prepended when some of it is missing from the inherited `PATH` (the first shell of a tree);
  re-prepending in a nested shell used to push entries the parent had put in front (venv, nvm,
  shims) behind the system dirs. Limitation: a parent that has every prefix dir present but in
  a different order isn't reordered. Don't write the check as `${#${prefix:|path}}` — unquoted
  and nested it counts the joined string's characters, not the missing elements, so it is always
  true; assign to an array first. The tool-specific `gnubin` `MYPATH` lines (macOS
  coreutils/gnu-tar/findutils/make) were deleted outright (`0206daa`) as a trial in favor of the
  ohmyzsh `gnu-utils` Zim module (`.zimrc`, darwin-only) — their `MANPATH` lines stay active since
  `gnu-utils` has no man-page equivalent. `typeset -U manpath` follows them so a nested shell
  re-running `.zshenv` with an inherited `MANPATH` doesn't stack duplicate entries (the trailing
  empty entry, meaning "also search man's defaults", survives). Only one generic gnubin `MYPATH` line remains, commented
  out (`$HOMEBREW_PREFIX/libexec/gnubin`). This trades coverage: `gnu-utils` works via `hash`,
  which only reaches interactive shells, so a script or cron job invoking `ls`/`sed`/`tar`
  still gets the BSD version even though an interactive shell doesn't. Reverting now means
  uncommenting that one remaining line and re-adding the four deleted per-tool lines. The chruby
  bootstrap deliberately stays here rather than moving to a Zim
  module, for the opposite reason: cron jobs need it, and `.zshenv` (unlike `.zshrc`/Zim) is
  sourced by every zsh, interactive or not. Sets `no_global_rcs`
  unconditionally (all platforms), skipping `/etc/zsh/{zprofile,zshrc,zlogin}` — originally
  added for macOS because Apple's `/etc/zprofile` reorders `PATH`, but it also prevents a
  Linux-only bug where Debian/Ubuntu's `/etc/zsh/zshrc` calls `compinit` itself before Zim's
  `completion` module gets a chance to, which made Zim print "completion was already
  initialized before completion module" on every shell startup. Also sets `HISTFILE` — it has
  to live here, not `.zshrc`, because Zim's `environment` module sets `HISTFILE` too (only if
  unset) as part of `source $ZIM_HOME/init.zsh`, and reassigning `HISTFILE` after that point
  doesn't re-read history from the new file.
- `.zsh/.zshrc` — interactive only: Zim bootstrap/module init, `zstyle` completion rules,
  aliases, oh-my-posh init (in the non-dumb branch of the `$TERM` case, guarded on
  `oh-my-posh` being installed), pager/less config (lesspipe search, `LESS`, `MANPAGER`,
  `LESS_TERMCAP_*`) — lives here rather than `.zshenv` since `man`/`less` only consult any of
  these when their output is actually going to a terminal, the same judgment call already made
  for `PAGER` (set by Zim's `environment`/`utility` modules, interactive shells only). Sets
  `ZSH_CACHE_DIR`
  and adds `$ZSH_CACHE_DIR/completions` to `fpath` before Zim init — an oh-my-zsh convention
  Zim itself doesn't set, needed because the ohmyzsh `docker` plugin (`.zimrc`) writes its
  generated completion there; left unset, the plugin's background completion-generation job
  resolves the path to `/completions/_docker` and fails with a permission error on every
  startup on a machine with `docker` installed.
- **Zim** (`.zsh/.zimrc`) is the plugin/module manager, replacing the old vendored
  `zsh-syntax-highlighting` submodule. `ZIM_HOME=$ZDOTDIR/.zim` is *not* tracked in this repo —
  `.zshrc` self-installs it (downloads `zimfw.zsh`, then runs `zimfw init`) on first shell
  startup if missing, so **a fresh machine needs network access on first login** to get
  completions, syntax highlighting, and autosuggestions. This is the first place shell startup
  reaches the network; every other optional tool (`vivid`, `lsd`, `bat`) degrades silently
  without it.
  - Modules loaded: `environment`, `input`, `utility`, `run-help`, `termtitle`, `git`,
    `archive`, `MichaelAquilina/zsh-you-should-use` (nags on typing out a command longhand
    that matches an existing alias), `ssh` (Linux only, via `--if-ostype 'linux*'` — macOS
    already has agent-backed keys via `AddKeysToAgent yes` in `.ssh/config`), five oh-my-zsh
    plugins pulled via `zmodule ohmyzsh/ohmyzsh --root plugins/<name>` (see below), plus
    `zsh-completions`, `completion`, `Aloxaf/fzf-tab` (fuzzy tab-completion menu; per its own
    README it must load after `completion`'s `compinit` but before any widget-wrapping plugin,
    hence its position here — see `.zimrc`), `zsh-syntax-highlighting`,
    `zsh-history-substring-search`, `zsh-autosuggestions`. The last three must stay in that
    relative order — Zim's own doc calls this out.
  - **oh-my-zsh plugins**: `gnu-utils`, `docker-compose`, `docker`, `chruby`, `sudo`, each as
    `zmodule ohmyzsh/ohmyzsh --root plugins/<name>` — the zimfw README's documented way to pull
    a single plugin out of another framework's repo. `--use degit` (set once, on the first
    `zmodule ohmyzsh/ohmyzsh` call — per-module options carry over to every later call for the
    same module) pulls a tarball snapshot instead of a full clone, since the ohmyzsh repo is
    ~14 MB. Placement matters:
    - `gnu-utils` and `docker-compose` load early (no compinit dependency); `gnu-utils` is
      gated `--if-ostype 'darwin*'` (see the `.zshenv` gnubin note above) and `docker-compose`
      and `docker` are gated `--if-command docker` (neither is installed on this machine).
    - `docker` and `chruby` load *after* `completion` — `docker`'s plugin registers
      `_comps[docker]=_docker`, and the `chruby` plugin's `compdef _chruby chruby` needs
      `compdef` to exist, both of which only exist post-compinit. `chruby` is gated
      `--if '(( ${+functions[chruby]} ))'`, not `--if-command` — chruby is a shell function
      sourced by `.zshenv`, never a binary on `PATH`.
    - `sudo` (an Esc-Esc `zle` widget toggling a `sudo` prefix) must load before the
      `zsh-syntax-highlighting`/`zsh-autosuggestions` block or autosuggestions won't wrap it.
    - `docker`'s plugin hardcodes `$ZSH_CACHE_DIR/completions` as its generated-completion path
      — an oh-my-zsh variable Zim doesn't set on its own, so `.zshrc` sets it (see above).
      Deliberately no `--fpath completions` on the `docker` `zmodule` call: OMZ itself only
      ever puts the generated `$ZSH_CACHE_DIR/completions` copy on `fpath`, never the plugin's
      bundled `completions/_docker`, and adding it would let Zim's prepended module `fpath`
      shadow the freshly generated completion with the stale vendored one.
    - General zimfw gotcha hit while adding these: passing `--fpath` to a `zmodule` call
      disables its default `--source <name>.plugin.zsh` auto-detection (the `zimfw.zsh` guard
      is `(( ! ${#zfpaths} && ! ${#zfunctions} && ! ${#zcmds} ))`) — so a module needing both a
      custom `fpath` entry and its default init script needs an explicit `--source` too.
  - `environment` sets `EXTENDED_GLOB`, `NO_CLOBBER`, `AUTO_PUSHD`, `AUTO_CD`,
    `INTERACTIVE_COMMENTS` and more. `NO_CLOBBER` (`>` refusing to overwrite files) did turn out
    to be annoying, so `.zshrc` sets `setopt CLOBBER` after Zim init, alongside `CORRECT` and
    `NO_AUTO_MENU`, to override it back off.
  - `.zshrc` rebinds `fzf-tab`'s `tab` key to `accept` (its own default is `tab:down`, Enter-only
    to accept) and binds fzf's `one` event to `accept` too, so a query that narrows the candidate
    list to a single row — including a menu that would only ever have one row — inserts it with no
    keypress. The `fzf-bindings` zstyle's binds are appended after fzf-tab's defaults inside a
    single `--bind`, and fzf takes the last binding given for a key, so this is a pure override.
    `.zshrc` also sets `zstyle ':completion:*' menu no`, overriding Zim's `completion` module
    (`menu select`) per fzf-tab's README, so zsh never starts its own menu and fzf-tab can capture
    the unambiguous prefix — Zim's more specific menu styles (directory-stack, history-words)
    still win in their own contexts.
  - `.zshrc` also binds plain Tab (`^I`) to a small dispatcher widget,
    `ktg-tab-partial-accept-or-complete`, rather than to `fzf-tab-complete` directly, because
    `zsh-autosuggestions` needs the same key: with a suggestion showing and the cursor at the end
    of the buffer *and* `ktg-word-has-file-match` finds no file or directory starting with the
    word being typed (empty word or leading `~` handled; no `(e)` expansion), Tab accepts the
    suggestion one component at a time via stock `forward-word`; any other time it falls through
    to `zle fzf-tab-complete`, so files win over history. Only files count:
    command/option/subcommand completion still loses to the suggestion.
    This works because `.zshrc` runs `select-word-style bash` (right after `bindkey -e`): word
    characters are alphanumerics only, and `skip-whitespace-first` makes `forward-word` stop at
    the *end* of the next word, so `ssh example.com` accepted after `ssh` lands on `ssh example`,
    not `ssh example.`. The cost is that `--color=auto` takes several Tabs. `WORDCHARS` itself is
    never set — zsh's default is left alone (the style bypasses it). This replaced a custom
    `ktg-forward-word-end` widget, which kept `-`/`_`/`=` as word characters so a flag accepted in
    one Tab; restore it from git history (see the commit that introduced bash word style) if that
    matters more. The style also applies to Alt-f, Ctrl-Right and Ctrl-W, which now move per path
    component. `forward-word` accepts a suggestion because it is in zsh-autosuggestions' default
    `ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS`. The dispatcher itself must be in
    `ZSH_AUTOSUGGEST_IGNORE_WIDGETS` — appended *after* Zim init, the one deliberate exception to
    the "set Zim-consumed zstyles before `source $ZIM_HOME/init.zsh`" rule below, since the
    plugin's default list is only set when unset and assigning earlier would drop its entries:
    `zsh-autosuggestions` re-wraps every zle widget on each precmd, and an unignored widget it
    doesn't recognize gets its generic `modify` wrapper, which blanks `POSTDISPLAY` before calling
    through — the dispatcher would never see a suggestion to accept. Ignoring the dispatcher leaves
    `POSTDISPLAY` intact for it while the `forward-word` / `fzf-tab-complete` widgets it calls still
    hit their own wrappers normally.
    Shift-Tab (`key_info[BackTab]`, from Zim's `input` module) is bound straight to
    `fzf-tab-complete` as an escape hatch that always opens the menu — stealing that key back
    from `input`'s `reverse-menu-complete`, which `menu no` had already made a no-op since zsh
    never starts a menu to reverse through.
  - `zstyle`s that Zim modules read (`:zim:ssh`, `:zim:termtitle`, …) and
    `ZSH_HIGHLIGHT_HIGHLIGHTERS` must be set **before** `source $ZIM_HOME/init.zsh` — setting
    them after has no effect, since the modules already consumed the old value.
  - `.zshrc` defines a `tput` shell function, guarded on `(( ! $+commands[tput] ))`, before the
    Zim bootstrap — needed on OpenWrt, which has no `tput` and no package that provides one
    (upstream `package/libs/ncurses` builds with `--without-progs`, so `libncurses`/
    `libncursesw`/`libncurses-dev` ship zero programs; only the `terminfo` database package
    exists). The shim backs onto zsh's own `zsh/terminfo` module — `echoti` is a direct analogue
    of `tput`, same capability names, same `/usr/share/terminfo` — falling back to raw ANSI SGR
    codes if that module or the terminfo database is unavailable. It has to sit before Zim init
    specifically because the `zsh-you-should-use` module (see modules list above) probes
    `type tput` at load time and caches empty colour variables if that probe fails; it's outside
    the `$TERM` case further down since it's unrelated to dumb-terminal handling. This is also why
    it lives in the committed `.zshrc` rather than the uncommitted `.zshrc-local`, even though only
    one host needs it — `.zshrc-local` is sourced last, long after Zim (and YSU) have already
    initialized.
  - `zsh-syntax-highlighting` and `zsh-autosuggestions` don't self-guard on `TERM=dumb` the way
    Zim's own modules do, so the whole Zim bootstrap is skipped under a dumb terminal (TRAMP),
    falling back to a bare `compinit -i`, matching the old pre-Zim behavior.
  - `termtitle` replaced the hand-rolled `title()`/`precmd`/`preexec` functions.
  - fzf shell integration is Zim's stock `zmodule fzf` (zimfw/fzf), placed right after
    `Aloxaf/fzf-tab` (fzf's `completion.zsh` captures whatever `^I` is bound to when it loads) and
    before the widget-wrapping block. It needs **fzf ≥ 0.48** (`fzf --zsh`). Missing fzf is silent
    (`init.zsh` bails with `return 1`, no key bindings). An older fzf is *not* silent: `fzf --zsh`
    prints "unknown flag" on every startup and there are no key bindings — Ubuntu 22.04 ships
    0.29.0 and 24.04 0.44.1, so install a newer fzf manually there (the Makefile's apt `fzf` is too
    old on those). The module caches `fzf --zsh` output in its own dir (zcompiled, regenerated when
    the fzf binary is newer). This replaced a hand-rolled block that fell back to Debian's
    `/usr/share/doc/fzf/examples/*.zsh` and filtered stderr for the `can't change option: zle`
    line; that warning (a bug in fzf's shipped scripts: restoring the snapshotted `$options`
    re-sets `zle`, which zsh refuses) only appears outside a real PTY, e.g. `zsh -ic exit`, so no
    workaround is kept. The module also sets `FZF_DEFAULT_COMMAND`/`FZF_CTRL_T_COMMAND` from the
    first of bfs/fd/rg/ug installed (rg's variant includes hidden and git-ignored files) and adds
    bat previews (Ctrl-T) and eza/lsd/ls previews (Alt-C), Ctrl-/ toggles. fzf's `**<Tab>`
    completion trigger is dead: `.zshrc` rebinds `^I` to the Tab dispatcher after init.
- **oh-my-posh** (`.zsh/kgarner.omp.json`) replaced Powerlevel10k as the prompt engine.
  Powerlevel10k is effectively unmaintained; there is no p10k-style instant prompt anywhere
  outside p10k, so that feature is gone with no replacement.
  - **This is the first hard dependency shell startup has ever had** — every other optional
    tool (`vivid`, `lsd`, `bat`, `dircolors`) degrades silently when missing, and p10k itself
    was a vendored submodule (always present offline). oh-my-posh is neither: no binary, no
    prompt. `.zshrc` guards the init on `(( $+commands[oh-my-posh] ))` and falls back to the
    plain `PS1`/`RPS1` that used to be the pre-p10k default, so a machine without it is still
    usable, just plain.
  - A `precmd` hook (`_posh_jobs_precmd`, registered before oh-my-posh's own hooks) exports
    `POSH_JOBS` for the theme's `text` segment — oh-my-posh has no built-in equivalent to
    p10k's `background_jobs` segment.
  - The theme's colors are p10k's original 256-color indices, ported as plain numeric strings
    (e.g. `"254"`) — oh-my-posh accepts raw 256-color indices directly, confirmed against
    `src/color/colors.go` upstream (`strconv.ParseUint` → `color.C256`), not just hex/named
    colors.
  - Segments use `"style": "powerline"` with `powerline_symbol: ""` on the left prompt,
    and `""` plus `invert_powerline: true` on the rprompt, to reproduce p10k's rainbow-style
    solid arrows between sections — modeled on oh-my-posh's own shipped
    `powerlevel10k_rainbow.omp.json` theme. This makes a Nerd Font a hard requirement for the
    prompt to render correctly (already true since `8cc0bf4` added Nerd Font icons to segments).
    Those `powerline_symbol` values are literal Nerd Font glyphs (e.g. U+E0B0/U+E0B2), not
    empty strings, even though some terminals/editors render them as blank — a string-match
    edit against a literal `""` in a quoted old/new pair will silently fail to find the
    line; match against the surrounding keys instead, or edit by line number.
  - The `path` segment's `template` anchors the path at the git repo root (matching p10k's old
    `truncate_to_repo` behavior) via a cross-segment reference to the `git` segment's
    `.RepoName`/`.RelativeDir`, falling back to the plain `.Path` outside a repo. oh-my-posh has
    no built-in repo-anchored path style (upstream issue
    JanDeDobbeleer/oh-my-posh#5174 is still open). The forward reference to `git`, which sits
    *after* `path` in the block, works because oh-my-posh resolves `.Segments.<Name>` templates
    by dependency (`Needs`), not by segment order — `git` still renders in its usual position,
    only `path`'s own text is computed after it.
  - The same `template` also hard-caps the rendered path at 60 characters (`…` plus the last 59,
    via Sprig `trunc -59`; it is rune-safe, so non-ASCII names count per character). This is
    separate from `properties.max_width: 60` (set to match, so both limits agree), which only
    drops whole folders and so can't shorten a single huge component (e.g. a pnpm store dir like `.pnpm/@datadog+browser-rum-react@…_…`
    ~150 chars) — that case wrapped the prompt over two lines. The template builds the string
    into `$p` first (assigning with `=` inside the `if` branches) and then truncates it.
    `claude/statusline.omp.json` carries the identical `path` template; edit both together.
  - The `session` segment (`user@host`) shows only when `.SSHSession` or `.Root` is true, and
    within that, `@{{ hostname }}` itself is further gated on `.SSHSession` alone — so root over
    SSH shows `root@host` but root locally shows just `root`, since the local hostname is always
    "here" and adds nothing. `foreground_templates` turns the whole segment bright red (`196`,
    the same red the last block's error `❯` already uses) when `.Root` is true, falling back to
    the normal yellow (`3`) otherwise — the same conditional-list-with-literal-fallback idiom the
    `git` segment's `background_templates` uses.
  - The `git` segment's `properties.branch_template` truncates branch names longer than 35
    characters to a fixed 35-char prefix plus an ellipsis (`{{ if gt (len .Branch) 35 }}{{ trunc
    35 .Branch }}…{{ else }}{{ .Branch }}{{ end }}`), added after a ticket-ID-prefixed feature
    branch (`feature/eng-2171-b3-…`) overflowed the terminal width at work. `branch_template` is a
    real property on the installed oh-my-posh (confirmed against the v31.3.0 source and re-checked
    on 31.4.1, not just the docs site, which — same trap as the `ghostty-config` skill documents — can document options ahead of
    what's actually installed); it receives only `{{ .Branch }}`/`{{ .Upstream }}`, and oh-my-posh
    templates include the full Sprig function set (`trunc`, `len`, etc.), so no new dependency was
    needed. When iterating on template changes, `oh-my-posh print primary --config ... --force`
    can still show stale output — oh-my-posh caches rendered segment values on disk, so
    `oh-my-posh cache clear` is needed between test runs, independent of `--force` (which only
    forces hidden/disabled segments to render, not a cache bypass).
- Machine-specific overrides go in `~/.zsh/.zshenv-local` and `~/.zsh/.zshrc-local`, sourced last
  and **not** part of this repo. Host-specific settings belong there, not in committed files.
- There is no vendored completion directory any more — `.zsh/.zshfunc/` (8 hand-vendored files, all
  predating Zim) was retired once every one of them turned out to be shadowing a newer, better
  system or vendor completion. Completions now come from zsh's own functions dir plus whatever
  `.zshrc` adds to `fpath`: `$HOMEBREW_PREFIX/share/zsh/site-functions`,
  `/usr/local/share/zsh/site-functions` and `/usr/share/zsh/vendor-completions`, each guarded on
  `[[ -d ... ]]` since none is reliably present on every platform this repo targets — Debian/
  Ubuntu's vendor dir would normally come from `/etc/zsh/zshenv`, which `.zshenv`'s `no_global_rcs`
  skips. They're appended, not prepended, specifically so zsh's own `_git` (in the system functions
  dir, earlier in `fpath`) keeps winning over git's own shipped completion wrapper — see the zsh
  architecture notes below for why that ordering was chosen. `fpath` must be in its final form
  *before* Zim's `completion` module runs — it globs `fpath` once at init time, so anything
  appended later is invisible to completion.
- Guard new tool config with `(( $+commands[foo] ))` — the existing style, since these files run
  on both macOS and Linux.

