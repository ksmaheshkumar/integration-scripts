#!/bin/bash -xe

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.5-build/lastSuccessfulBuild/artifact/trunk/release/archives}
HERE=$(cd $(dirname $0); pwd -P)

# Upload successfully tested package and sources on $UPLOAD_URL
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:-download}
if [ ! -z "$UPLOAD_URL" ]; then
    ls $SRC_URL/*HF*.zip >/dev/null 2>&1 && exit 0 || true
    date
    scp -C $SRC_URL/*.zip* $UPLOAD_URL || true
    mkdir -p $HERE/download/mp
    cd $HERE/download/mp
    links=`lynx --dump $LASTBUILD_URL/mp | grep -E -o 'http:.*archives\/((nuxeo-.*(-sdk)*.zip(.md5)*)|packages.xml)' | sort -u`
    if [ ! -z "$links" ]; then
        wget -nv $links
        scp -C $SRC_URL/mp/* $UPLOAD_URL/mp/ || true
    fi
    cd -
    date
fi
