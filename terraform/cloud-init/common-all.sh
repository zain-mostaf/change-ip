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

function cleanup_log_files {
    : === Starting cleanup_log_files - common-all.sh
    local paths=(
        "/opt/ibm/spectrumcomputing/kernel/log/*"
        "/opt/ibm/spectrumcomputing/eservice/wsg/log/*"
        "/opt/ibm/spectrumcomputing/eservice/esc/log/*"
        "/opt/ibm/spectrumcomputing/eservice/rs/log/*"
        "/opt/ibm/spectrumcomputing/soam/logs/*"
        "/opt/ibm/spectrumcomputing/gui/logs/*"
    )

    echo "Cleaning Spectrum Computing logs..."

    for path in "${paths[@]}"; do
        if compgen -G "$path" > /dev/null; then
            echo "Cleaning: $path"
            rm -f $path
        else
            echo "No files found in: $path"
        fi
    done

    echo "Log cleanup completed."
    : === Leaving cleanup_log_files - common-all.sh
}

function update_nm_plugins {
    : === Starting update_nm_plugins - worker.sh
    local file="/etc/NetworkManager/NetworkManager.conf"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    if grep -q '^plugins=ifcfg-rh' "$file"; then
        echo "plugins=ifcfg-rh already set. No changes needed."
    elif grep -q '^#plugins=ifcfg-rh' "$file"; then
        echo "Uncommenting plugins line..."
        sed -i 's/^#plugins=ifcfg-rh/plugins=ifcfg-rh/' "$file"
    else
        echo "plugins line not found. Adding it..."
        echo "plugins=ifcfg-rh" >> "$file"
    fi
    : === Leaving update_nm_plugins - worker.sh
}

function update_nm_controlled {
    : === Starting update_nm_controlled - worker.sh
    local dir="/etc/sysconfig/network-scripts"
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir"
        return 1
    fi

    for file in "$dir"/ifcfg-*; do
        [[ -f "$file" ]] || continue

        echo "Processing $file"

        if grep -q '^NM_CONTROLLED=yes' "$file"; then
            echo "  Already set to yes. No change."

        elif grep -q '^NM_CONTROLLED=no' "$file"; then
            echo "  Changing NM_CONTROLLED to yes..."
            sed -i 's/^NM_CONTROLLED=no/NM_CONTROLLED=yes/' "$file"

        else
            echo "  NM_CONTROLLED not found. Adding it..."
            printf "NM_CONTROLLED=yes\n" >> "$file"
        fi
    done
    : === Leaving update_nm_controlled - worker.sh
}

function update_dnsmasq_config {
    : === Starting update_dnsmasq_config - worker.sh
    
    local file="/etc/NetworkManager/conf.d/dns.conf"
    local dir
    dir=$(dirname "$file")

    # Ensure directory exists
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi

    if [[ -f "$file" ]]; then
        echo "File exists: $file"

        if grep -qi 'dnsmasq' "$file"; then
            echo "dnsmasq already configured. No changes needed."
        else
            echo "dnsmasq not found. Updating file..."
            # Ensure newline at end if needed
            [[ -s "$file" && -n $(tail -c1 "$file") ]] && echo >> "$file"
            printf "[main]\ndns=dnsmasq\n" >> "$file"
        fi
    else
        echo "File not found. Creating $file..."

        cat <<EOF > "$file"
[main]
dns=dnsmasq
EOF
    fi
    : === Leaving update_dnsmasq_config - worker.sh
}

function update_dnsmasq_options {
    : === Starting update_dnsmasq_options - worker.sh
    local file="/etc/NetworkManager/dnsmasq.d/01-DNS-configuration.conf"
    local dir
    dir=$(dirname "$file")

    # Required configuration block
    local content="domain-needed
bogus-priv
interface=lo
bind-interfaces
listen-address=127.0.0.1
cache-size=1000
no-poll
no-negcache

## Logging (optional for troubleshooting)
log-queries
log-facility=/var/log/dnsmasq.log"

    # Ensure directory exists
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi

    if [[ -f "$file" ]]; then
        echo "File exists: $file"

        # Check if ALL required lines exist
        local missing=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            grep -Fxq "$line" "$file" || missing=1
        done <<< "$content"

        if [[ $missing -eq 0 ]]; then
            echo "All required dnsmasq settings already exist. No change."
        else
            echo "Some settings are missing. Updating file..."
            # Ensure newline at end
            [[ -s "$file" && -n $(tail -c1 "$file") ]] && echo >> "$file"

            # Add only missing lines
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if ! grep -Fxq "$line" "$file"; then
                    echo "$line" >> "$file"
                fi
            done <<< "$content"
        fi
    else
        echo "File not found. Creating $file..."

        cat <<EOF > "$file"
$content
EOF
    fi
    : === Leaving update_dnsmasq_options - worker.sh
}

function configure_nm_dns {
    : === Starting configure_nm_dns - worker.sh
    local iface="eth0"
    local dns_servers="161.26.0.7 161.26.0.8"
    local dns_options="single-request-reopen,edns0"
    local dns_search_domain="$domainName"

    # Get connection name
    local conn
    conn=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v dev="$iface" '$2==dev {print $1}')

    if [[ -z "$conn" ]]; then
        echo "No active connection found for $iface"
        return 1
    fi

    echo "Using connection: $conn"

    # --- DNS servers ---
    current_dns=$(nmcli -g ipv4.dns con show "$conn")
    if [[ "$current_dns" == "$dns_servers" ]]; then
        echo "DNS servers already configured. No change."
    else
        echo "Setting DNS servers..."
        nmcli con mod "$conn" ipv4.dns "$dns_servers"
    fi

    # --- DNS search domain ---
    if [[ -n "$dns_search_domain" ]]; then
        current_search=$(nmcli -g ipv4.dns-search con show "$conn")
        if [[ "$current_search" == "$dns_search_domain" ]]; then
            echo "DNS search domain already configured. No change."
        else
            echo "Setting DNS search domain..."
            nmcli con mod "$conn" ipv4.dns-search "$dns_search_domain"
        fi
    else
        echo "domainName variable is empty. Skipping DNS search domain."
    fi

    # --- Ignore auto DNS ---
    current_ignore=$(nmcli -g ipv4.ignore-auto-dns con show "$conn")
    if [[ "$current_ignore" == "yes" ]]; then
        echo "ignore-auto-dns already set. No change."
    else
        echo "Disabling auto DNS..."
        nmcli con mod "$conn" ipv4.ignore-auto-dns yes
    fi

    # --- DNS options ---
    current_options=$(nmcli -g ipv4.dns-options con show "$conn")
    if [[ "$current_options" == "$dns_options" ]]; then
        echo "DNS options already configured. No change."
    else
        echo "Setting DNS options..."
        nmcli con mod "$conn" ipv4.dns-options "$dns_options"
    fi

    echo "DNS configuration completed."
    : === Leaving configure_nm_dns - worker.sh
}

function configure_mtu {
    : === Starting configure_mtu - worker.sh
    local iface="eth0"
    local desired_mtu="9000"

    # Get active connection name
    local conn
    conn=$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v dev="$iface" '$2==dev {print $1}')

    if [[ -z "$conn" ]]; then
        echo "No active connection found for $iface"
        return 1
    fi

    echo "Using connection: $conn"

    # Get current MTU
    local current_mtu
    current_mtu=$(nmcli -g 802-3-ethernet.mtu con show "$conn")

    # If empty, treat as default (1500 usually)
    current_mtu=${current_mtu:-1500}

    if [[ "$current_mtu" == "$desired_mtu" ]]; then
        echo "MTU already set to $desired_mtu. No change."
    else
        echo "Updating MTU to $desired_mtu..."
        nmcli con mod "$conn" 802-3-ethernet.mtu "$desired_mtu"
    fi
    : === Leaving configure_mtu - worker.sh
}

function update_dhclient_conf {
    : === Starting update_dhclient_conf - worker.sh
    local file="/etc/dhcp/dhclient.conf"

    # Required content
    local content="timeout 0;
retry 0;
supersede dhcp-lease-time 4294967295;
supersede dhcp-renewal-time 4294967295;
supersede dhcp-rebinding-time 4294967295;"

    if [[ -f "$file" ]]; then
        echo "File exists: $file"

        local missing=0

        # Check if all lines exist
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            grep -Fxq "$line" "$file" || missing=1
        done <<< "$content"

        if [[ $missing -eq 0 ]]; then
            echo "All DHCP settings already exist. No change."
        else
            echo "Some settings are missing. Updating file..."
            # Ensure newline at end
            [[ -s "$file" && -n $(tail -c1 "$file") ]] && echo >> "$file"

            # Add only missing lines
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if ! grep -Fxq "$line" "$file"; then
                    echo "$line" >> "$file"
                fi
            done <<< "$content"
        fi
    else
        echo "File not found. Creating $file..."

        cat <<EOF > "$file"
$content
EOF
    fi
    : === Leaving update_dhclient_conf - worker.sh
}
function update_nm_dhcp_client {
    : === Starting update_nm_dhcp_client - worker.sh
    local file="/etc/NetworkManager/conf.d/10-dhcp-client.conf"
    local dir
    dir=$(dirname "$file")

    local content="[main]
dhcp=dhclient"

    # Ensure directory exists
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi

    if [[ -f "$file" ]]; then
        echo "File exists: $file"

        if grep -qi 'dhclient' "$file"; then
            echo "dhclient already configured. No change."
        else
            echo "dhclient not found. Updating file..."
            # Ensure newline at end if needed
            [[ -s "$file" && -n $(tail -c1 "$file") ]] && echo >> "$file"

            printf "%s\n" "$content" >> "$file"
        fi
    else
        echo "File not found. Creating $file..."

        cat <<EOF > "$file"
$content
EOF
    fi
    : === Leaving update_nm_dhcp_client - worker.sh
}

function restart_networking {
    : === Starting restart_networking - worker.sh
    echo "Restarting NetworkManager service..."

    if systemctl restart NetworkManager; then
        echo "NetworkManager restarted successfully."
    else
        echo "Failed to restart NetworkManager"
        return 1
    fi

    echo "Reactivating all network connections..."

    # Get all connection names
    nmcli -t -f NAME con show | while IFS= read -r conn; do
        [[ -z "$conn" ]] && continue

        echo "Bringing up connection: $conn"
        nmcli con up "$conn" >/dev/null 2>&1
    done

    echo "Network restart and interface reactivation completed."
    : === Leaving restart_networking - worker.sh
}

function update_resolv_conf {
    : === Starting update_resolv_conf - worker.sh
    local file="/etc/resolv.conf"
    local search_line="search $domainName"
    local ns_line="nameserver 127.0.0.1"

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    echo "Checking $file"

    # --- Search domain ---
    if grep -Fxq "$search_line" "$file"; then
        echo "Search domain already set. No change."
    else
        echo "Updating search domain..."

        if grep -q '^search ' "$file"; then
            sed -i "s/^search .*/$search_line/" "$file"
        else
            printf "%s\n" "$search_line" >> "$file"
        fi
    fi

    # --- Nameserver ---
    if grep -Fxq "$ns_line" "$file"; then
        echo "Nameserver already set. No change."
    else
        echo "Updating nameserver..."

        if grep -q '^nameserver ' "$file"; then
            sed -i "s/^nameserver .*/$ns_line/" "$file"
        else
            printf "%s\n" "$ns_line" >> "$file"
        fi
    fi

    echo "resolv.conf update completed."
    : === Stopping update_resolv_conf - worker.sh
}

function reinstall_idm_client {
    : === Starting reinstall_idm_client - worker.sh
    #local servers=("$server1" "$server2" "$server3")
    #Local server="idm-01-ldap.common.citi.ibmcloud"
    local realm="CITI.COM"
    local domain="citi.com"
    local ntp_server="time.adn.networklayer.com"

    # --- Step 1: Uninstall (ignore errors if not installed) ---
    echo "Uninstalling existing IdM client (if any)..."
    ipa-client-install --uninstall -U >/dev/null 2>&1 || true

    # --- Step 2: DNS validation ---
    echo "Validating DNS resolution for IdM servers..."

    for srv in "${servers[@]}"; do
        [[ -z "$srv" ]] && continue

        if nslookup "$srv" >/dev/null 2>&1; then
            echo "  $srv resolved successfully"
        else
            echo "  ERROR: Cannot resolve $srv"
            return 1
        fi
    done

    # --- Step 3: Install IdM client ---
    echo "Installing IdM client..."

    ipa-client-install \
        --realm="$realm" \
        --domain="$domain" \
        --server=idm-01-ldap.common.citi.ibmcloud \
        --principal=admin \
        --password="$idm_password" \
        --ntp-server="$ntp_server" \
        --mkhomedir \
        --unattended \
        --force

    if [[ $? -eq 0 ]]; then
        echo "IdM client installed successfully."
    else
        echo "IdM client installation failed."
        return 1
    fi
    : === Leaving reinstall_idm_client - worker.sh
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

function NFS_Storage_Unmounted 
{
    : === Starting NFS_Storage_Unmounted common-all.sh
    echo "y" | egosh ego shutdown
    cp -f  /opt/symphony-scripts/data/*   ${EGO_TOP}/kernel/conf/
    sed -i '/fsf-tor0551a-byok-fz.adn.networklayer.com:\/4ff2e321_f8bf_4531_8a8b_ec2414712ad8/d' /etc/fstab
    umount /data
    df -h
    sleep 20
    : === Leaving NFS_Storage_Unmounted common-all.sh
}

