PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib

BASHCOMP_PATH ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMP_PATH ?= $(PREFIX)/share/zsh/site-functions

ifeq ($(FORCE_ALL),1)
FORCE_BASHCOMP := 1
FORCE_ZSHCOMP := 1
FORCE_FISHCOMP := 1
endif
ifneq ($(strip $(wildcard $(BASHCOMP_PATH))),)
FORCE_BASHCOMP := 1
endif
ifneq ($(strip $(wildcard $(ZSHCOMP_PATH))),)
FORCE_ZSHCOMP := 1
endif

all:
	@echo "Try \"make install\" instead."

install-common:
	@[ "$(FORCE_BASHCOMP)" = "1" ] && install -v -d "$(BASHCOMP_PATH)" && install -m 0644 -v completion/servers.bash-completion "$(BASHCOMP_PATH)/servers" || true
	@[ "$(FORCE_ZSHCOMP)" = "1" ] && install -v -d "$(ZSHCOMP_PATH)" && install -m 0644 -v completion/servers.zsh-completion "$(ZSHCOMP_PATH)/_servers" || true

install: install-common
	@install -v -d "$(BINDIR)/"
	cat src/server-store.sh > "$(BINDIR)/servers"
	@chmod 0755 "$(BINDIR)/servers"

uninstall:
	@rm -vrf \
		"$(BINDIR)/servers" \
		"$(BASHCOMP_PATH)/servers" \
		"$(ZSHCOMP_PATH)/_servers"


.PHONY: install uninstall
