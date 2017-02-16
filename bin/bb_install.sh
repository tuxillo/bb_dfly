#! /bin/sh

TDIR=$1
PASS=$2

check_prereq()
{

    # Make sure TDIR is a directory and  that it
    # does not contain other buildbot instances.
    if [ -z "${TDIR}" ]; then
	echo "Target directory is empty"
	exit 1
    elif [ ! -d "${TDIR}" ]; then
	echo "Target is not a directory"
	exit 1
    elif [ -d "${TDIR}/bb_master" ]; then
	echo "buildbot is already installed in that path"
	exit 1
    elif [ -d "${TDIR}/bb_worker" ]; then
	echo "buildbot is already installed in that path"
	exit 1
    fi

    echo -n "Checking for programs: "

    # python2 and virtualenv are needed
    if [ ! -x "$(which python)" ]; then
	echo
	echo "python has not been found"
    else
	pymajor="$(python -c 'import sys; print(".".join(map(str, sys.version_info[:1])))')"
	if [ "${pymajor}" != "2" ]; then
	    echo
	    echo "python2 is required"
	    exit 1
	fi
	echo -n "python "
    fi
    if [ ! -x "$(which virtualenv)" ]; then
	echo
	echo "virtualenv has not been found"
	exit 1
    else
	echo -n "virtualenv "
    fi

    echo "ok"
}

install_bb_master()
{

    mkdir -p ${TDIR}/bb_master || (echo "Failed to create dir" && exit 1)

    echo "Installing bb_master"

    cd ${TDIR}/bb_master
    virtualenv --no-site-packages sandbox >> ${TDIR}/bb_install.log 2>&1
    . sandbox/bin/activate >> ${TDIR}/bb_install.log 2>&1

    pip install --upgrade pip >> ${TDIR}/bb_install.log 2>&1
    pip install 'buildbot[bundle]' >> ${TDIR}/bb_install.log 2>&1

    if [ $? -ne 0 ]; then
	echo "Installation failed, cleaning up"
	rm -fr ${TDIR}/bb_master
	exit 1
    fi
}

config_bb_master()
{
    echo "Setting up bb_master"

    buildbot create-master master >> ${TDIR}/bb_install.log 2>&1
    mv master/master.cfg.sample master/master.cfg >> ${TDIR}/bb_install.log 2>&1

}

install_bb_worker()
{

    mkdir -p ${TDIR}/bb_worker || (echo "Failed to create dir" && exit 1)

    echo "Installing bb_worker"

    cd ${TDIR}/bb_worker
    virtualenv --no-site-packages sandbox >> ${TDIR}/bb_install.log 2>&1
    . sandbox/bin/activate >> ${TDIR}/bb_install.log 2>&1

    pip install --upgrade pip >> ${TDIR}/bb_install.log 2>&1
    pip install buildbot-worker >> ${TDIR}/bb_install.log 2>&1

    if [ $? -ne 0 ]; then
	echo "Installation failed, cleaning up"
	rm -fr ${TDIR}/bb_worker
	exit 1
    fi
}

config_bb_worker()
{
    echo "Setting up bb_worker"
    buildbot-worker create-worker worker localhost example-worker ${PASS:-pass} >> ${TDIR}/bb_install.log 2>&1
}

# MAIN -------------------------------

if [ $# -lt 1 ]; then
    echo "$0: [targetdir] [pass]"
    exit 1
fi

check_prereq
install_bb_master
config_bb_master
install_bb_worker
config_bb_worker
