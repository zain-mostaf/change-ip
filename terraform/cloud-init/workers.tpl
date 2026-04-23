#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status
exec > /var/log/deployment-script.log 2>&1  # Redirect logs for debugging
export unzip_dir="/opt/symphony-scripts/nextgen"
export base64_input=${base64_zip}
export output_path="/opt/symphony-scripts/nextgen/deployment-script.zip"
export cluster_name=${cluster_name}
export num_of_management_nodes=${num_of_management_nodes}
export dns_domain=${dns_domain}
export symphony_subnet_cidr=${symphony_subnet_cidr}
export idm_password=${idm_password}

function copy_service_script {
  # Check and create directory if it doesn't exist
  if [ ! -d "$unzip_dir" ]; then
    echo "Directory does not exist. Creating..."
    if ! mkdir -p "$unzip_dir"; then
      echo "Error: Failed to create directory $unzip_dir" >&2
      exit 1
    fi
  fi

  # Decode the Base64 input and save to file
  if ! echo "$base64_input" | base64 -d > "$output_path"; then
    echo "Error: Failed to decode Base64 input." >&2
    exit 1
  fi

  # Check if unzip is installed, install if not
  if ! command -v unzip &> /dev/null; then
    echo "Unzip not found. Installing..."
    if ! yum install -y unzip; then
      echo "Error: Failed to install unzip. Please install it manually." >&2
      exit 1
    fi
  fi


  # Unzip the file
  echo "Unzipping the file..."
  if ! unzip -o "$output_path" -d "$unzip_dir"; then
    echo "Error: Failed to unzip file." >&2
    exit 1
  fi
}
copy_service_script
cd /opt/symphony-scripts/nextgen
chmod 755 *.sh
./worker.sh "${cluster_name}" "${num_of_management_nodes}" "${dns_domain}" "${symphony_subnet_cidr}" "${idm_password}"