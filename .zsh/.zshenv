# Skip /etc/zsh/{zprofile,zshrc,zlogin} - originally added because Apple's
# /etc/zprofile broke our PATH ordering, but it also fixes a Linux-only bug:
# Debian/Ubuntu's /etc/zsh/zshrc unconditionally calls `compinit` itself,
# which runs before Zim's `completion` module (Zim's own .zshrc, and thus
# ZDOTDIR, isn't read until after the global rcs) and makes it print
# "completion was already initialized before completion module". Since we
# manage completion (and everything else these global rcs might set)
# ourselves via Zim, skip them everywhere rather than just on macOS.
setopt no_global_rcs

export ZDOTDIR=~/.zsh

export HOMEBREW_PREFIX="/opt/homebrew"

# Set before Zim's `environment` module loads (it only sets HISTFILE if unset,
# but reassigning it later in .zshrc would not re-read history from this file).
export HISTFILE=$ZDOTDIR/.zsh_history

if [ -e $ZDOTDIR/.zshenv-local ]; then
	. $ZDOTDIR/.zshenv-local
fi

export MAIL="$HOME/Maildir"
export RSYNC_RSH=ssh
export SCREENDIR=~/.screen
export TMUX_TMPDIR=~/.screen

# I always trust my bin, /usr/local/bin, and /usr/local/sbin over all
# other bins. /usr/local/{bin,sbin} are guarded, not assumed - they're
# common on Linux but don't exist on Apple-silicon macOS.
MYPATH=~/bin
if [ -e /usr/local/bin ]; then
  MYPATH=$MYPATH:/usr/local/bin
fi
if [ -e /usr/local/sbin ]; then
  MYPATH=$MYPATH:/usr/local/sbin
fi
if [ -e $HOMEBREW_PREFIX/bin ]; then
  MYPATH=$MYPATH:$HOMEBREW_PREFIX/bin
fi
if [ -e $HOMEBREW_PREFIX/sbin ]; then
  MYPATH=$MYPATH:$HOMEBREW_PREFIX/sbin
fi
# gnubin MYPATH entries commented out in favor of the ohmyzsh gnu-utils Zim
# module (.zimrc); see AGENTS.md for the trade-off. Uncomment to revert.
# if [ -e $HOMEBREW_PREFIX/libexec/gnubin ]; then
#   MYPATH=$MYPATH:$HOMEBREW_PREFIX/libexec/gnubin
# fi
if [ -e $HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin ]; then
  MANPATH="$HOMEBREW_PREFIX/opt/coreutils/libexec/gnuman:$MANPATH"
fi
if [ -e $HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnubin ]; then
  MANPATH="$HOMEBREW_PREFIX/opt/gnu-tar/libexec/gnuman:$MANPATH"
fi
if [ -e $HOMEBREW_PREFIX/opt/findutils/libexec/gnubin ]; then
  MANPATH="$HOMEBREW_PREFIX/opt/findutils/libexec/gnuman:$MANPATH"
fi
if [ -e $HOMEBREW_PREFIX/opt/make/libexec/gnubin ]; then
  MANPATH="$HOMEBREW_PREFIX/opt/make/libexec/gnuman:$MANPATH"
fi
# MANPATH is inherited by nested shells, which re-run this file and would
# otherwise prepend the gnuman dirs again.
typeset -U manpath
if [ -e /usr/lib/ccache ]; then
  MYPATH=/usr/lib/ccache:$MYPATH
fi

# Only prepend when part of the prefix is missing, i.e. in the first shell of a
# tree. A nested shell inherits a PATH this block already built, and
# re-prepending would push entries its parent put in front (venv, nvm, ...)
# behind the system dirs.
prefix=(${(s.:.)MYPATH} /bin /usr/bin /sbin /usr/sbin)
missing=(${prefix:|path})
if (( ${#missing} )); then
  path=($prefix $path)
fi
unset prefix missing
typeset -U path
export PATH

# Stays here (not a Zim module) so cron and other non-interactive shells get
# it too; see AGENTS.md. The ohmyzsh chruby Zim module only adds completion.
for search_path in /usr/local $HOMEBREW_PREFIX
do
  # chruby for ruby
  if [ -e $search_path/share/chruby/chruby.sh ]; then
	  . $search_path/share/chruby/chruby.sh
	  . $search_path/share/chruby/auto.sh
	  if [ -e ~/.ruby-version ]; then
      chruby `cat ~/.ruby-version`
	  fi
    break
  fi
done
