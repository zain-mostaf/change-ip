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

# output ego_conf {
#     value = module.cloud_init_scripts.parsed_ego_conf
# }

# output "dns_domain_debug" {
#   value = local.dns_domain
# }


# output "debug_workspace_output" {
#   value = local.output
# }

output "symphony_cluster_info" {
  value = local.symphony_cluster_info
}

output "num_of_management_nodes" {
  value = local.num_of_management_nodes
}

output "symphony_subnet_id" {
  value = local.symphony_subnet_id
}

output "cluster_prefix" {
  value = local.cluster_prefix
}

output "cluster_name" {
  value = local.cluster_name
}