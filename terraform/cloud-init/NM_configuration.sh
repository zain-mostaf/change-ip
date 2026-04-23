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
    : === Stopping update_nm_plugins - worker.sh
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
    : === Stopping update_nm_controlled - worker.sh
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
    : === Stopping update_dnsmasq_config - worker.sh
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

            # Backup
            cp "$file" "${file}.bak"

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
    : === Stopping update_dnsmasq_options - worker.sh
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
    : === Stopping configure_nm_dns - worker.sh
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

    # Backup before change
    cp "$file" "${file}.bak"

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
    : === Stopping configure_mtu - worker.sh
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

            # Backup
            cp "$file" "${file}.bak"

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
    : === Stopping update_dhclient_conf - worker.sh
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

            # Backup
            cp "$file" "${file}.bak"

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
    : === Stopping update_nm_dhcp_client - worker.sh
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
    : === Stopping restart_networking - worker.sh
}