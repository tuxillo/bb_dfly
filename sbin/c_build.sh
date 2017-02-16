#! /bin/sh

. ../etc/subs.sh

verbose=1

######## MAIN

# Sanity checks
if [ `id -u` -ne 0 ]; then
    err 1 You must be root to run this script
fi

validate_destdir

case "$1" in
    "buildworld"|"buildkernel"|"nativekernel"|"installworld"|"installkernel")
	make -j$(sysctl -n hw.ncpu) $1
	;;
    "distribution")
	cd etc
	make $1
	;;
    *)
	err 1 "Invalid build option"
	;;
esac
