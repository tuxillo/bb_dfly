#! /bin/sh

TDIR=$1

if [ -z "${TDIR}" ]; then
    echo "buildbot directory not specified"
    exit 1
fi

./bin/bbw_cmd.sh ${TDIR} stop worker || echo "Failed to stop buildbot worker"
./bin/bbm_cmd.sh ${TDIR} stop master || echo "Failed to stop buildbot master"

