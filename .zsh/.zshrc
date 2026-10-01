# The ohmyzsh docker plugin (.zimrc) needs $ZSH_CACHE_DIR set; see AGENTS.md.
ZSH_CACHE_DIR=$ZDOTDIR/.cache
[[ -d $ZSH_CACHE_DIR/completions ]] || mkdir -p $ZSH_CACHE_DIR/completions

# Init some zsh complete stuff
fpath=($ZSH_CACHE_DIR/completions $fpath)

# Vendor completion dirs that aren't on the default fpath here. Homebrew's is
# never added automatically (and the old hardcoded /usr/local path is Intel-only,
# so it's been dead since this box went arm64); Debian/Ubuntu's normally comes
# from /etc/zsh/zshenv, which .zshenv's no_global_rcs skips. Appended, not
# prepended, so zsh's own _git wins over git's contrib bash wrapper on every
# platform. HOMEBREW_PREFIX comes from .zshenv.
for _ktg_fpath_dir in \
  $HOMEBREW_PREFIX/share/zsh/site-functions \
  /usr/local/share/zsh/site-functions \
  /usr/share/zsh/vendor-completions
do
  [[ -d $_ktg_fpath_dir ]] && fpath+=($_ktg_fpath_dir)
done
unset _ktg_fpath_dir

typeset -U fpath

# zsh-you-should-use probes `type tput` at load time and falls back to
# uncoloured messages without it. OpenWrt has no tput and no package that
# provides one - upstream builds ncurses --without-progs - so stand in with
# zsh's own terminfo module: echoti is tput's analogue, same capability
# names, same /usr/share/terminfo the `terminfo` package installs. `type`
# finds functions, so this satisfies the probe. Plain SGR fallback covers a
# box with neither the module nor the database. Must run before Zim init
# below - YSU captures its colour variables at module-load time.
if (( ! $+commands[tput] )); then
  if zmodload -i zsh/terminfo 2>/dev/null && (( ${+terminfo[sgr0]} )); then
    function tput { echoti "$@" }
  else
    function tput {
      case $1 in
        (sgr0) print -n $'\e[0m' ;;
        (bold) print -n $'\e[1m' ;;
        (smul) print -n $'\e[4m' ;;
        (setaf) (( $2 < 8 )) && print -n $'\e[3'$2'm' || print -n $'\e[38;5;'$2'm' ;;
        (setab) (( $2 < 8 )) && print -n $'\e[4'$2'm' || print -n $'\e[48;5;'$2'm' ;;
        (*) return 1 ;;
      esac
    }
  fi
fi

# Zim plugin/module manager. zsh-syntax-highlighting and zsh-autosuggestions
# don't self-guard on TERM=dumb the way Zim's own modules (environment, input,
# completion, termtitle, ...) do, so skip the whole framework under a dumb
# terminal (TRAMP) and fall back to a bare compinit, matching the pre-Zim setup.
if [[ $TERM != dumb ]]; then
  ZIM_HOME=$ZDOTDIR/.zim

  # Download the zimfw plugin manager if missing.
  if [[ ! -e $ZIM_HOME/zimfw.zsh ]]; then
    curl -fsSL --create-dirs -o $ZIM_HOME/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
  # Install missing modules, and update init.zsh if missing or outdated.
  if [[ ! $ZIM_HOME/init.zsh -nt $ZDOTDIR/.zimrc ]]; then
    source $ZIM_HOME/zimfw.zsh init
  fi

  # These zstyles are consumed by modules below; they must be set before
  # `source $ZIM_HOME/init.zsh` or the modules never see them.
  zstyle ':zim:ssh' ids 'id_ed25519'
  zstyle ':zim:termtitle' hooks 'preexec' 'precmd'
  zstyle ':zim:termtitle:precmd'  format '<%n@%m>${ENVIRONMENT} %35<..<%~%<<'
  zstyle ':zim:termtitle:preexec' format '<%n@%m>${ENVIRONMENT} %35<..<%~%<< ${${(Az)1}[1]:t}'
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern regexp cursor line)

  source $ZIM_HOME/init.zsh
else
  autoload -U compinit
  compinit -i
fi

# Use emacs key bindings
bindkey -e

# less/man pager config - lives here rather than .zshenv because `man`
# and `less` only ever consult MANPAGER/LESSOPEN/LESS/LESS_TERMCAP_* when
# their output is actually going to a terminal; piped or redirected (the
# genuinely non-interactive case: cron, scripts), `man` bypasses paging
# entirely and `less` degrades to a plain dump, so none of this does
# anything there. Same judgment call Zim's `environment`/`utility`
# modules already make for PAGER (defaulted to `less` for interactive
# shells only) - this block just applies it consistently to the rest of
# the pager settings.
for lp in /bin/lesspipe /usr/bin/lesspipe.sh /usr/local/bin/lesspipe.sh $HOMEBREW_PREFIX/bin/lesspipe
do
  if [ -e $lp ]; then
    export LESSOPEN="|$lp %s" LESS_ADVANCED_PREPROCESSOR=1
    break
  fi
done
export LESS="--ignore-case --jump-target=4 --LONG-PROMPT --no-init --quit-if-one-screen --RAW-CONTROL-CHARS -x4"
export MANPAGER='less -Rsi'

# LESS_TERMCAP colors for less/man (mb/md/us match Zim's `utility`
# module's bold-weighted values; so/se have no Zim equivalent - it
# doesn't set them at all - and are kept as before).
export LESS_TERMCAP_mb=$'[1;31m'
export LESS_TERMCAP_md=$'[1;31m'
export LESS_TERMCAP_me=$'[0m'
export LESS_TERMCAP_se=$'[0m'
export LESS_TERMCAP_so=$'[00;32m'
export LESS_TERMCAP_ue=$'[0m'
export LESS_TERMCAP_us=$'[1;32m'

# color-ls initialization
if (($+commands[vivid])); then
  export LS_COLORS=$(vivid generate molokai)
elif (($+commands[dircolors])) ; then
  if [ -e /etc/DIR_COLORS ]; then
      COLORS=/etc/DIR_COLORS
      eval `dircolors --sh /etc/DIR_COLORS`
  elif [ -f "$HOME/.dircolors" ]; then
      eval `dircolors --sh $HOME/.dircolors`
      COLORS=$HOME/.dircolors
  else
      eval `dircolors --sh`
  fi
fi

if (( ${+LS_COLORS} )); then
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
fi

setopt promptsubst
case "$TERM" in
    "dumb")
	PS1="> "
        # The zsh bracketed paste mode totally breaks TRAMP.  We'll
        # unset it when we're in a dumb term.  The only thing that I
        # *know* uses dumb term is TRAMP.
	unset zle_bracketed_paste
	;;
    *)
        # Fallback prompt for a machine without oh-my-posh installed (or when
        # $PATH doesn't include it) - oh-my-posh is a hard dependency with no
        # vendored fallback, unlike everything else in this file.
        PS1="%n@%m [%!]%(!.#.:)"
        RPS1="%20<..<%~%<<"
        if (( $+commands[oh-my-posh] )); then
          # Exposes the background-job count to kgarner.omp.json's `text`
          # segment (oh-my-posh has no built-in equivalent to p10k's
          # background_jobs segment). Registered before oh-my-posh's own
          # precmd hook so the count is current when the prompt renders.
          function _posh_jobs_precmd { POSH_JOBS=${#jobstates} }
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _posh_jobs_precmd
          eval "$(oh-my-posh init zsh --config $ZDOTDIR/kgarner.omp.json)"
          # oh-my-posh's own precmd hook unsets PROMPT_SUBST every cycle (so
          # literal `$`/backtick characters in rendered segment text, e.g.
          # directory names, aren't re-interpreted as shell syntax). Zim's
          # termtitle module relies on PROMPT_SUBST staying on so its
          # `${...}` zstyle format strings above actually expand instead of
          # showing up literally in the title bar. Registered after
          # oh-my-posh's hook so it always runs last in the precmd sequence,
          # leaving PROMPT_SUBST back on for termtitle's next precmd/preexec.
          function _termtitle_restore_prompt_subst { setopt PROMPT_SUBST }
          add-zsh-hook precmd _termtitle_restore_prompt_subst
        fi
	;;
esac

setopt CORRECT
setopt NO_AUTO_MENU
setopt CLOBBER

# Disable zsh's new-mail check
export MAILCHECK=0

# If the system has vim, use that over vi
if (( $+commands[vim] )); then
    alias vi="vim"
fi

# If your system has the emacs-plus-app Emacs.app, we use its emacsclient
# to open files in the running server, starting it if needed. Otherwise
# fall back to whatever emacsclient is on PATH.
ECSOCKET=$TMPDIR/emacs$UID/server
if [ -e /Applications/Emacs.app ]; then
    function ge
    {
        if [ -e $ECSOCKET ]; then
	  /Applications/Emacs.app/Contents/MacOS/bin/emacsclient -n $* >/dev/null 2>&1
        else
	    open -a /Applications/Emacs.app
            until [ -e $ECSOCKET ]; do
                sleep .5
            done
	    /Applications/Emacs.app/Contents/MacOS/bin/emacsclient -n $* >/dev/null 2>&1
	fi
    }
    alias gec="emacsclient -nw"
elif [ -e /usr/bin/emacs -o -e /usr/local/bin/emacs ]; then
    alias ge="emacsclient -n"
    alias gec="emacsclient -nw"
fi

# History size/dedup tuning. HISTFILE is set in .zshenv (has to be, so it's
# in place before Zim's `environment` module runs); SHARE_HISTORY,
# HIST_IGNORE_SPACE, HIST_VERIFY, and HIST_FIND_NO_DUPS also come from
# `environment` now. This must run *after* Zim init, or `environment`'s own
# HISTSIZE=20000/SAVEHIST=10000 defaults overwrite these.
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Ignore CVS in all cases
zstyle ':completion:*' ignored-patterns '(*/)#CVS'

zstyle ':completion:*' completer _complete _correct _prefix
zstyle ':completion:predict:*' completer _complete

# No matcher-list or group-name override here: Zim's `completion` module
# already sets both (matcher-list is case-insensitive plus substring/
# partial-word matching, strictly more capable than a plain case-fold).

# Zim's `completion` module sets `menu select`, but fzf-tab replaces zsh's
# own completion menu entirely and its README asks for `menu no` so zsh
# never starts a menu of its own, letting fzf-tab capture the unambiguous
# prefix instead. Zim's more specific menu styles (directory-stack,
# history-words) still win in their own contexts, so e.g. `cd -<TAB>` is
# unaffected.
zstyle ':completion:*' menu no

# Zim's `completion` module sets these description/correction/message/
# warning formats with %F{}/%f prompt-expansion color codes, but fzf-tab
# renders them itself and doesn't interpret those escapes - its own README
# says so ("don't use escape sequences ... fzf-tab will ignore them"), so
# without this override they show up as literal `%F{yellow}` text in the
# fzf-tab completion menu. Override with the same text, minus the escapes.
zstyle ':completion:*:corrections' format '-- %d (errors: %e) --'
zstyle ':completion:*:descriptions' format '-- %d --'
zstyle ':completion:*:messages' format '-- %d --'
zstyle ':completion:*:warnings' format '-- no matches found --'

# fzf-tab's default group-colors palette (fzf-tab.zsh) opens with ANSI
# "bright blue" (\e[94m) for the first group it encounters (usually
# "external command"), which on a dark background can render as a fairly
# dark, low-contrast blue depending on the terminal theme's ANSI palette.
# Override just that first slot with an explicit 256-color light blue,
# which (like the oh-my-posh theme colors) bypasses the terminal's ANSI
# palette for a predictable result; the rest of the list is fzf-tab's
# unchanged default.
zstyle ':fzf-tab:*' group-colors \
    $'\e[38;5;39m' $'\e[32m' $'\e[33m' $'\e[35m' $'\e[31m' $'\e[38;5;27m' $'\e[36m' \
    $'\e[38;5;100m' $'\e[38;5;98m' $'\e[91m' $'\e[38;5;80m' $'\e[92m' \
    $'\e[38;5;214m' $'\e[38;5;165m' $'\e[38;5;124m' $'\e[38;5;120m'

# fzf-tab's default binds are `tab:down,btab:up,...` (its lib/-ftb-fzf), so
# Enter is the only way to take a match out of the menu. Rebind tab to accept
# the highlighted entry instead - fzf-tab appends this zstyle's binds after
# its defaults inside a single --bind, and fzf takes the last binding given
# for a key, so tab still opens the menu, and tab again inserts the
# highlighted row. Navigation inside the menu is then arrows/^N/^P or typing
# to filter; ctrl-space still toggles multi-select. `one:accept` fires
# whenever the candidate list narrows to exactly one row - including at
# open, so a menu that would only ever have one row never appears - which
# lets filtering down to a single match insert it with no keypress at all.
zstyle ':fzf-tab:*' fzf-bindings 'tab:accept' 'one:accept'

# Tab does double duty. With an autosuggestion showing, the cursor at the end
# of the line, and no file or directory matching the word being typed, it accepts
# that suggestion one component at a time via ktg-forward-word-end below - a
# narrower version of what Alt-f and Ctrl-Right already do with
# zsh-autosuggestions' stock `forward-word` partial-accept. Any other time Tab
# falls through to fzf-tab's completion menu, so files win over history.
#
# ktg-forward-word-end exists because plain forward-word is wrong for this job
# in two ways: with zsh's default WORDCHARS (`*?_-.[]~=/&;!#$%^(){}<>`), `/` and
# `.` count as word characters, so one forward-word swallows a whole path or
# hostname instead of one component; and forward-word stops at the *start* of
# the next word, which rides the separator along with it - accepting from
# history `ssh example.com` after typing just `ssh` would land on
# "ssh example." rather than "ssh example". This widget instead derives its own
# word-char set from $WORDCHARS with `/` and `.` dropped (so `-`, `_`, `=` etc.
# still glue a flag like --color=auto into one chunk), then moves the cursor
# past any leading separators and stops at the *end* of the following word -
# never a wordchars-list member.
ktg-forward-word-end() {
  local wordchars=${${WORDCHARS//\//}//./} c
  while (( CURSOR < $#BUFFER )); do
    c=${BUFFER[CURSOR+1]}
    [[ $c == [[:alnum:]] || $wordchars == *"$c"* ]] && break
    (( CURSOR++ ))
  done
  while (( CURSOR < $#BUFFER )); do
    c=${BUFFER[CURSOR+1]}
    [[ $c == [[:alnum:]] || $wordchars == *"$c"* ]] || break
    (( CURSOR++ ))
  done
}
zle -N ktg-forward-word-end

# Registering it as a partial-accept widget (rather than calling it directly)
# is what makes it an *accept* instead of a bare cursor move: zsh-autosuggestions'
# _zsh_autosuggest_partial_accept temporarily appends POSTDISPLAY to BUFFER, runs
# the wrapped widget, then re-splits both at wherever the cursor landed - keeping
# the remaining suggestion dim-highlighted. Appended, and only after Zim init,
# same as ZSH_AUTOSUGGEST_IGNORE_WIDGETS below: the plugin's own default list is
# guarded on this variable being unset, so setting it earlier would drop
# forward-word & co. and break Alt-f / Ctrl-Right, which deliberately keep the
# default WORDCHARS and so still take a whole path or hostname in one motion.
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(ktg-forward-word-end)

# The dispatcher has to be in ZSH_AUTOSUGGEST_IGNORE_WIDGETS or it can't see what
# it's dispatching on: zsh-autosuggestions re-wraps every widget on each precmd,
# and a widget it doesn't recognise gets the `modify` wrapper, which blanks
# POSTDISPLAY before calling the original. Ignored, the dispatcher keeps its view
# of POSTDISPLAY, and the widgets it calls still hit their own wrappers. Appended
# rather than assigned, and only after Zim init: the module's own default ignore
# list is guarded on this variable being unset, so setting it earlier would drop
# those defaults.
if (( ${+widgets[fzf-tab-complete]} )); then
  # True when the word being typed is a prefix of at least one file or directory.
  # An empty word (cursor after a space) is not a match, or every non-empty
  # directory would shadow the suggestion. Only a leading ~ is expanded - `(e)`
  # would run command substitutions on every Tab. The unquoted ${word} isn't
  # glob-expanded (no GLOB_SUBST), so only the trailing `*` is a pattern.
  function ktg-word-has-file-match {
    [[ $LBUFFER == *[[:space:]] ]] && return 1
    local word=${(Q)${(z)LBUFFER}[-1]}
    [[ -n $word ]] || return 1
    word=${word/#\~/$HOME}
    local -a matches=( ${word}*(N[1]) )
    (( $#matches ))
  }

  function ktg-tab-partial-accept-or-complete {
    if [[ -n $POSTDISPLAY ]] && (( CURSOR == $#BUFFER )) && ! ktg-word-has-file-match; then
      zle ktg-forward-word-end
    else
      zle fzf-tab-complete
    fi
  }
  zle -N ktg-tab-partial-accept-or-complete
  ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(ktg-tab-partial-accept-or-complete)
  bindkey '^I' ktg-tab-partial-accept-or-complete

  # Escape hatch: force the completion menu even with a suggestion showing.
  # Zim's `input` module binds Shift-Tab to reverse-menu-complete, which is dead
  # weight here - `menu no` above means zsh never starts a menu to reverse
  # through - so this is a free key. key_info comes from that same module.
  if [[ -n ${key_info[BackTab]} ]]; then
    bindkey ${key_info[BackTab]} fzf-tab-complete
  fi
fi

zstyle ':completion:*' file-patterns \
       '%p:globbed-files: *(-/):directories:Directories' '*:all-files:Others'

# Fun helpers for ruby and other dev
# Have ruby's RI use ansi color formatting
export RI="-f ansi"
alias be='bundle exec'
alias bcsp='bundle config set --local path "vendor/bundle"'

for i in bat batcat
do
  if (( $+commands[$i] )); then
    alias cat=$i
    export BAT_THEME=Coldark-Dark
    break
  fi
done

if [ -e $ZDOTDIR/.zshrc-local ]; then
    . $ZDOTDIR/.zshrc-local
fi
