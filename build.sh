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

NODE_KEYS=$(curl -fsSLo- --compressed https://github.com/nodejs/node/raw/master/README.md | awk '/^gpg --keyserver pool.sks-keyservers.net --recv-keys/ {print $NF}')

for key in $NODE_KEYS; do
    if [[ -n "$key" ]]; then
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ;
    fi
done

curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz"
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c -
tar -Jxf "node-v$NODE_VERSION.tar.xz"
cd "node-v$NODE_VERSION/"
./configure --fully-static --without-npm --without-intl
make -j"$(getconf _NPROCESSORS_ONLN)"
