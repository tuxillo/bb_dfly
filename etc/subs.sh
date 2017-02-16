#! /bin/sh

#
# info message
# Display an informational message, typically under
#verbose mode.
info()
{
    local msg=$1
    shift

    [ ${verbose} -gt 0 ] && echo "INFO: " ${msg} $*
}

#
# err exitval message
#     Display an error and exit.
#
err()
{
    exitval=${1:-1}
    shift

    echo 1>&2 "ERROR: $*"
    exit $exitval
}

#
# runcmd cmd
# Execute a command
runcmd()
{
    local logf=${logfile}
    local cmd=$*
    local rc=0

    # If we don't have a logfile yet, discard the output
    [ -z "${logfile}" ] && logf="/dev/null"

    [ ${verbose} -gt 0 ] && echo "RUN: " ${cmd} >> ${logf}
    ${cmd}

    rc=$?

    if [ ${rc} -ne 0 ]; then
	err 1 "Failed to run ${cmd}"
    fi

    return ${rc}
}

validate_destdir()
{
    if [ -z "${DESTDIR}" ]; then
	err 255 "DESTDIR must be specified"
    elif [ ! -d "${DESTDIR}" ]; then
	err 254 "DESTDIR does not exist"
    elif [ "`realpath ${DESTDIR}`" == "/" ]; then
	err 253 "You cannot do that!"
    fi

}
