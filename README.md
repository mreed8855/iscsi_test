# iscsi_test
## Usage
### ./iscsi_vm_run.sh {jammy,focal}

This script does the following:

* Creates 2 virtual machines
* Copies an iscsi_target.sh script to the virtual machine called iscsi_target
* Copies an iscsi_client.sh script to the virual machine called iscsi_client
* Iscsi_target creates an iscsi target
* Iscsi_client creates and Iscsi client that logs into the iscsi target and runs a brief stress ng disk test
