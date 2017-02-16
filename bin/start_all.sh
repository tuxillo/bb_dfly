#! /bin/sh

TDIR=$1

if [ -z "${TDIR}" ]; then
    echo "buildbot directory not specified"
    exit 1
fi

./bin/bbm_cmd.sh ${TDIR} start master || (echo "Failed to start buildbot master" && exit 1)
./bin/bbw_cmd.sh ${TDIR} start worker || (echo "Failed to start buildbot worker" && exit 1)

