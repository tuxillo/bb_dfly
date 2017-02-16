#! /bin/sh

. ../etc/subs.sh

verbose=1
logfile=$(mktemp)

mount_proc()
{
    local rootdir=$1
    runcmd mount_procfs procfs ${rootdir}/proc
}

umount_proc()
{
    local rootdir=$1
    runcmd umount ${rootdir}/proc
}

mount_dev()
{
    local rootdir=$1
    runcmd mount_devfs devfs ${rootdir}/dev
}

umount_dev()
{
    local rootdir=$1
    runcmd umount ${rootdir}/dev
}

chroot_up()
{
    info Setting up chroot...

    # Mount devfs
    mount_dev ${DESTDIR}

    # Mount procfs
    mount_proc ${DESTDIR}

    # Initial resolv.conf
    runcmd cp /etc/resolv.conf ${DESTDIR}/etc/

    #
    # Customize a bit for the build process
    #
    runcmd chroot ${DESTDIR} fetch \
	   --no-verify-peer https://leaf.dragonflybsd.org/~tuxillo/archive/misc/bb-jail-cust.sh
    runcmd chroot ${DESTDIR} /bin/sh bb-jail-cust.sh
}

chroot_down()
{
    info Shutting down chroot...

    # Kill all processes in the builder jail
    #  runcmd sudo jexec ${jid} /bin/kill -TERM -1 > /dev/null

    # Umount devfs
    umount_dev ${DESTDIR}

    # Umount procfs
    umount_proc ${DESTDIR}

}

######## MAIN

# Sanity checks
if [ `id -u` -ne 0 ]; then
    err 1 You must be root to run this script
fi

validate_destdir

case "$1" in
    "start"|"START")
	chroot_up
	;;
    "stop"|"STOP")
	chroot_down
	;;
    *)
	err 1 "Valid commands $0 [start|stop]"
	;;
esac

# Cleanup
rm ${logfile}
