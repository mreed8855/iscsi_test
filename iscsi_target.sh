#!/bin/bash
# Set up Iscsi target

DEVICE_DIR="/var/lib/iscsi_disks/"
BACKING_DEVICE=$DEVICE_DIR"disk01.img"
ISCSI_CONF="/etc/tgt/conf.d/iscsi.conf"

# Temp hack for vm's  **Need sudo ato fix**
if [ -z "$1" ]; then
    IP_ADDRESS=`hostname -I`
else
    IP_ADDRESS=$1
fi

# Install packages
apt update -y
apt install tgt -y
apt install net-tools -y

if [ -f "$BACKING_DEVICE" ]; then
    echo "$BACKING_DEVICE exists"
else
    echo "Create Disk for Target "
    sudo mkdir -p $DEVICE_DIR
    sudo dd if=/dev/zero of=$BACKING_DEVICE count=0 bs=1 seek=10G
fi

if [ -f "$ISCSI_CONF" ]; then
    echo "$ISCSI_CONF exists, remove file"
    sudo rm $ISCSI_CONF
fi    

echo "Create and Configure $ISCSI_CONF"
cat <<EOF >> $ISCSI_CONF
<target iqn.2020-07.example.com:lun1>
     backing-store $BACKING_DEVICE
     initiator-address $IP_ADDRESS
     incominguser iscsi-user ubuntu
     outgoinguser iscsi-target ubuntu
</target>
EOF
   

systemctl restart tgt

# grep for ready or online or something to indicate its working correctly
tgtadm --mode target --op show

# Grant access to ALL.  It could cause an error if this is not run
tgtadm --lld iscsi --op bind --mode target --tid 1 -I ALL

echo "iSCSI Target Creation Complete"
