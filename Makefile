include Makefile.include

SUBDIRS=html cgi scripts
.PHONY: install ${SUBDIRS}

install: $(SUBDIRS)

${SUBDIRS}:
	${MAKE} -C $@
