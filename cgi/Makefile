include ../Makefile.include

install:
	mkdir -p ${CGI}
	sed -e 's#@QUEUEDIR@#${QUEUEDIR}#' < Modloop.pl > ${CGI}/Modloop.pl
	chmod 755 ${CGI}/Modloop.pl
	cp codinetmp.sh looptmp.top toptext.tex ${CGI}
