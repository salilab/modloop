include Makefile.include

SUBDIRS=html cgi scripts
.PHONY: install ${SUBDIRS}

install: $(SUBDIRS)
	mkdir -p ${QUEUEDIR} ${RUNDIR}
	chmod 775 ${QUEUEDIR}
	@echo
	@echo "To finalize installation, add"
	@echo
	@echo "ScriptAlias modloop/cgi ${CGI}
	@echo "Alias modloop ${HTML}"
	@echo
	@echo "to the Apache configuration (on alto), and make sure that"
	@echo "the ${QUEUEDIR} directory is owned by the nobody group."

${SUBDIRS}:
	@test `whoami` = "modloop" || (echo "Must run as the 'modloop' user"; exit 1)
	${MAKE} -C $@
