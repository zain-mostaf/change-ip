## 
## Common functions for workers
##


function config_hyperthreading
{
    : === Starting config_hyperthreading - common-worker.sh
    if ! $hyperthreading; then
    for vcpu in `cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq`; do
        echo 0 > /sys/devices/system/cpu/cpu$vcpu/online
    done
    fi
    : === Leaving config_hyperthreading - common-worker.sh
}

function config_symcompute
{
    : === Starting config_symcompute - common-worker.sh
    source ${EGO_TOP}/profile.platform
    #parse shared ego.conf for primary master
    export EGO_MASTER_LIST=`gawk -F= '/EGO_MASTER_LIST/{print $2}' ${SHARED_EGO_CONF_FILE} | tr -d \"`
    export PRIMARY_MASTER=`echo $EGO_MASTER_LIST | cut -d' ' -f1`

    egosetsudoers.sh
    egosetrc.sh
    su ${CLUSTERADMIN} -c 'egoconfig join ${PRIMARY_MASTER} -f'
    su ${CLUSTERADMIN} -c 'egoconfig addresourceattr "[resourcemap ibmcloud*cloudprovider] [resource corehoursaudit]"'
    : === Leaving config_symcompute - common-worker.sh
}