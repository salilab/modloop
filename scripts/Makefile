include ../Makefile.include

install:
	mkdir -p ${SCRIPTS}
	sed -e 's#@QUEUEDIR@#${QUEUEDIR}#' -e 's#@SCRIPTS@#${SCRIPTS}#' < Modloop_sub.pl > ${SCRIPTS}/Modloop_sub.pl
	chmod 755 ${SCRIPTS}/Modloop_sub.pl
	cp codinetmp.sh ${SCRIPTS}
	crontab crontab
