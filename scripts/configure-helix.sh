#!/bin/bash

# This script is only tested on CentOS 7.5, RHEL 7.6 and Ubuntu 18.04 LTS.

MOUNTPOINT="/hxdata"
LOG=/tmp/init.log

while getopts w:p:s: option
do
  case "${option}"
  in
    w) PASSWORD=${OPTARG};;
    p) P4PORT=${OPTARG};;
    s) SWARMPORT=${OPTARG};;
  esac
done

echo "PASSWORD: $PASSWORD" >> $LOG
echo "P4PORT: $P4PORT" >> $LOG
echo "SWARMPORT: $SWARMPORT" >> $LOG

check_os() {
    grep ubuntu /proc/version > /dev/null 2>&1
    isubuntu=${?}
    grep centos /proc/version > /dev/null 2>&1
    iscentos=${?}
}


configure_helix() {
    useradd --shell /bin/bash --home-dir /p4 --create-home perforce
    cd "$MOUNTPOINT"
    mkdir hxlogs hxmetadata hxdepots
    chown -R perforce:perforce "$MOUNTPOINT"
    cd /
    ln -s $MOUNTPOINT/hx* .
    chown -h perforce:perforce hx*

    mkdir -p /hxdepots/reset
    cd /hxdepots/reset

    curl -k -s -O https://swarm.workshop.perforce.com/downloads/guest/perforce_software/helix-installer/main/src/reset_sdp.sh

    chmod +x reset_sdp.sh
    ./reset_sdp.sh -fast -no_sd > reset_sdp.log 2>&1

    systemctl enable p4d_1
    # Change default port and then generate SSL cert
    sudo -u perforce perl -pi -e 's/P4PORTNUM=1999/P4PORTNUM=1666/' /p4/common/config/p4_1.vars 
    sudo -u perforce bash -c "source /p4/common/bin/p4_vars 1 && /p4/1/bin/p4d_1 -Gc"
    systemctl start p4d_1
    if [ ! -z "${PASSWORD}" ]; then
        echo "$PASSWORD" > /p4/common/config/.p4passwd.p4_1.admin
    fi

    init_script=/p4/init.sh
cat <<"EOF" >$init_script
#!/bin/bash

su - perforce

source /p4/common/bin/p4_vars 1
p4 trust -y
p4 -p ssl:`hostname`:1666 trust -y
p4 user -o | p4 user -i

PASSWORD=`cat /p4/common/config/.p4passwd.p4_1.admin`
echo -e "$PASSWORD\n$PASSWORD" | p4 passwd
/p4/common/bin/p4login -v 1
/p4/sdp/Server/setup/configure_new_server.sh 1
crontab /p4/p4.crontab
EOF

    chmod +x $init_script
    $init_script >> $LOG 2>&1
}

check_os
if [ $iscentos -ne 0 ] && [ $isubuntu -ne 0 ];
then
    echo "unsupported operating system"
    exit 1
else
    configure_helix
fi
