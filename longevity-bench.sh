#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}

# Cleaning
rm -rf ./jboss ./report ./download
mkdir ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $LASTBUILD_URL | grep -o "http:.*nuxeo\-.*.zip\(.md5\)*" | sort -u`
    # Download and unpack the lastest builds
    for link in $links; do
        wget -nv $link || exit 1
    done
    unzip -q nuxeo-*jboss*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# JBOSS tests --------------------------------------------------------
build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./jboss || exit 1

# Update funkload/selenium tests
update_distribution_source
setup_jboss 127.0.0.1

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Start jboss
start_server 127.0.0.1

# Run simple rest, web and webengine tests
test_path=$NXDIR/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload/
(cd $test_path; make bench-longevity EXT="--no-color"; ret=$?; make stop; exit $ret)
ret1=$?
mv $NXDIR/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload/target/results ./report

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
