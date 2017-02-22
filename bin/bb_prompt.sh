#! /bin/sh

. etc/subs.sh
. etc/bb_dfly.conf

verbose=1
role=$1

case "${role}" in
    master)
    ;;
    worker)
    ;;
    *)
	err 1 "$0: [master|worker] cmd ..."
esac

cd ${TDIR}/bb_${role} || exit 1

. sandbox/bin/activate
PS1="(`basename \"$VIRTUAL_ENV\"_${role}`) $ "
/bin/sh
