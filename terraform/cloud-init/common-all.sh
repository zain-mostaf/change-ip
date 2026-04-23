##
##  Common Functions used by Symphony provisioning
##

function load_default_env_data {
    : === Starting load_default_env_data - common-all.sh
#primary specific ===============
export entitlementLine1="ego_base   3.9   ()   ()   ()   ()   0dd01a5e74fa2cf2851965cf64b1166f242e7843"
export entitlementLine2="sym_advanced_edition   7.3.1   ()   ()   ()   ()   21402f8aebf693f45c9e5a1c595435134be80845"

#password should be 8 to 15 characters
set +x
export adminPswd=Admin
set -x
export guestPswd=Guest

#internal
export CLUSTERADMIN=egoadmin
export EGO_TOP=/opt/ibm/spectrumcomputing
export SHARED_TOP=/data
export SHARED_TOP_CLUSTERID=${SHARED_TOP}/${clusterID}
export SHARED_TOP_SYM=${SHARED_TOP_CLUSTERID}/sym731
export HOSTS_FILES=${SHARED_TOP_CLUSTERID}/hosts
export LOCK_FILE=${SHARED_TOP_CLUSTERID}/lock
#ensure DONE file does not exist before starting
export DONE_FILE=${SHARED_TOP_CLUSTERID}/done
export HOST_NAME=`hostname`
export HOST_IP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
export DELAY=15
export STARTUP_DELAY=1
export ENTITLEMENT_FILE=$EGO_TOP/kernel/conf/sym_adv_entitlement.dat
export EGO_HOSTS_FILE=${SHARED_TOP_SYM}/kernel/conf/hosts
export SHARED_EGO_CONF_FILE=${SHARED_TOP_SYM}/kernel/conf/ego.conf
export IBM_CLOUD_PROVIDER_SCRIPTS=hostfactory/1.1/providerplugins/ibmcloudgen2/samplepostprovision/sym
export IBM_CLOUD_PROVIDER_PP_SCRIPT=${EGO_TOP}/${IBM_CLOUD_PROVIDER_SCRIPTS}/post_installgen2.sh
export IBM_CLOUD_PROVIDER_SHARED_PP_SCRIPT=${SHARED_TOP_SYM}/${IBM_CLOUD_PROVIDER_SCRIPTS}/post_installgen2.sh
export IBM_CLOUD_PROVIDER_WORK=work/providers/ibmcloudgen2inst

    : === Leaving load_default_env_data - common-all.sh
}

function check_data_dir {
    : === Starting check_data_dir common-all.sh
   dirName=/data
   if test -d "$dirName"
   then
     echo "directory is already existing"
   else
     mkdir /data
   fi
   : === Leaving check_data_dir common-all.sh
}

function NFS_Storage_Mounted {
    : === Starting NFS_Storage_Mounted common-all.sh
	# Add the NFS mount entry to /etc/fstab
	echo "172.200.250.8:/109650d7_f65d_40ff_ac6b_5527596af85e /data nfs4 nfsvers=4.1,sec=sys,_netdev 0 0" >> /etc/fstab

	# Reload the systemd daemon, mount all filesystems, and display disk usage
	systemctl daemon-reload
    systemctl restart remote-fs.target
    mount -a
    df -h | grep -q "/data"
    : === Leaving NFS_Storage_Mounted common-all.sh
}


function patch_image {
    : === Starting patch_image common-all.sh

    local file="/etc/sysctl.conf"
    local key="net.ipv4.tcp_max_syn_backlog"
    local value="65536"
    local line="$key = $value"

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    echo "Processing $file"

    # Count existing occurrences (ignoring comments)
    local count
    count=$(grep -E "^\s*$key\s*=" "$file" | wc -l)

    if [[ "$count" -eq 1 ]] && grep -Fxq "$line" "$file"; then
        echo "Correct value already set. No change."
        return 0
    fi

    echo "Updating $key..."

    # Backup
    cp "$file" "${file}.bak"

    # Remove all existing entries for the key
    sed -i "/^\s*$key\s*=/d" "$file"

    # Ensure newline at end
    [[ -s "$file" && -n $(tail -c1 "$file") ]] && echo >> "$file"

    # Add correct line once
    echo "$line" >> "$file"

    echo "$key configured successfully."
    rm -f /root/preconfig.sh
    : === Leaving patch_image common-all.sh
}


function start_ego
{
    : === Starting start_ego common-all.sh
    echo "source ${EGO_TOP}/profile.platform" >> /root/.bashrc
    sleep $STARTUP_DELAY
    systemctl start ego
    : === Leaving start_ego common-all.sh
}


function wait_for_management_hosts
{
    # wait for all management hosts to report their IP address
    : === Starting wait_for_management_hosts common-all.sh
    CURRENT_HOSTS=0
    while (( CURRENT_HOSTS < numExpectedManagementHosts ))
    do
        sleep $DELAY
        sleep $(($RANDOM%5))
        if [ "${egoHostRole}" == "compute" ]; then
            echo "${HOST_IP} ${HOST_NAME}${domainName} ${HOST_NAME}" > /tmp/hosts
        fi
        cat ${HOSTS_FILES}/* >> /tmp/hosts
        CURRENT_HOSTS=`wc -l < /tmp/hosts`
        rm -f /tmp/hosts
    done
    : === Leaving wait_for_management_hosts common-all.sh
}

function copy_sshkey
{
    : === Starting copy_sshkey common-all.sh
    mkdir -p /root/.ssh
    cat ${SHARED_TOP_CLUSTERID}/root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    cp ${SHARED_TOP_CLUSTERID}/root/.ssh/id_rsa /root/.ssh/.
    : === Leaving copy_sshkey common-all.sh
}

function copy_sslkey
{
     : === Starting copy_sslkey common-all.sh
    # Share CA Certificate
    cp -f ${SHARED_TOP_SYM}/security/* ${EGO_TOP}/wlp/usr/shared/resources/security/.
     : === Leaving copy_sslkey common-all.sh
}

function wait_for_candidate_hosts_norestart
{
    # wait for all candidate hosts to update MASTERS_LIST
    : === Starting wait_for_candidate_hosts_norestart common-all.sh
    CURRENT_HOSTS=0
    EXPECTED_PRIMARY_HOSTS=1
    if (( numExpectedManagementHosts > 1 )); then
        EXPECTED_PRIMARY_HOSTS=2
    fi

    export EGO_MASTER_LIST=`gawk -F= '/EGO_MASTER_LIST/{print $2}' ${SHARED_EGO_CONF_FILE} | tr -d \"`
    while (( CURRENT_HOSTS < EXPECTED_PRIMARY_HOSTS ))
    do
        sleep $DELAY
        sleep $(($RANDOM%5))
        # if candidate list changed need to restart ego
        NEW_EGO_MASTERS_LIST=`gawk -F= '/EGO_MASTER_LIST/{print $2}' ${SHARED_EGO_CONF_FILE} | tr -d \"`
        if [ "${NEW_EGO_MASTERS_LIST}" != "${EGO_MASTERS_LIST}" ]; then
            echo "New candidate joined"
            EGO_MASTERS_LIST=${NEW_EGO_MASTERS_LIST}
        fi
        words=( $EGO_MASTERS_LIST )
        CURRENT_HOSTS=${#words[@]}
    done
    : === Leaving wait_for_candidate_hosts_norestart common-all.sh
}

function NFS_Storage_Unmounted 
{
    : === Starting NFS_Storage_Unmounted common-all.sh
    echo "y" | egosh ego shutdown
    cp -f  /opt/symphony-scripts/data/*   ${EGO_TOP}/kernel/conf/
    sed -i '/fsf-tor0551a-byok-fz.adn.networklayer.com:\/4ff2e321_f8bf_4531_8a8b_ec2414712ad8/d' /etc/fstab
    umount /opt/data
    df -h
    sleep 20
    : === Leaving NFS_Storage_Unmounted common-all.sh
}

