# Options: 
# make cli             bash, ctags, nvim, vim, tmux
# make desktop         foot, g0wm
# make home            everything under home/
# make system          everything under root/ (needs sudo)

# make unstow-home     remove the $HOME symlinks
# make check           dry run, touches nothing

STOW        := stow
SUDO        ?= $(if $(filter 0,$(shell id -u)),,$(firstword \
                 $(foreach c,doas sudo,$(if $(shell command -v $(c) 2>/dev/null),$(c)))))
HOME_TARGET := $(HOME)
DESTDIR     ?=
BACKUP      ?= 1
MAKEFILE    := $(firstword $(MAKEFILE_LIST))

CLI_PKGS     := bash ctags nvim vim tmux
DESKTOP_PKGS := foot g0wm
HOME_PKGS    := $(CLI_PKGS) $(DESKTOP_PKGS)
ROOT_PKGS    := nftables sysctl ssh chrony networkmanager dnscrypt dracut

ifeq ($(strip $(DESTDIR)),)
INSTALL_SUDO  := $(SUDO)
INSTALL_OWNER := -o root -g root
else
INSTALL_SUDO  :=
INSTALL_OWNER :=
endif

ifeq ($(strip $(BACKUP)),1)
INSTALL_BACKUP := --backup=simple --suffix=~
else
INSTALL_BACKUP :=
endif

.DEFAULT_GOAL := help
.PHONY: help cli desktop home system check unstow-home stow \
        require-stow require-pkgs require-root not-root $(HOME_PKGS)

help:
	@awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' $(MAKEFILE)

# preflight

require-stow:
	@command -v $(STOW) >/dev/null 2>&1 || { \
		echo "error: '$(STOW)' not found. Install GNU stow:" >&2; \
		echo "  debian/ubuntu: apt install stow   void: xbps-install -S stow" >&2; \
		echo "  arch: pacman -S stow              gentoo: emerge app-admin/stow" >&2; \
		exit 1; }

require-pkgs:
	@for pkg in $(ROOT_PKGS); do \
		[ -d "root/$$pkg" ] || { echo "error: no such package: root/$$pkg" >&2; exit 1; }; \
	done
	@for pkg in $(HOME_PKGS); do \
		[ -d "home/$$pkg" ] || { echo "error: no such package: home/$$pkg" >&2; exit 1; }; \
	done

# root helper
require-root:
	@[ -n "$(DESTDIR)" ] || [ "$$(id -u)" = 0 ] || [ -n "$(SUDO)" ] || { \
		echo "error: need root for /etc, and no doas/sudo found." >&2; \
		echo "       run as root, or stage first: make system DESTDIR=/tmp/x" >&2; \
		exit 1; }

not-root:
	@[ -z "$$SUDO_USER" ] || { \
		echo "error: run this as yourself, not under sudo" >&2; \
		echo "       (target would be $(HOME_TARGET))" >&2; exit 1; }

# $HOME

cli:     ; @$(MAKE) --no-print-directory stow PKGS="$(CLI_PKGS)"
desktop: ; @$(MAKE) --no-print-directory stow PKGS="$(DESKTOP_PKGS)"
home:    ; @$(MAKE) --no-print-directory stow PKGS="$(HOME_PKGS)"

$(HOME_PKGS):
	@$(MAKE) --no-print-directory stow PKGS="$@"

stow: require-stow require-pkgs not-root
	@[ -n "$(PKGS)" ] || { echo "error: no packages given" >&2; exit 1; }
	@$(STOW) --dir=home --target=$(HOME_TARGET) --restow --no-folding $(PKGS)
	@echo "stowed into $(HOME_TARGET): $(PKGS)"

unstow-home: require-stow not-root
	@$(STOW) --dir=home --target=$(HOME_TARGET) --delete $(HOME_PKGS)
	@echo "unstowed: $(HOME_PKGS)"

# /etc
system: require-pkgs require-root
	@for pkg in $(ROOT_PKGS); do \
		find "root/$$pkg" -type f | while IFS= read -r src; do \
			dst="$(DESTDIR)/$${src#root/$$pkg/}"; \
			mode=0644; case "$$dst" in \
				*/etc/nftables/*|*/etc/sysctl.d/*) mode=0600 ;; \
			esac; \
			$(INSTALL_SUDO) install -D $(INSTALL_OWNER) $(INSTALL_BACKUP) \
				-m $$mode "$$src" "$$dst" || exit 1; \
			echo "  $$dst  ($$mode)"; \
		done || exit 1; \
	done
	@echo "note: reload what needs it - sysctl --system, nft -f, dracut -f"

# dry run
check: require-stow require-pkgs
	@$(STOW) --dir=home --target=$(HOME_TARGET) --restow --no-folding \
		--simulate --verbose=2 $(HOME_PKGS) 2>&1 | sed 's/^/  /'
	@echo "--- root/ vs live /etc ---"
	@for pkg in $(ROOT_PKGS); do \
		find "root/$$pkg" -type f | while IFS= read -r src; do \
			dst="$(DESTDIR)/$${src#root/$$pkg/}"; \
			if [ ! -e "$$dst" ]; then echo "  missing     $$dst"; \
			elif [ ! -r "$$dst" ]; then echo "  unreadable  $$dst (rerun as root)"; \
			elif ! cmp -s "$$src" "$$dst"; then echo "  differs     $$dst"; fi; \
		done || exit 1; \
	done
