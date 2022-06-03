
INSTALL_LOCATION ?= /usr/local/include/#
LIB_FILE := decomposer.mk

install:
	cp ${LIB_FILE} ${INSTALL_LOCATION}

clean un-install:
	rm ${INSTALL_LOCATION}${LIB_FILE}
