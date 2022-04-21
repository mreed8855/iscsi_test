#!/bin/bash
# set -x 
ISCSI_TARGET=$1
ISCSI_INIT="/etc/iscsi/initiatorname.iscsi"
ISCSI_ISCSID="/etc/iscsi/iscsid.conf"
SFDISK_PART="/tmp/sdpart.out"
MOUNTED_DIR="/mnt/iscsi_test"
USERNAME="iscsi-user"
PASSWORD="ubuntu"
NODE_CHAP="node.session.auth.authmethod = CHAP"
iscsid_settings=("node.session.auth.username = $USERNAME" 
				 "node.session.auth.password = $PASSWORD") 

is_mounted()
{
    mountpoint -q "$1"
}

cleanup_iscsi_dir_dev()
{
    set -x
    echo "unmount, remove partion and logout"
	sudo umount $1
	sudo sfdisk --delete $2
	sudo iscsiadm -m node --targetname $ISCSI_LUN --portal $ISCSI_TARGET  --logout
}
apt update -y
apt-get install stress-ng open-iscsi lsscsi -y

# Create a backup of the iscsid.conf file
if [ -f "$ISCSI_ISCSID.bak" ]; then
    echo "$ISCSI_ISCSID.bak exists"
else
    echo "$ISCSI_ISCSID.bak does not exists so create a backup"
    cp $ISCSI_ISCSID $ISCSI_ISCSID.bak
fi

# Configure 
# Check CHAP settings
grep -F -q "$NODE_CHAP" $ISCSI_ISCSID
    if [ $? -eq 0 ]; then
    echo "Uncomment CHAP setting"
        sed -i "/^#$NODE_CHAP/ c$NODE_CHAP" $ISCSI_ISCSID
    else
        echo "not found"
    fi
    
for ((i = 0; i < ${#iscsid_settings[@]}; i++))
do
    grep -q "${iscsid_settings[$i]}" $ISCSI_ISCSID
    if [ $? -eq 0 ]; then
       echo "found"
    else
       echo "Add username or password"
       echo "${iscsid_settings[$i]}" >> $ISCSI_ISCSID
    fi   
done

# Set InitiatorName
sed -i '/InitiatorName/s/^/#/g' $ISCSI_INIT
ISCSI_LUN=`/sbin/iscsi-iname`
echo  "InitiatorName=$ISCSI_LUN" >> $ISCSI_INIT

ISCSI_LUN=`iscsiadm -m discovery -t st -p $ISCSI_TARGET | cut -d" " -f 2`
sudo iscsiadm -m node --targetname $ISCSI_LUN --portal $ISCSI_TARGET  --login

#ISCI_DEV_CHECK=`sudo dmesg |  grep "Attached SCSI" |cut -d " " -f 5 | cut -c 2-4`
#ISCI_DEV="/dev/"$ISCI_DEV_CHECK

ISCI_DEV=`lsscsi | grep dev | awk '{print $6}'`
#echo "dev = $ISCSI_DEV"
#echo "dev check = $ISCI_DEV_CHECK"

if [ -f $SFDISK_PART ]; then
   echo "$SFDISK_PART exists"
else
cat <<EOF >> $SFDISK_PART
label: dos
label-id: 0xaf4181c3
device: /dev/sda
unit: sectors
sector-size: 512

/dev/sda1 : start=        2048, size=    20969472, type=83

EOF
fi

# Partition iSCSI device
sudo sfdisk $ISCI_DEV < $SFDISK_PART 
ISCI_DEV=$ISCI_DEV"1"

# Create filesystem
yes | sudo mkfs.ext4 $ISCI_DEV

# Create and Mount directory
mkdir -p $MOUNTED_DIR

if is_mounted "$MOUNTED_DIR"; then
    echo "$MOUNTED_DIR already mounted"
    sudo umount $MOUNTED_DIR 
else
     sudo mount $ISCI_DEV $MOUNTED_DIR   
fi

#Verify Mounted iSCSI directory
ls $MOUNTED_DIR
sudo lsblk
# | grep $ISCI_DEV
sudo stress-ng --temp-path $MOUNTED_DIR -d 5 -t 1m

cleanup_iscsi_dir_dev $MOUNTED_DIR $ISCI_DEV
echo "done"


