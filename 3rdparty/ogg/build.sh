#!/bin/sh

src="libogg-1.3.2"
if [ "$1" = "" ]; then
  dest=`pwd`/../build
else
  dest=$1
fi

curl -O http://downloads.xiph.org/releases/ogg/${src}.tar.gz

tar xf ${src}.tar.gz

cd ${src}

./configure --prefix=${dest} --disable-shared --with-pic
make -j4
make install
make clean

cd ..

rm -rf ${src} *.tar.gz

