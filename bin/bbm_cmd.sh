#! /bin/sh

TDIR=$1
CMD=$2

if [ -z "${TDIR}" ]; then
    echo "Specify buildbot dir"
    exit 1
elif [ -z "${CMD}" ]; then
    echo "Specify a buildbot command"
    exit 1
fi

cd ${TDIR}/bb_master || exit 1

. sandbox/bin/activate

shift 2
buildbot ${CMD} $@
