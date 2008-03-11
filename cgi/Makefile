include ../Makefile.include

install:
	mkdir -p ${CGI}
	sed -e 's#@QUEUEDIR@#${QUEUEDIR}#' -e 's#@RUNDIR@#${RUNDIR}#' < Modloop.pl > ${CGI}/Modloop.pl
	sed -e 's#@QUEUEDIR@#${QUEUEDIR}#' -e 's#@RUNDIR@#${RUNDIR}#' -e 's#@FINISHEDDIR@#${FINISHEDDIR}#' < queue.pl > ${CGI}/queue.pl
	chmod 755 ${CGI}/Modloop.pl ${CGI}/queue.pl
	cp toptext.tex ${CGI}
