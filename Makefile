SRC=${PWD}
ZDOTDIR=${HOME}/.zsh
ZCVSDIR=$(SRC)/.zsh

BIN_DIR=${HOME}/bin
KEYBINDINGS_DIR=${HOME}/Library/KeyBindings
KEYBINDINGS_FILE=$(KEYBINDINGS_DIR)/DefaultKeyBinding.dict
CLAUDE_DIR=${HOME}/.claude

# Target repo/branch for `make publish-public` - see that target below.
PUBLIC_REMOTE ?= git@github.com:ktgeek/dotfiles.git
PUBLIC_BRANCH ?= main

all: install-zsh install-emacs install-vim install-git install-sqlite install-tmux install-irbrc install-rspec

install-mac: install-homebrew install-homebrew-packages all install-keybindings install-lsd install-defaults install-mac-sudo-touchid

install-linux: all install-toprc install-linux-packages install-oh-my-posh

install-zsh:
	mkdir -p $(ZDOTDIR)
	# One-time migration cleanup (added 2026-09); safe to remove once all
	# machines have re-run make.
	rm -f $(ZDOTDIR)/zsh-syntax-highlighting $(ZDOTDIR)/.p10k.zsh $(ZDOTDIR)/powerlevel10k \
	      $(ZDOTDIR)/.iterm2_shell_integration.zsh
	rm -rf $(ZDOTDIR)/.zshfunc
	ln -sf $(ZCVSDIR)/.zshenv $(ZDOTDIR)
	ln -sf $(ZDOTDIR)/.zshenv ${HOME}
	ln -sf $(ZCVSDIR)/.zshrc $(ZDOTDIR)
	ln -sf $(ZCVSDIR)/.zimrc $(ZDOTDIR)
	ln -sf $(ZCVSDIR)/kgarner.omp.json $(ZDOTDIR)

install-elisp:
	ln -sf $(SRC)/.elisp ${HOME}

install-emacs: install-elisp
	ln -sf $(SRC)/.emacs ${HOME}
	@if command -v emacs >/dev/null 2>&1; then \
		emacs --batch -l ${HOME}/.emacs --eval "(progn (package-refresh-contents) (package-install-selected-packages t))"; \
	else \
		echo "install-emacs: emacs not found on PATH, skipping package install (symlinks only)"; \
	fi
#	test -e $(SRC)/.emacs.elc && ln -sf $(SRC)/.emacs.elc ${HOME}

install-vim:
	ln -sf $(SRC)/.vimrc ${HOME}

install-toprc:
	ln -sf $(SRC)/.toprc ${HOME}

install-git:
	ln -sf $(SRC)/.gitconfig ${HOME}
	ln -sf $(SRC)/.gitconfig-* ${HOME}
	ln -sf $(SRC)/.gitignore_global ${HOME}

install-sqlite:
	ln -sf $(SRC)/.sqliterc ${HOME}

install-tmux:
	ln -sf $(SRC)/.tmux.conf ${HOME}

install-ssh:
	mkdir -p ~/.ssh
	ln -sf $(SRC)/.ssh/config ${HOME}/.ssh
	ln -sf $(SRC)/.ssh/config-personal ${HOME}/.ssh

# Ports this machine's Claude Code working-style memory, permission gating
# (permissions.ask, the write-scope PreToolUse hook, autoMode.soft_deny), the
# oh-my-posh statusline theme, and user-level skills into ~/.claude. Not part of
# `all`/`install-mac`/`install-linux` - see AGENTS.md for
# why (fails outright if CLAUDE.md already exists and isn't this repo's own
# symlink, so it must never run unattended as part of a routine `make`).
# settings.json itself is merged in place (via bin/claude-merge-settings), not
# symlinked - Claude Code rewrites that file (e.g. /config, "always allow"), and
# a machine may carry its own additional autoMode.soft_deny rules; the merge
# script prompts interactively about those, keeping them by default.
install-claude:
	mkdir -p $(CLAUDE_DIR)/hooks $(CLAUDE_DIR)/skills
	@target="$(SRC)/claude/user-CLAUDE.md"; \
	if [ -L $(CLAUDE_DIR)/CLAUDE.md ]; then \
		current="$$(readlink $(CLAUDE_DIR)/CLAUDE.md)"; \
		case "$$current" in \
			"$$target") \
				echo "install-claude: CLAUDE.md already linked to this repo" ;; \
			$(SRC)/claude/*) \
				ln -sfn "$$target" $(CLAUDE_DIR)/CLAUDE.md; \
				echo "install-claude: re-pointed CLAUDE.md to this repo's current payload path" ;; \
			*) \
				echo "install-claude: $(CLAUDE_DIR)/CLAUDE.md already exists - move it aside first" >&2; \
				exit 1 ;; \
		esac; \
	elif [ -e $(CLAUDE_DIR)/CLAUDE.md ]; then \
		echo "install-claude: $(CLAUDE_DIR)/CLAUDE.md already exists - move it aside first" >&2; \
		exit 1; \
	else \
		ln -s "$$target" $(CLAUDE_DIR)/CLAUDE.md; \
	fi
	@# A hook renamed or removed from claude/hooks/ leaves its old symlink
	@# dangling here forever otherwise - the ln -sf glob below only adds or
	@# overwrites, it never removes. Sweep anything dangling first so a
	@# relink always reflects the repo's current hook set.
	@for link in $(CLAUDE_DIR)/hooks/*; do \
		[ -L "$$link" ] || continue; \
		[ -e "$$link" ] && continue; \
		echo "install-claude: removing stale hook symlink $$link"; \
		rm -f "$$link"; \
	done
	ln -sf $(SRC)/claude/hooks/*.sh $(CLAUDE_DIR)/hooks
	@# Same dangling-symlink problem as the hooks sweep above, for skills.
	@for link in $(CLAUDE_DIR)/skills/*; do \
		[ -L "$$link" ] || continue; \
		[ -e "$$link" ] && continue; \
		echo "install-claude: removing stale skill symlink $$link"; \
		rm -f "$$link"; \
	done
	@# Symlink each skill directory (not its SKILL.md) so a skill can grow
	@# supporting files later. Looped, not a bare glob, so an empty
	@# claude/skills/ doesn't pass ln a literal unmatched glob string.
	@for skill in $(SRC)/claude/skills/*/; do \
		[ -d "$$skill" ] || continue; \
		ln -sfn "$${skill%/}" $(CLAUDE_DIR)/skills/; \
	done
	ln -sf $(SRC)/claude/statusline.omp.json $(CLAUDE_DIR)
	ln -sf $(SRC)/claude/statusline.sh $(CLAUDE_DIR)
	$(SRC)/bin/claude-merge-settings $(SRC)/claude/settings-gating.json $(CLAUDE_DIR)/settings.json

# This installs emacs like keybindings in OS X
$(KEYBINDINGS_DIR):
	mkdir -p $(KEYBINDINGS_DIR)

$(KEYBINDINGS_FILE): $(KEYBINDINGS_DIR)
	cp $(SRC)/Library/KeyBindings/DefaultKeyBinding.dict $(KEYBINDINGS_FILE)

install-keybindings: $(KEYBINDINGS_FILE)

procmail: ${HOME}/.procmailrc

${HOME}/.procmailrc: procmailrc.m4 procmail-base.m4
	m4 < procmailrc.m4 > ${HOME}/.procmailrc~ && \
	mv ${HOME}/.procmailrc~ ${HOME}/.procmailrc

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

install-etags: $(BIN_DIR)
	ln -sf $(SRC)/bin/etags $(BIN_DIR)
	ln -sf $(SRC)/bin/vstags $(BIN_DIR)

install-defaults:
	sudo defaults write /Library/Preferences/com.apple.NetworkAuthorization UseDefaultName -bool NO
	sudo defaults write /Library/Preferences/com.apple.NetworkAuthorization UseShortName -bool YES
	defaults -currentHost write -globalDomain NSStatusItemSpacing -int 2
	defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 2

install-irbrc:
	ln -sf $(SRC)/.irbrc ${HOME}

install-rspec:
	ln -sf $(SRC)/.rspec ${HOME}

install-lsd:
	ln -sf $(SRC)/.config/lsd ${HOME}/.config

install-ghostty:
	mkdir -p ${HOME}/.config
	ln -sf $(SRC)/.config/ghostty ${HOME}/.config

# One-time: makes xterm-ghostty resolvable to processes Ghostty didn't launch
# (e.g. tmux started from a login shell) by compiling it into ~/.terminfo. Only
# usable on a machine with Ghostty or ncurses' tic/infocmp - e.g. not this
# target's own OpenWrt machines, whose ncurses ships without programs at all.
# See bin/ghostty-terminfo for the remote-host equivalent (no argument-free
# target for that one, since it needs a hostname); on such a tic-less remote,
# push from the machine running Ghostty instead of running this target there.
install-ghostty-terminfo:
	$(SRC)/bin/ghostty-terminfo local

install-mac-code: $(BIN_DIR)
	ln -sf /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code $(BIN_DIR)/code

install-mac-sudo-touchid:
	sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local

# oh-my-posh has no apt package; this is the official install script. On
# macOS, install-homebrew's `oh-my-posh` formula is used instead - this
# target is only wired into install-linux.
install-oh-my-posh: $(BIN_DIR)
	curl -s https://ohmyposh.dev/install.sh | bash -s -- -d $(BIN_DIR)

# Guarded so a re-run of install-mac on an already-configured machine
# doesn't abort: both the installer and xcode-select fail outright when
# what they install is already present.
install-homebrew:
	command -v brew >/dev/null 2>&1 || /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	xcode-select -p >/dev/null 2>&1 || xcode-select --install

install-homebrew-packages:
	brew tap d12frosted/emacs-plus
	brew install \
		font-fira-code \
		font-fira-code-nerd-font \
		font-meslo-lg-nerd-font \
		git \
		git-delta \
		chruby \
		ruby-install \
		sqlite \
		openssh \
		mosh \
		mtr \
		mqttui \
		bat \
		ripgrep \
		ctags \
		lsd \
		syntax-highlight \
		betterzip \
		vivid \
		pigz \
		pbzip2 \
		rsync \
		gnu-tar \
		coreutils \
		container \
		oh-my-posh \
		fzf \
		tmux \
		p7zip \
		jq
	brew install --cask emacs-plus-app

# Ubuntu/Debian analog of install-homebrew's package list. oh-my-posh has no
# apt package (see install-oh-my-posh); .rar support is deliberately absent
# here (unrar is multiverse-only, not installed by default - see AGENTS.md).
# fzf: the zsh integration (zim's fzf module) needs >= 0.48; the apt package is older
# on Ubuntu 22.04/24.04, so install a newer fzf manually there.
install-linux-packages:
	sudo apt update
	sudo apt install -y \
		zsh \
		curl \
		git \
		git-delta \
		fzf \
		bat \
		ripgrep \
		ctags \
		fonts-firacode \
		p7zip-full \
		pbzip2 \
		pigz \
		xz-utils \
		zstd \
		unzip \
		mosh \
		rsync \
		tmux \
		jq

# Builds a fresh, history-free snapshot of HEAD via `git archive` (which
# respects .gitattributes export-ignore, so files like .ssh/config-personal
# and procmailrc.m4 never leave this repo) and force-pushes it as a single
# commit to PUBLIC_REMOTE/PUBLIC_BRANCH. git only ever transfers objects
# reachable from the ref it pushes, so no prior history - this repo's or a
# previous public snapshot's - is ever sent. Needs consent before running,
# same as any push to a shared remote - see AGENTS.md.
publish-public:
	@tmp="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp"' EXIT; \
	git archive HEAD -o "$$tmp/archive.tar" && \
	tar -xf "$$tmp/archive.tar" -C "$$tmp" && \
	rm "$$tmp/archive.tar" && \
	cd "$$tmp" && \
	git init -q && \
	git add -A && \
	git commit -q -m "snapshot: dotfiles as of $$(date +%Y-%m-%d)" && \
	git push -f $(PUBLIC_REMOTE) HEAD:$(PUBLIC_BRANCH)
