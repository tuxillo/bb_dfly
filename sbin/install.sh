#! /bin/sh

. ../etc/subs.sh

verbose=1
logfile=$(mktemp)

# Read configuration file
. ../etc/bb_dfly.conf

prepare()
{
    runcmd mkdir -p ${prefix}/master
    runcmd mkdir -p ${prefix}/release

    # Create 'bbdfly' user if it doesnt exist
    if ! pw user show bbdfly -q >/dev/null; then
	info "Creating user ${bbuser}"
	runcmd pw useradd -m -d /home/${bbuser} -u ${bbuser_uid} -s /bin/sh -n ${bbuser}
    else
	info "User ${bbuser} already exists"
    fi

    runcmd rm -f /home/${bbuser}/.profile
    runcmd rm -f /home/${bbuser}/.login

    su - ${bbuser} -c "mkdir -p -m 0700 /home/${bbuser}/.ssh" >> ${logfile}

    if [ ! -f ${vkernel_master_rsa_key} ]; then
	info "Generating RSA key for master worker"
	su - ${bbuser} -c \
	   "ssh-keygen -q -t rsa -f ${vkernel_master_rsa_key} -N ''"
    fi

    if [ ! -f ${vkernel_release_rsa_key} ]; then
	info "Generating RSA key for release worker"
	su - ${bbuser} -c \
	   "ssh-keygen -q -t rsa -f ${vkernel_release_rsa_key} -N ''"
    fi

}


#
# This assumes that the vkernel boostrap images have been
# built by test/vkernel and the files are put in master/ or
# release/ directories respectively.
#
bootstrap_vkernel()
{
    local url=$1
    local ip=$2
    local key=$3
    local imgdir=""
    local vn=""

    case "${url}" in
	*master*) imgdir="master" ;;
	*release*) imgdir="release" ;;
    esac

    # Check if the images are already there
    if [ -f ${prefix}/${imgdir}/root.img ]; then
	info "${imgdir} vkernel is already in place"
	return
    fi

    # Get image from URL and extract it
    info "Downloading ${imgdir} vkernel"
    fetch -q -o - ${url} | \
	tar -C ${prefix} -xJf -
    [ $? -ne 0 ] && err 1

    # Mount image and setup things
    vn=$(vnconfig -l | fgrep 'not in use' | cut -d : -f1 | head -1)
    [ -z "${vn}" ] && err 1 "No vn free"

    runcmd vnconfig ${vn} ${prefix}/${imgdir}/root.img
    runcmd mount ${vn}s1a /mnt

    # Customize vkernel
    cat <<EOF > /mnt/etc/fstab
/dev/vkd0s1a      /       ufs     rw      1  1
proc              /proc   procfs  rw      0  0
EOF

    cat <<EOF > /mnt/etc/rc.conf
hostname="${imgdir}"
network_interfaces="lo0 vke0"
ifconfig_vke0="inet ${ip} netmask 255.255.0.0"
defaultrouter=${gateway}
sendmail_enable="NO"
blanktime="NO"
sshd_enable="YES"
dntpd_enable="YES"
EOF

    runcmd mkdir -m 0700 -p /mnt/root/.ssh

    cat ${key}.pub >> /mnt/root/.ssh/authorized_keys

    runcmd umount /mnt
    runcmd vnconfig -u ${vn}
}

bootstrap()
{
    # Prepare vkernel boostrap images
    bootstrap_vkernel ${vkernel_master_url} ${vkernel_master_ip} \
		     ${vkernel_master_rsa_key}
    bootstrap_vkernel ${vkernel_release_url} ${vkernel_release_ip} \
		     ${vkernel_release_rsa_key}
}


# Install bbm and bbw
#./bin/bb_install.sh

# Install doas.conf
#cat etc/doas.conf.template >> 

prepare
bootstrap

