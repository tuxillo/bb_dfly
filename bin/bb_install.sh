#! /bin/sh

. etc/subs.sh
. etc/bb_dfly.conf

verbose=1
logfile=${prefix}/bb_install.log

check_prereq()
{

    # Force builbot user for the installation
    if [ "$(id -nu)" != "${bbuser}" ]; then
	err 1 "This program must be run by ${bbuser}"
    fi

    # Make sure prefix is a directory and that it
    # does not contain other buildbot instances.
    if [ -z "${prefix}" ]; then
	err 1 "prefix variable is not set"
    elif [ ! -d "${prefix}" ]; then
	err 1 "Target is not a directory"
    fi

    # python2 and virtualenv are needed
    [ ! -x "$(which python)" ] && err 1 "python has not been found"

    pymajor="$(python -c 'import sys; print(".".join(map(str, sys.version_info[:1])))')"
    if [ "${pymajor}" != "2" ]; then
	err 1 "python2 is required"
    fi

    [ ! -x "$(which virtualenv)" ] && err 1 "virtualenv has not been found"
}

install_bb_master()
{
    runcmd mkdir -p ${prefix}/bb_master

    info "Installing bb_master"

    runcmd cd ${prefix}/bb_master
    runcmd virtualenv --no-site-packages sandbox
    . sandbox/bin/activate

    runcmd pip install --upgrade pip
    runcmd pip install 'buildbot[bundle]'

    if [ $? -ne 0 ]; then
	echo "Installation failed, cleaning up"
	rm -fr ${prefix}/bb_master
	exit 1
    fi
}

config_bb_master()
{
    echo "Setting up bb_master"

    runcmd cd ${prefix}/bb_master
    . sandbox/bin/activate

    runcmd buildbot create-master master
    runcmd fetch -q \
	   https://raw.githubusercontent.com/tuxillo/bb_dfly/master/etc/master.cfg \
	   -o ${prefix}/bb_master/master/master.cfg
}

install_bb_worker()
{

    runcmd mkdir -p ${prefix}/bb_worker

    echo "Installing bb_worker"

    runcmd cd ${prefix}/bb_worker
    runcmd virtualenv --no-site-packages sandbox
    . sandbox/bin/activate

    runcmd pip install --upgrade pip
    runcmd pip install buildbot-worker

    if [ $? -ne 0 ]; then
	echo "Installation failed, cleaning up"
	rm -fr ${prefix}/bb_worker
	exit 1
    fi
}

config_bb_worker()
{
    # worker name relies on the hostname, which should be either release or master
    # depending on what the vkernel dragonfly version is
    runcmd cd ${prefix}/bb_worker
    . sandbox/bin/activate

    echo "Setting up bb_worker"
    runcmd buildbot-worker create-worker worker ${bb_master_ip} \
		    "$(hostname)" ${worker_pass}
}

# MAIN -------------------------------

case "$1" in
    master)
	# Master runs with ${bbuser}
	check_prereq
	install_bb_master
	config_bb_master
	;;
    worker)
	# Workers run with root inside the vkernels
	check_prereq
	install_bb_worker
	config_bb_worker
	;;
    *)
	err 1 "$0 [master|worker]"
	;;
esac
