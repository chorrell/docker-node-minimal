#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

usage() {
    cat <<USAGE
Usage: $0 -n NODE_VERSION
    -n <NODE_VERSION> (Required)
    -h help
Example:
    $0 -n 16.2.0
USAGE
    exit 1
}

NODE_VERSION=

while getopts n:h? options; do
    case ${options} in
    n)
        NODE_VERSION=${OPTARG}
        ;;
    h)
        usage
        ;;
    \?)
        usage
        ;;
    esac
done

if [[ -z ${NODE_VERSION} ]]; then
    echo "FATAL: No value for -n, NODE_VERSION"
    echo ""
    usage
fi

for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
done

curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz"
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c -
tar -Jxf "node-v$NODE_VERSION.tar.xz"
cd "node-v$NODE_VERSION/"
./configure --fully-static --without-npm --without-intl
make -j$(getconf _NPROCESSORS_ONLN)
