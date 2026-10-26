PREFIX ?= /opt/ravn-git-bare-clone
BINDIR ?= /usr/bin
DESTDIR ?=

.PHONY: all install test lint check clean help

all: check

help:
	@echo "ravn-git-bare-clone targets:"
	@echo "  install  Install files to $(DESTDIR)$(PREFIX) and symlink to $(DESTDIR)$(BINDIR)"
	@echo "  test     Run the test suite"
	@echo "  lint     Run shellcheck on all bash scripts"
	@echo "  check    Run lint and test"

install:
	install -d "$(DESTDIR)$(PREFIX)/runtime/helper"
	install -d "$(DESTDIR)$(PREFIX)/runtime/lib"
	install -d "$(DESTDIR)$(PREFIX)/runtime/scripts"
	install -d "$(DESTDIR)$(PREFIX)/runtime/completion"
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 ravn-git-bare-clone "$(DESTDIR)$(PREFIX)/ravn-git-bare-clone"
	install -m 644 runtime/commands.tsv "$(DESTDIR)$(PREFIX)/runtime/commands.tsv"
	install -m 755 runtime/helper/set_variable.sh "$(DESTDIR)$(PREFIX)/runtime/helper/set_variable.sh"
	install -m 644 runtime/lib/global_fn.sh "$(DESTDIR)$(PREFIX)/runtime/lib/global_fn.sh"
	install -m 644 runtime/lib/command_catalog.sh "$(DESTDIR)$(PREFIX)/runtime/lib/command_catalog.sh"
	install -m 644 runtime/lib/command_interface.sh "$(DESTDIR)$(PREFIX)/runtime/lib/command_interface.sh"
	install -m 644 runtime/lib/dispatch.sh "$(DESTDIR)$(PREFIX)/runtime/lib/dispatch.sh"
	install -m 644 runtime/lib/lifecycle.sh "$(DESTDIR)$(PREFIX)/runtime/lib/lifecycle.sh"
	install -m 644 runtime/lib/presentation.sh "$(DESTDIR)$(PREFIX)/runtime/lib/presentation.sh"
	install -m 755 runtime/scripts/clone "$(DESTDIR)$(PREFIX)/runtime/scripts/clone"
	install -m 755 runtime/scripts/sync "$(DESTDIR)$(PREFIX)/runtime/scripts/sync"
	install -m 755 runtime/scripts/create "$(DESTDIR)$(PREFIX)/runtime/scripts/create"
	install -m 755 runtime/scripts/issue "$(DESTDIR)$(PREFIX)/runtime/scripts/issue"
	install -m 755 runtime/scripts/help "$(DESTDIR)$(PREFIX)/runtime/scripts/help"
	install -m 644 runtime/completion/git-bare-clone.bash "$(DESTDIR)$(PREFIX)/runtime/completion/git-bare-clone.bash"
	install -m 644 runtime/completion/_git-bare-clone "$(DESTDIR)$(PREFIX)/runtime/completion/_git-bare-clone"
	install -m 755 bin/git-bare-clone "$(DESTDIR)$(PREFIX)/bin/git-bare-clone"
	install -m 755 bin/git-create-worktree "$(DESTDIR)$(PREFIX)/bin/git-create-worktree"
	install -m 755 bin/git-issue-worktree "$(DESTDIR)$(PREFIX)/bin/git-issue-worktree"
	ln -sf "$(PREFIX)/ravn-git-bare-clone" "$(DESTDIR)$(BINDIR)/ravn-git-bare-clone"
	ln -sf "$(PREFIX)/bin/git-bare-clone" "$(DESTDIR)$(BINDIR)/git-bare-clone"
	ln -sf "$(PREFIX)/bin/git-create-worktree" "$(DESTDIR)$(BINDIR)/git-create-worktree"
	ln -sf "$(PREFIX)/bin/git-issue-worktree" "$(DESTDIR)$(BINDIR)/git-issue-worktree"

lint:
	shellcheck ravn-git-bare-clone \
		bin/* \
		runtime/completion/*.bash \
		runtime/helper/*.sh \
		runtime/lib/*.sh \
		runtime/scripts/* \
		tests/*.sh

test:
	bash tests/run.sh

check: lint test

clean:
	rm -rf dest
