#!/usr/bin/env bash

VERSION=0.12.7
ROOTFSDIR=/var/tmp/rootfs
TAG=
DIR=

curl -Os https://nodejs.org/dist/v$VERSION/node-v$VERSION.tar.gz
tar -zxvf node-v$VERSION.tar.gz
pushd $PWD
cd node-v$VERSION/
./configure --fully-static
make

mkdir $ROOTFSDIR
mkdir $ROOTFSDIR/bin
cp out/Release/node $ROOTFSDIR/bin/


tar --numeric-owner --create --auto-compress --file "rootfs.tar.xz" --directory "$ROOTFSDIR" --transform='s,^./,,' .


cat > Dockerfile <<EOF
FROM scratch
MAINTAINER image-team@joyent.com
ADD rootfs.tar.xz /
ENTRYPOINT ["/bin/node"]
EOF
docker build -t $TAG $DIR
