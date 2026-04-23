##
# Copyright (C) IBM Inc. - All Rights Reserved
# 
# This source code is protected under international copyright law.  All rights
# reserved and protected by the copyright holders.
# This file is confidential and only available to authorized individuals with the
# permission of the copyright holders.  If you encounter this file and do not have
# permission, please contact the copyright holders and delete this file.
# 
# This software is provided as-is, without warranties of any kind. 
##

locals {
  workspace_id = var.schematics_workspace_id
}

data "ibm_schematics_workspace" "schematics_workspace" {
  
  workspace_id = local.workspace_id
}

/*
data "ibm_schematics_output" "output" {
  workspace_id = local.workspace_id
  template_id  = data.ibm_schematics_workspace.schematics_workspace.template_id.0
}
*/

data shell_script workspace_output_variables {
    lifecycle_commands {
        read = "/bin/bash getTFOutputs.sh ${local.workspace_id}"
    }
}

// validation of available slots for networking
data shell_script validate_pool_cidr_size {
    lifecycle_commands {
        read = "/usr/bin/python3 validatePoolCIDRSize.py ${length(local.worker_pool_ips)} ${local.worker_pool_size}"
    }
}

// validation for ad_join_password field against password protection coming from parent workspace

data "ibm_is_subnet" "symphony_subnet" {
  provider   = ibm.builder   # important in your setup
  identifier = local.symphony_subnet_id
}

locals {

    // New HPC Management offerings outputs all needed data to be consumed by this worker pool.
    // For the old HPC management offerings, the worker pool will look at input variables.
    output = data.shell_script.workspace_output_variables.output

    /**
    * Declared input variables in the HPC Management Schematics workspace
    */
    zone = try(try(local.output.zone, [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "zone" ][0]), "")

    // Region: calculated based on zone (needed for ibm builder provider)
    region = "${split("-", local.zone)[0]}-${split("-", local.zone)[1]}"

    cluster_prefix = try(try(local.output.cluster_prefix, [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "cluster_prefix" ][0]), "")
    tags = try(try(jsondecode(local.output.tags), jsondecode([for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "tags" ][0])), [])
    ssh_keys = try(try(local.output.ssh_keys, [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "ssh_keys" ][0]), "")

    symphony_cluster_info = try(
    try ( local.output.symphony_cluster_info, 
        try(
              [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "symphony_cluster_info" ][0],
              [for input in data.ibm_schematics_workspace.schematics_workspace.template_values_metadata : input.default if input.name == "symphony_cluster_info"][0]
            ),
        ),
    "")


    num_of_management_nodes = try(
        try(
        local.output.num_of_management_nodes,
        try(
            [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs :
            input.value if input.name == "num_of_management_nodes"][0],
            [for input in data.ibm_schematics_workspace.schematics_workspace.template_values_metadata :
            input.default if input.name == "num_of_management_nodes"][0]
        )
        ),
        ""
    )

    /*
    * Declared input variables in the HPC Managemeny Schematics workspace that can be overwritten by this workspace
    */
     symphony_compute_instance_profile = try([for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "symphony_compute_instance_profile" ][0], "")
     symphony_linux_image_name = try(try(local.output.symphony_image_name, [for input in data.ibm_schematics_workspace.schematics_workspace.template_inputs : input.value if input.name == "symphony_image_name" ][0]), "")
    

    // Computed grid-manager-prefix name (used to configure ego.conf on workers) - according to Citi conventions
    symphony_master_names = [
        for i in range(2) :
            "${local.cluster_prefix}-grid-man-${format("%02d", i+1)}"
        ]

    /*
    *  Output variables coming from HPC Management Schematics workspace (requires commit 7f45c3fa7c0d85e3bb02ccb2afeb8b5fd178046b in citi-hpc-offering to work)
    */
    workload_vpc_id = local.output.workload_vpc_id
    resource_group_id = local.output.resource_group_id
    private_dns_instance_id = local.output.private_dns_instance_id
    private_dns_zone_id = local.output.private_dns_zone_id
    dns_domain = try(module.dns_records[0].domain_name, "")
    ssh_key_ids = try(jsondecode(local.output.ssh_key_ids), [])
    cluster_name = "citi-${local.cluster_prefix}"

    /*
    *  Output that can be overwritten by this workspace
    */
    
    symphony_subnet_id = var.symphony_subnet_id != "" ? var.symphony_subnet_id : local.output.symphony_subnet_id
    symphony_subnet_cidr = data.ibm_is_subnet.symphony_subnet.ipv4_cidr_block
    symphony_worker_security_group = length(var.security_groups) > 0 ? flatten([for sg_name in var.security_groups : [for sg in module.security_groups.security_groups : sg.id if sg.name == sg_name]]) : try(jsondecode(local.output.symphony_worker_security_group), [])

    symphony_instance_profile = var.symphony_instance_profile != "" ? var.symphony_instance_profile : local.symphony_compute_instance_profile
    symphony_instance_image_id = var.symphony_instance_image_id != "" ? var.symphony_instance_image_id : local.symphony_linux_image_name

    // Worker pool size, name and IPs
    worker_pool_subnet_segmentation = var.worker_pool_subnet_segmentation
    worker_pool_size = var.worker_pool_size
    worker_pool_prefix = var.worker_pool_prefix
    worker_pool_start_number_at = var.worker_pool_start_at_number
    #worker_pool_ips = flatten([for subnet in local.worker_pool_subnet_segmentation : [for index in range(pow(2, 32 - split("/", subnet)[1])) : cidrhost(subnet, index)]])
    worker_pool_ips = flatten([for subnet in local.worker_pool_subnet_segmentation : [for index in range(local.worker_pool_size) : cidrhost(subnet, index + var.worker_ip_offset)]])
    worker_pool_name_prefix = local.worker_pool_prefix != "" ? local.worker_pool_prefix : "worker"
    worker_pool_worker_names = [for i in range(local.worker_pool_size) : "${local.cluster_prefix}-${local.worker_pool_name_prefix}-${format("%04d", i + local.worker_pool_start_number_at)}"]
    worker_pool_ip_name_mapping = {for idx in range(min(local.worker_pool_size, length(local.worker_pool_ips))) : local.worker_pool_ips[idx] => local.worker_pool_worker_names[idx]}

    // Worker pool type
    worker_pool_type = var.worker_pool_type
    idm_password = var.idm_password 

}

// Get all resource groups from the region
module security_groups {
    providers = {
        ibm = ibm.builder
    }

    source = "./modules/all-security-groups"
}

// Create DNS records
module dns_records {
    providers = {
        ibm = ibm.builder
    }
    depends_on=[data.shell_script.validate_pool_cidr_size]
    count = local.private_dns_instance_id != "" && local.private_dns_zone_id != "" ? 1 : 0
    source = "./modules/dns-entry"
    ibmcloud_api_key = var.ibmcloud_api_key
    private_dns_instance_id = local.private_dns_instance_id
    private_dns_zone_id = local.private_dns_zone_id
    machine_ip_name_mapping = local.worker_pool_ip_name_mapping
}


// Create shared workers
module shared_workers {
    providers = {
        ibm = ibm.builder
    }
    depends_on=[data.shell_script.validate_pool_cidr_size]
    source = "./modules/shared-worker"
    count = local.worker_pool_type == "shared" ? 1 : 0
    machine_ip_name_mapping = local.worker_pool_ip_name_mapping
    symphony_image_name = local.symphony_instance_image_id
    symphony_profile = local.symphony_instance_profile
    worker_tags = local.tags
    security_group_ids = local.symphony_worker_security_group
    zone = local.zone
    subnet_id_or_name = local.symphony_subnet_id
    resource_group_id = local.resource_group_id
    ssh_keys = local.ssh_key_ids
    vpc_id = local.workload_vpc_id
    cloud_init_script = templatefile("${path.module}/cloud-init/workers.tpl", {
        base64_zip    = filebase64("${path.module}/cloud-init/deployment-scripts.zip"),
        cluster_name = local.cluster_name,
        num_of_management_nodes = local.num_of_management_nodes,
        dns_domain = local.dns_domain,
        symphony_subnet_cidr = local.symphony_subnet_cidr,
        idm_password = var.idm_password
      })
}