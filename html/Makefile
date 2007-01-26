include ../Makefile.include
DISTFILES=bg_3.gif modloop_title_blue.gif logo33.gif \
          pdfsml.gif index.html help.html modloop.css


install:
	mkdir -p ${HTML}
	cp ${DISTFILES} ${HTML}
	(cd ${HTML} && rm -f modloop.html && ln -s index.html modloop.html)
