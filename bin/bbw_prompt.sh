#! /bin/sh

TDIR=$1

if [ -z "${TDIR}" ]; then
    echo "Specify bb_worker dir"
    exit 1
fi

cd ${TDIR}/bb_worker || exit 1

. sandbox/bin/activate
PS1="(`basename \"$VIRTUAL_ENV\"_worker`) $ "
/bin/sh
