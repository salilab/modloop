include ../Makefile.include

install:
	mkdir -p ${SCRIPTS}
	sed -e 's#@QUEUEDIR@#${QUEUEDIR}#' -e 's#@RUNDIR@#${RUNDIR}#' -e 's#@SCRIPTS@#${SCRIPTS}#' < Modloop_sub.pl > ${SCRIPTS}/Modloop_sub.pl
	chmod 755 ${SCRIPTS}/Modloop_sub.pl
	cp looptmp.py sge-template.sh ${SCRIPTS}
	/bin/echo -e "# ModLoop daemon\n0,15,30,45 * * * * ${SCRIPTS}/ModLoop_sub.pl" | crontab -u modloop -

