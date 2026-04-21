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

variable ibmcloud_api_key {
    description = "IBM Cloud API Key to query and provision resources"
}

variable schematics_workspace_id {
    description = "ID of the HPC Management Schematics workspace. It is used to retrieve common information about the cluster (ex: VPC ID, DNS instance, etc)"
}

variable worker_pool_subnet_segmentation {
    type=list(string)
    description = "List of CIDRs to be used for worker IP assignment. It will limit the number of available spots for this worker pool."
}

variable worker_pool_size {
    type=number
    description="Quantity of workers to be provisioned into this worker pool. Maximum allowed is 512 workers."

    validation {
        condition = var.worker_pool_size <= 512
        error_message = "Maximum number of workers allowed per worker pool is 512."
    }
}

variable worker_pool_type {
    default="shared"
    description="Provision workers by using 'shared' VSIs, 'dedicated' hosts or 'baremetal'. Currently only 'shared' is implemented."

    validation {
        condition = var.worker_pool_type == "shared"
        error_message = "Only 'shared' is currently supported."
    }
}

variable worker_pool_prefix {
    default=""
    description="(Optional) Worker pool prefix to be added after cluster prefix (cluster prefix is captured from HPC management workspace). If informed, workers will be named by the following convention: <cluster_prefix>-<worker_prefix>-<counter>. If omitted, worker will follow the same naming convention from HPC management workspace (<cluster_prefix>-<(worker/wk)>-<counter>.)"
}
variable worker_pool_start_at_number {
    type=number
    default=1
    description="(Optional) Start counter for workers. This is useful when you want to keep the same cluster/worker prefix across worker pools."
}

variable symphony_subnet_id {
    default=""
    description="(Optional) ID or Name of an existent subnet where this worker pool will land. If omitted, the Symphony worker subnet set in the HPC Management workspace will be used."
}

variable symphony_instance_profile {
    default=""
    description="(Optional) Machine profile to use for this pool. If omitted, the Symphony worker profile used in the HPC Management workspace will be used."
}

variable symphony_instance_image_id {
    default=""
    description="(Optional) Imsge ID to be used by this worker pool. If omitted, the Symphony image ID used by HPC Management workspace will be used."
}

variable security_groups {
    type = list(string)
    default = []
    description = "(Optional) List of security group names to be added into this worker. If not informed, the list will be imported from the HPC management offering."
}



