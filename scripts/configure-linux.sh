#!/bin/bash

# This script is only tested on CentOS 7.5, RHEL 7.6 and Ubuntu 18.04 LTS.
MOUNTPOINT="/hxdata"

# An set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

# if on RHEL, open firewall
# if [ "$OS" == "RHEL 7.6" ] || [ "$OS" == "CentOS 7.5" ]
# then
#   firewall-cmd --zone=public --add-port=80/tcp --permanent
#   firewall-cmd --reload
# fi

check_os() {
    grep ubuntu /proc/version > /dev/null 2>&1
    isubuntu=${?}
    grep centos /proc/version > /dev/null 2>&1
    iscentos=${?}
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

get_disk_count() {
    DISKCOUNT=0
    for DISK in "${DISKS[@]}";
    do
        DISKCOUNT+=1
    done;
    echo "$DISKCOUNT"
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    DISK=${1}
    echo "Partitioning disk $DISK"
    echo "n
p
1


w
" | fdisk "${DISK}"
#> /dev/null 2>&1

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${DISK}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}

add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=${UUID} ${MOUNTPOINT} xfs     defaults       0 0"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

configure_disks() {
	ls "${MOUNTPOINT}"
	if [ ${?} -eq 0 ]
	then
		return
	fi
    DISKS=($(scan_for_new_disks))
    echo "Disks are ${DISKS[@]}"
    declare -i DISKCOUNT
    DISKCOUNT=$(get_disk_count)
    echo "Disk count is $DISKCOUNT"
    DISK="${DISKS[0]}"
    do_partition ${DISK}
    PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')

    echo "Creating filesystem on ${PARTITION}."
    mkfs -t xfs ${PARTITION}
    mkdir "${MOUNTPOINT}"
    read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
    add_to_fstab "${UUID}" "${MOUNTPOINT}"
    echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
    mount "${MOUNTPOINT}"
}

disable_apparmor_ubuntu() {
    /etc/init.d/apparmor teardown
    update-rc.d -f apparmor remove
}

disable_selinux_centos() {
    sed -i 's/^SELINUX=.*/SELINUX=permissive/I' /etc/selinux/config
    setenforce 0
}

configure_network() {
    # open_ports
    if [ $iscentos -eq 0 ];
    then
        disable_selinux_centos
        # firewall-cmd --zone=public --add-port=80/tcp --permanent
        # firewall-cmd --zone=public --add-port=1666/tcp --permanent
        # firewall-cmd --reload
    elif [ $isubuntu -eq 0 ];
    then
        disable_apparmor_ubuntu
    fi
}

check_os
if [ $iscentos -ne 0 ] && [ $isubuntu -ne 0 ];
then
    echo "unsupported operating system"
    exit 1
else
    configure_network
    configure_disks
fi
