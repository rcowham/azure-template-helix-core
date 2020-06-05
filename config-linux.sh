#!/bin/bash

# confirmed: this script works when run manually as root user from root top directory using the following command
# sh ./config-linux.sh -u <username> -p <password> -h admin -i admin
# customized to reflect machine admin username and admin password

while getopts u:p:f:h:i option
do
 case "${option}"
 in
 u) USER=${OPTARG};;
 p) PASSWORD=${OPTARG};;
 f) OS=${OPTARG};;
 h) TS_USER=${OPTARG};;
 i) TS_PASS=${OPTARG};;
esac
done

cd /tmp/

echo "script executed" > script.log

# if on RHEL, open firewall
if [ "$OS" == "RHEL 7.6" ] || [ "$OS" == "CentOS 7.5" ]
then
  firewall-cmd --zone=public --add-port=80/tcp --permanent
  firewall-cmd --reload
fi
