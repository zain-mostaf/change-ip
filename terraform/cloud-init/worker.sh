##
##  Script to deploy a Symphony Worker.
##  The Symphony worker will be connected in a GPFS file system to read the shared ego.conf file.
##  Usage: worker.sh clusterID numberOfManagementHosts domain scaleManagerName internalClusterCIDR
##  Example: ./worker.sh wdcaz1-sym731 3 "us-south-1.hpc.citi.ibmcloud" wdcaz1-scale-cmpmgr-01 "172.200.128.0/21"
## ./worker.sh wdcaz1-sym731 3 "us-south-1.hpc.citi.ibmcloud" "172.200.128.0/21"

set +x 
echo "Importing modules..."

source "common-all.sh"
source "common-worker.sh"

set -x
#cluster ID should be 39 characters alphanumeric no spaces, supports -_.
export clusterID=$1
load_default_env_data #common-all.sh

#common =================
export enableSSL=N

export numExpectedManagementHosts=$2
# Option to use Private DNS
export domainName=".$3"
#vpn
export CLUSTER_CIDR=$4


: === STARTING WORKER DEPLO
check_data_dir
NM_configuration
NFS_Storage_Mounted
config_hyperthreading
wait_for_candidate_hosts_norestart
copy_sshkey
copy_sslkey
patch_image
config_symcompute
start_ego
wait_for_management_hosts
NFS_Storage_Unmounted
: === WORKER DEPLOY FINISHED
