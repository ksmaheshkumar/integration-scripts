#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh
LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-master-build/lastSuccessfulBuild/artifact/archives/}
UPLOAD_URL=${UPLOAD_URL:-}
ZIP_FILE=${ZIP_FILE:-}
PRODUCT=${PRODUCT:-cap}

# Comment out to enable monitoring
SKIP_MONITORING=true

# Cleaning
rm -rf ./jboss ./jboss2 ./results ./download ./report /tmp/cluster-binaries
mkdir ./results ./download /tmp/cluster-binaries || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $LASTBUILD_URL | grep -o "http:.*nuxeo\-cap.*.zip" | grep jboss | sort -u | grep -v ear | grep -v sdk | grep -v online`

    # Download and unpack the latest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-*jboss*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

build=$(find ./download -maxdepth 1 -name 'nuxeo-*' -name "*$PRODUCT*" -type d)
mv $build ./jboss || exit 1

# Update selenium tests
update_distribution_source

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database "$HERE/jboss"
fi


# remove ooo daemon, set opensocial port
cat >> "$JBOSS_HOME"/bin/nuxeo.conf <<EOF || exit 1
org.nuxeo.ecm.platform.transform.ooo.enableDaemon=false
opensocial.gadgets.port=8000
repository.clustering.enabled=true
EOF

# setup cluster mode
mkdir -p $JBOSS_HOME/templates/postgresql/deploy/nuxeo.ear/config
#cp ./cluster_default-repository-config.xml $JBOSS_HOME/templates/postgresql/deploy/nuxeo.ear/config/default-repository-config.xml

# setup jboss2
cp -r ./jboss ./jboss2

# Start --------------------------------------------------
# start pound
/usr/sbin/pound -f ./pound.cfg -p ./pound.pid || kill `cat ./pound.pid` && \
( /usr/sbin/pound -f ./pound.cfg -p ./pound.pid || exit 1 )

# Setup both JBoss
JBOSS_HOME_1="$HERE/jboss"
JMX_PORT=1089
setup_jboss "$JBOSS_HOME_1" 127.0.1.1
JBOSS_HOME_2="$HERE/jboss2"
JMX_PORT=1189
setup_jboss "$JBOSS_HOME_2" 127.0.1.2

# And start them
echo "########## Starting JBOSS1 ##########"
start_server "$JBOSS_HOME_1" 127.0.1.1
sleep 10
echo "########## Starting JBOSS2 ##########"
start_server "$JBOSS_HOME_2" 127.0.1.2

# Test --------------------------------------------------
# Run selenium tests first
# it requires an empty db
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
pushd $SELENIUM_PATH
mvn org.nuxeo.build:nuxeo-distribution-tools:integration-test -Dtarget=run-selenium -Dsuites=suite1,suite2,suite-dm,suite-webengine,suite-webengine-website,suite-webengine-tags -DnuxeoURL=http://localhost:8000/nuxeo/
mvn org.nuxeo.build:nuxeo-distribution-tools:verify
ret1=$?
popd


# Stop --------------------------------------------------

kill `cat ./pound.pid`
JBOSS_HOME_1="$HERE/jboss"
stop_server "$JBOSS_HOME_1"
JBOSS_HOME_2="$HERE/jboss2"
stop_server "$JBOSS_HOME_2"

cd "$HERE/jboss2/log"
for log in *.log.gz; do
    cp  $log "$HERE/jboss/log/"${log%.log.gz}2.log.gz
done
# use sysstat log of jboss 2
if [ -z "$SKIP_MONITORING" ]; then
    cp "$HERE"/jboss2/log/sysstat-sar.log.gz "$HERE"/jboss/log/
fi
exit $ret1
