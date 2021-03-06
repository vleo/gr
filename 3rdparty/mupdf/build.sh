#!/bin/sh

src="mupdf-1.6-source"
if [ "$1" = "" ]; then
  dest=`pwd`/../build
else
  dest=$1
fi

curl -O http://mupdf.com/downloads/archive/${src}.tar.gz

tar xf ${src}.tar.gz

patch -p0 <mupdf.patch

opts="prefix=${dest} HAVE_MUJS=no HAVE_CURL=no XCFLAGS=-fPIC"
if [ `uname` = "Darwin" ]; then
  opts="${opts} HAVE_X11=no"
fi

make -C ${src} ${opts}
make -C ${src} ${opts} install
make -C ${src} ${opts} clean

rm -rf ${src} *.tar.gz

