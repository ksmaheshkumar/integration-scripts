#!/bin/sh -x
# 5.2 specific integration build
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

ADDONS=${ADDONS:-}
TAG=${TAG:-"I"$(date +"%Y%m%d_%H%M")}
if [ $TAG == "final" ]; then
    # final release no more tag
    $TAG=
fi
# label for the zip package
LABEL=${LABEL:-}
DISTRIBUTIONS=${DISTRIBUTION:-'ALL'}

# dev workspace
DWS="$HERE"/dev
# release workspace
RWS="$HERE"/release

if [ ! -e $DWS ]; then
    mkdir -p $DWS || exit 1
    cd $DWS
    nx-builder clone || exit 2
else
    cd $DWS
    nx-builder pull || exit 2
fi

[ -e $RWS ] && rm -rf $RWS
mkdir $RWS || exit 1
cd $RWS || exit 1

# setup nx configuration file
cat > nx-builder.conf <<EOF
NX_HG=$DWS/nuxeo
NXA_HG=$DWS/addons
MVNOPTS=
MAVEN_PROFILES=local-deployment,timestamp-rev-in-mf
JBOSS_ARCH=$JBOSS_ARCHIVE
JBOSS_PATCH=patch

NXP_BRANCH=5.2
NXP_SNAPSHOT=5.2-SNAPSHOT
NXP_TAG=5.2.0$TAG
NXP_NEXT_SNAPSHOT=5.2-SNAPSHOT

NXC_BRANCH=1.5
NXC_SNAPSHOT=1.5-SNAPSHOT
NXC_TAG=1.5.0$TAG
NXC_NEXT_SNAPSHOT=1.5-SNAPSHOT

# Addons
NXA_BRANCH=5.2
NXA_SNAPSHOT=5.2-SNAPSHOT
NXA_TAG=5.2.0$TAG
NXA_NEXT_SNAPSHOT=5.2-SNAPSHOT

NXP_BRANCH_NULL_MERGE=
NXC_BRANCH_NULL_MERGE=
NXA_BRANCH_NULL_MERGE=

NXA_MODULES="$ADDONS"

EOF

nx-builder prepare || exit 1

nx-builder package || exit 1

if [ $DISTRIBUTIONS == 'ALL' ]; then
    jboss_zip=`find $RWS/archives/ -name "nuxeo*jboss*.zip"`

    nx-builder package-we || exit 1

    nx-builder zip2jar $jboss_zip || exit 1
fi

cp fallback* archives/
