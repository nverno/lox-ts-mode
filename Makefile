SHELL    = /bin/bash
TSDIR   ?= $(CURDIR)/tree-sitter-lox
TESTDIR ?= $(CURDIR)/test
BINDIR  ?= $(CURDIR)/bin

all:
	@

dev: $(TSDIR)
$(TSDIR):
	@git clone https://github.com/nverno/tree-sitter-lox
	@cd $(TSDIR) && git checkout master && npm install && npm run build

.PHONY: parse-%
parse-%: dev
	@cd $(TSDIR) && npx tree-sitter parse $(TESTDIR)/$(subst parse-,,$@)

clean:
	$(RM) -r *~

distclean: clean
	$(RM) -rf $$(git ls-files --others --ignored --exclude-standard)
