#!/bin/bash

VERBOSE_FLAG=""
if [[ "$1" == "-verbose" ]]; then
    VERBOSE_FLAG="-verbose"
fi

# SERVER 1
echo "Configuring server1..."
scp configure-host.sh remoteadmin@server1-mgmt:/root || { echo "SCP to server1 failed"; exit 1; }
ssh remoteadmin@server1-mgmt -- "/root/configure-host.sh $VERBOSE_FLAG -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4"

# SERVER 2
echo "Configuring server2..."
scp configure-host.sh remoteadmin@server2-mgmt:/root || { echo "SCP to server2 failed"; exit 1; }
ssh remoteadmin@server2-mgmt -- "/root/configure-host.sh $VERBOSE_FLAG -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3"

# LOCAL HOST UPDATES
echo "Updating local /etc/hosts..."
./configure-host.sh $VERBOSE_FLAG -hostentry loghost 192.168.16.3
./configure-host.sh $VERBOSE_FLAG -hostentry webhost 192.168.16.4

echo "Lab 3 complete!"
