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

cd ${prefix}/bb_${role} || exit 1

. sandbox/bin/activate

shift
buildbot ${CMD} $@
