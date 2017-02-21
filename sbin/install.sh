#! /bin/sh

. etc/subs.sh

verbose=1
logfile=$(mktemp)
sshopts="-o StrictHostKeyChecking=false -o ConnectTimeout=5"

# Read configuration file
. etc/bb_dfly.conf

prepare()
{
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
	*) err 1 "Wrong URL format" ;;
    esac

    runcmd mkdir -p ${prefix}/${imgdir}

    # Remove previous host key from known_hosts
    runcmd ssh-keygen -qR ${ip}

    # shutdown vkernel if it's up
    ssh ${sshopts} -i ${key} root@${ip} uptime >> ${logfile} 2>&1
    if [ $? -eq 0 ]; then
	info "Stopping ${imgdir} vkernel for configuration"
	runcmd /etc/rc.d/vkernel onestop
    fi

    # Check if the images are already there
    if [ -f ${prefix}/${imgdir}/root.img ]; then
	info "${imgdir} vkernel is already in place, skipping."
    else
	# Get image from URL and extract it
	info "Downloading/extracting ${imgdir} vkernel"
	fetch -q -o - ${url} | \
	    tar -C ${prefix} -xJf -
	[ $? -ne 0 ] && err 1
    fi

    # Mount image and setup things
    vn=$(vnconfig -l | fgrep 'not in use' | cut -d : -f1 | head -1)
    [ -z "${vn}" ] && err 1 "No vn free"

    runcmd vnconfig ${vn} ${prefix}/${imgdir}/root.img
    runcmd mount ${vn}s1a /mnt

    # Customize vkernel
    if [ ! -f /mnt/etc/fstab ]; then
	info "Customizing vkernel (fstab/rc.conf/resolv.conf/authorized_keys)"
	cat <<EOF > /mnt/etc/fstab
/dev/vkd0s1a      /       ufs     rw      1  1
proc              /proc   procfs  rw      0  0
EOF
    fi

    if [ ! -f /mnt/etc/rc.conf ]; then
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
    fi

    if [ ! -f /mnt/etc/resolv.conf ]; then
	cp /etc/resolv.conf /mnt/etc/resolv.conf
    fi
    
    runcmd mkdir -m 0700 -p /mnt/root/.ssh


    if [ ! -f /mnt/root/.ssh/authorized_keys ]; then
	cat ${key}.pub >> /mnt/root/.ssh/authorized_keys
    fi

    runcmd umount /mnt
    runcmd vnconfig -u ${vn}
    runcmd mkdir -m 1777 -p /var/vkernel

    info "Starting ${imgdir} vkernel (60 sec timeout)"

    list=$(grep vkernel_list /etc/rc.conf | tr -d \" | cut -d= -f2 | sed -e "s/${imgdir}//")

    # Remove previous list from file
    sed -I .bak "/vkernel_list/d" /etc/rc.conf

    # Remove any previous vkernel configuration
    sed -I .bak2 "/vkernel_${imgdir}/d" /etc/rc.conf

    cat<<EOF>>/etc/rc.conf
vkernel_list="${list} ${imgdir}"
vkernel_${imgdir}_bin="${prefix}/${imgdir}/vkernel"
vkernel_${imgdir}_memsize="${vkernel_memsize}"
vkernel_${imgdir}_rootimg_list="${prefix}/${imgdir}/root.img"
vkernel_${imgdir}_iface_list="-I /var/run/vknet"
vkernel_${imgdir}_logfile="/dev/null"
vkernel_${imgdir}_flags="-U"
vkernel_${imgdir}_kill_timeout="45"
EOF

    runcmd /etc/rc.d/vkernel onestart
    for n in $(seq 1 10)
    do
	ssh ${sshopts} -i ${key} root@${ip} uptime >> ${logfile} 2>&1
	if [ $? -eq 0 ]; then
  	    break
	fi
	sleep 5
    done

    ssh ${sshopts} -i ${key} root@${ip} uptime >> ${logfile} 2>&1
    [ $? -ne 0 ] && err 1 "${imgdir} vkernel not accesible, aborting"

    info "Customizing vkernel (pkg/buildbot)"

    # take care of pkg bootstrap
    ssh ${sshopts} -i ${key} root@${ip} -- \
	"[ -x /usr/local/sbin/pkg ]"

    if [ $? -ne 0 ]; then
	ssh ${sshopts} -i ${key} root@${ip} -- \
	    "cd /usr && make pkg-bootstrap" >> ${logfile} 2>&1
	[ $? -ne 0 ] && err 1 "Could not install pkg bootstrap in vkernel"
    fi

    # install required packages if needed
    ssh ${sshopts} -i ${key} root@${ip} -- \
	"pkg install -y python py27-virtualenv py27-sqlite3 git-lite" >> ${logfile} 2>&1
    [ $? -ne 0 ] && err 1 "Could not install software in vkernel"

    # clone or pull repo
    ssh ${sshopts} -i ${key} root@${ip} -- \
	"[ -d /root/bb_dfly ]"
    if [ $? -eq 0 ]; then
	ssh ${sshopts} -i ${key} root@${ip} -- \
	    "cd /root/bb_dfly && git reset --hard HEAD^ && git pull" >> ${logfile} 2>&1
	[ $? -ne 0 ] && err 1 "Could not pull repo"
    else
	ssh ${sshopts} -i ${key} root@${ip} -- \
	    "git clone https://github.com/tuxillo/bb_dfly.git /root/bb_dfly" >> ${logfile} 2>&1
	[ $? -ne 0 ] && err 1 "Could not clone repo"
    fi

    # copy local configuration
    scp ${sshopts} -i ${key} etc/bb_dfly.conf root@${ip}:/root/bb_dfly/etc
    [ $? -ne 0 ] && err 1 "Could not copy local configuration."

    # Install bb_worker
    ssh ${sshopts} -i ${key} root@${ip} -- \
	"[ -d /build/buildbot/bb_worker ]"

    if [ $? -ne 0 ]; then
	ssh -o StrictHostKeyChecking=false -i ${key} root@${ip} -- \
	    "mkdir -p ${prefix} && cd /root/bb_dfly && ./bin/bb_install.sh worker" >> ${logfile} 2>&1
	[ $? -ne 0 ] && err 1 "Could not install buildbot worker"
    fi
}

bootstrap()
{
    # Prepare vkernel boostrap images
    bootstrap_vkernel ${vkernel_master_url} ${vkernel_master_ip} \
		     ${vkernel_master_rsa_key}
#    bootstrap_vkernel ${vkernel_release_url} ${vkernel_release_ip} \
#		     ${vkernel_release_rsa_key}
}


# Install bbm and bbw
#./bin/bb_install.sh

# Install doas.conf
#cat etc/doas.conf.template >> 

prepare
bootstrap

