#! /bin/sh

verbose=1
. etc/subs.sh
. etc/bb_dfly.conf

check_prereq()
{

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

    [ -d ${prefix}/bb_master ] && (info "bb_master is already installed"; exit 0)

    su - ${bbuser} -c "mkdir -p ${prefix}/bb_master || (echo Failed to create dir && exit 1)"

    info "Installing bb_master"

    su - ${bbuser} -c "cd ${prefix}/bb_master && virtualenv --no-site-packages sandbox" >> \
       ${prefix}/bb_install.log 2>&1

    su - ${bbuser} -c "cd ${prefix}/bb_master && . sandbox/bin/activate && pip install --upgrade pip" >> \
       ${prefix}/bb_install.log 2>&1

    su - ${bbuser} -c "cd ${prefix}/bb_master && . sandbox/bin/activate && pip install 'buildbot[bundle]'" >> \
       ${prefix}/bb_install.log 2>&1

    if [ $? -ne 0 ]; then
	echo "Installation failed, cleaning up"
	rm -fr ${prefix}/bb_master
	exit 1
    fi
}

config_bb_master()
{
    echo "Setting up bb_master"

    su - ${bbuser} -c "cd ${prefix}/bb_master && . sandbox/bin/activate && buildbot create-master master" >> \
       ${prefix}/bb_install.log 2>&1


    su - ${bbuser} -c "cd ${prefix}/bb_master && . sandbox/bin/activate && " >> \
       ${prefix}/bb_install.log 2>&1

    su - ${bbuser} -c "fetch -q https://raw.githubusercontent.com/tuxillo/bb_dfly/master/etc/master.cfg -o ${prefix}/bb_master/master/master.cfg"

}

install_bb_worker()
{

    [ -d ${prefix}/bb_worker ] && (info "bb_worker is already installed"; exit 0)

    mkdir -p ${prefix}/bb_worker || (echo "Failed to create dir" && exit 1)

    echo "Installing bb_worker"

    cd ${prefix}/bb_worker
    virtualenv --no-site-packages sandbox >> ${prefix}/bb_install.log 2>&1
    . sandbox/bin/activate >> ${prefix}/bb_install.log 2>&1

    pip install --upgrade pip >> ${prefix}/bb_install.log 2>&1
    pip install buildbot-worker >> ${prefix}/bb_install.log 2>&1

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
    echo "Setting up bb_worker"
    buildbot-worker create-worker worker localhost \
		    "$(hostname)" ${worker_pass} >> ${prefix}/bb_install.log 2>&1
}

# MAIN -------------------------------

case "$1" in
    master|MASTER)
	# Master runs with ${bbuser}
	check_prereq
	install_bb_master
	config_bb_master
	;;
    worker|WORKER)
	# Workers run with root inside the vkernels
	check_prereq
	install_bb_worker
	config_bb_worker
	;;
    *)
	err 1 "$0 [master|worker]"
	;;
esac
