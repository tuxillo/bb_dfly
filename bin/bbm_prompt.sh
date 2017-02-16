#! /bin/sh

TDIR=$1

if [ -z "${TDIR}" ]; then
    echo "Specify bb_master dir"
    exit 1
fi

cd ${TDIR}/bb_master || exit 1

. sandbox/bin/activate
PS1="(`basename \"$VIRTUAL_ENV\"_master`) $ "
/bin/sh

