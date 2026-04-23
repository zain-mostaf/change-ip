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
export domainName="$3"
#vpn
export CLUSTER_CIDR=$4


: === STARTING WORKER DEPLO
cleanup_log_files                   # common-all.sh  ====> done
update_nm_plugins                   # common-all.sh  ====> done    
update_nm_controlled                # common-all.sh  ====> done
update_dnsmasq_config               # common-all.sh  ====> done
update_dnsmasq_options              # common-all.sh  ====> done
configure_nm_dns                    # common-all.sh  ====> done
update_dhclient_conf                # common-all.sh  ====> done
update_nm_dhcp_client               # common-all.sh  ====> done
restart_networking                  # common-all.sh  ====> done
reinstall_idm_client                # common-all.sh  ====> done
check_data_dir                      # common-all.sh  ====> done
NFS_Storage_Mounted                 # common-all.sh  ====> done
config_hyperthreading               # common-worker.sh  ====> done
wait_for_candidate_hosts_norestart  # common-all.sh  ====> done
copy_sshkey                         # common-all.sh  ====> done
copy_sslkey                         # common-all.sh  ====> done
patch_image                         # common-all.sh  ====> done
config_symcompute                   # common-worker.sh  ====> done
start_ego                           # common-all.sh  ====> done
wait_for_management_hosts           # common-all.sh  ====> done
NFS_Storage_Unmounted               # common-all.sh  ====> done
: === WORKER DEPLOY FINISHED