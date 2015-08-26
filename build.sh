#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

usage() {
cat <<EOF

Create a minimal Docker Node.js image for a given version of Node.js.

Usage:
  $0 -v <VERVSION>

Example:
  $0 -v 0.12.7

OPTIONS:
  -v The desired version of Node.js (e.g 0.12.7)
  -h Show this message

EOF
}

VERSION=
TAG=
ROOTFSDIR=/var/tmp/rootfs

while getopts "hv:" OPTION
do
  case $OPTION in
    h)
      usage
      exit
      ;;
    v)
      VERSION=${OPTARG}
      ;;
    \?)
      usage
      exit
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if [[ -z ${VERSION} ]]; then
  echo "Error: missing version (-v) value"
  exit 1
fi

if [[ -d $ROOTFSDIR ]]; then
  echo "Found previous rootfs directory. Deleting and creating a new one."
  
  rm -rf $ROOTFSDIR
fi

mkdir -p $ROOTFSDIR
mkdir -p $ROOTFSDIR/bin

echo "Getting version $VERSION of Node.js..."
curl -Os https://nodejs.org/dist/v$VERSION/node-v$VERSION.tar.gz
tar -zxvf node-v$VERSION.tar.gz
pushd $PWD
cd node-v$VERSION/

echo "Statically compiling Node.js v$VERSION"
./configure --fully-static
make

cp out/Release/node $ROOTFSDIR/bin/

popd

echo "Creating rootfs tarball"
tar --numeric-owner --create --auto-compress --file "rootfs.tar.xz" --directory "$ROOTFSDIR" --transform='s,^./,,' .

echo "Creating Dockerfile"
cat > Dockerfile <<EOF
FROM scratch
MAINTAINER christopher@horrell.ca
ADD rootfs.tar.xz /
ENTRYPOINT ["/bin/node"]
EOF

echo "Cleaning up"
rm -rf node-v$VERSION.tar.gz
rm -rf node-v$VERSION/
