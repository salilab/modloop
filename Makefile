include Makefile.include

SUBDIRS=html cgi scripts
.PHONY: install ${SUBDIRS}

install: $(SUBDIRS)
	mkdir -p ${QUEUEDIR} ${FINISHEDDIR}
	chown modloop.apache ${QUEUEDIR}
	chown modloop ${FINISHEDDIR}
	chmod 775 ${QUEUEDIR}
	@echo "ScriptAlias /modloop/cgi ${CGI}" > /etc/httpd/conf.d/modloop.conf
	@echo "Alias /modloop ${HTML}" >> /etc/httpd/conf.d/modloop.conf
	@echo "Don't edit files in this directory!" > ${TOP}/README
	@echo "Instead, check out the modloop SVN repository," >> ${TOP}/README
	@echo "and run 'make' from within that checkout." >> ${TOP}/README
	@echo
	@echo "** Note: may need to restart httpd to pick up modloop alias."
	@echo "** Also, make sure that ${RUNDIR} exists and is"
	@echo "** writeable by the modloop user."

${SUBDIRS}:
	${MAKE} -C $@
