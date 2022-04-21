#!/bin/bash
# Set up virtual machines for iscsi testing

iscsi_target="iscsi_target"
iscsi_client="iscsi_client"
iscsi_password="ubuntu"
iscsi_target_script="iscsi_target.sh"
iscsi_client_script="iscsi_client.sh"
current_dir=`pwd`"/"

iscsi_target_script_local=$current_dir"iscsi_target.sh"
iscsi_client_script_local=$current_dir"iscsi_client.sh"
timeout=20

if [ -z "$1" ]; then
    release=jammy
else
    release=$1
fi

sudo apt install sshpass uvtool -y

mkdir -p .ssh
if [ ! -e .ssh/id_rsa ]; then
	ssh-keygen -f .ssh/id_rsa -t rsa -N ''
else
        echo "ssh keys already exists"
fi


sudo uvt-simplestreams-libvirt query | grep $release
if [ $? -eq 0 ]; then
    echo "release found"
else
   sudo uvt-simplestreams-libvirt \
   --verbose sync --source http://cloud-images.ubuntu.com/daily \
   release=$release arch=amd64
fi

sudo uvt-kvm create $iscsi_target release=$release --disk 30 \
     --memory 2048 --cpu 2 --password $iscsi_password

sudo uvt-kvm create $iscsi_client release=$release --disk 30 \
     --memory 2048 --cpu 2 --password $iscsi_password

# wait for vm's to boot
echo "Waiting for vm's to boot..."
sleep $timeout

echo "Get IP addresses of target and client"
iscsi_target_ip_addr=`sudo uvt-kvm ip $iscsi_target`
iscsi_client_ip_addr=`sudo uvt-kvm ip $iscsi_client`


sshpass -p $iscsi_password ssh-copy-id -i $current_dir".ssh/id"_rsa.pub -o \
         StrictHostKeyChecking=no ubuntu@$iscsi_target_ip_addr

echo "wait for client to boot"
sleep $timeout

sshpass -p $iscsi_password ssh-copy-id -i $current_dir"ssh/id_rsa.pub" -o \
         StrictHostKeyChecking=no ubuntu@$iscsi_client_ip_addr

sshpass -p $iscsi_password scp -o 'StrictHostKeyChecking=no' \
        $iscsi_target_script_local ubuntu@$iscsi_target_ip_addr:/home/ubuntu/
sshpass -p $iscsi_password scp -o 'StrictHostKeyChecking=no' \
        $iscsi_client_script_local ubuntu@$iscsi_client_ip_addr:/home/ubuntu/

sshpass -p $iscsi_password ssh -o 'StrictHostKeyChecking=no' \
         ubuntu@$iscsi_target_ip_addr sudo ./$iscsi_target_script
sshpass -p $iscsi_password ssh -o 'StrictHostKeyChecking=no' \
         ubuntu@$iscsi_client_ip_addr sudo ./$iscsi_client_script $iscsi_target_ip_addr

sudo uvt-kvm destroy $iscsi_target 
sudo uvt-kvm destroy $iscsi_client
