##################################################
# VPC Outputs
##################################################

output "vpcs" {
  description = "Map of created VPCs with their details."
  value = {
    for k, v in nutanix_vpc_v2.vpc : k => {
      ext_id      = v.ext_id
      name        = v.name
      description = v.description
      vpc_type    = v.vpc_type
    }
  }
}

output "vpc_ids" {
  description = "Map of VPC keys to their external IDs."
  value       = { for k, v in nutanix_vpc_v2.vpc : k => v.ext_id }
}

##################################################
# Subnet Outputs
##################################################

# Subnets live in two resource blocks (see locals: non_overlay_subnets), so
# every subnet-shaped output merges both. Keys cannot collide: the two for_each
# maps partition var.subnets on subnet_type.
output "subnets" {
  description = "Map of created subnets with their details, VLAN and OVERLAY alike."
  value       = local.all_managed_subnets
}

output "subnet_ids" {
  description = "Map of subnet keys to their external IDs, VLAN and OVERLAY alike."
  value       = { for k, v in local.all_managed_subnets : k => v.ext_id }
}

##################################################
# Floating IP Outputs
##################################################

output "floating_ips" {
  description = "Map of created floating IPs with their details."
  value = {
    for k, v in nutanix_floating_ip_v2.floating_ip : k => {
      ext_id                    = v.ext_id
      name                      = v.name
      external_subnet_reference = v.external_subnet_reference
    }
  }
}

output "floating_ip_ids" {
  description = "Map of floating IP keys to their external IDs."
  value       = { for k, v in nutanix_floating_ip_v2.floating_ip : k => v.ext_id }
}

##################################################
# Routing Policy Outputs
##################################################

output "routing_policies" {
  description = "Map of created routing policies with their details."
  value = {
    for k, v in nutanix_pbr_v2.routing_policy : k => {
      ext_id     = v.ext_id
      name       = v.name
      vpc_ext_id = v.vpc_ext_id
      priority   = v.priority
    }
  }
}

output "routing_policy_ids" {
  description = "Map of routing policy keys to their external IDs."
  value       = { for k, v in nutanix_pbr_v2.routing_policy : k => v.ext_id }
}

##################################################
# Route Outputs
##################################################

output "routes" {
  description = "Map of created routes with their details."
  value = {
    for k, v in nutanix_routes_v2.route : k => {
      ext_id             = v.ext_id
      name               = v.name
      route_table_ext_id = v.route_table_ext_id
      route_type         = v.route_type
    }
  }
}

output "route_ids" {
  description = "Map of route keys to their external IDs."
  value       = { for k, v in nutanix_routes_v2.route : k => v.ext_id }
}

##################################################
# Network Function Outputs
##################################################

output "network_functions" {
  description = "Map of created network functions with their details."
  value = {
    for k, v in nutanix_network_function_v2.network_function : k => {
      ext_id                  = v.ext_id
      name                    = v.name
      high_availability_mode  = v.high_availability_mode
      traffic_forwarding_mode = v.traffic_forwarding_mode
      failure_handling        = v.failure_handling
    }
  }
}

output "network_function_ids" {
  description = "Map of network function keys to their external IDs."
  value       = { for k, v in nutanix_network_function_v2.network_function : k => v.ext_id }
}

##################################################
# Discovery Outputs (Existing Resources)
##################################################

# NOTE: these return a SUMMARY of each discovered entity (identity plus the
# fields needed to choose between them), not the raw data source. See the
# rationale on the discovery summary locals — returning the raw objects put every
# CVM and host SSH public key, and Prism Central's node topology, into state and
# into every plan log.

output "existing_vpcs" {
  description = "Existing VPCs discovered in the target Prism Central: ext_id, name, description, vpc_type."
  value       = local.existing_vpcs_summary
}

output "existing_subnets" {
  description = "Existing subnets discovered in the target Prism Central: ext_id, name, subnet_type, network_id, cluster_reference, vpc_reference, is_external."
  value       = local.existing_subnets_summary
}

output "existing_floating_ips" {
  description = "Existing floating IPs discovered in the target Prism Central: ext_id, name, external_subnet_reference."
  value       = local.existing_floating_ips_summary
}

output "existing_clusters" {
  description = "Existing clusters available for subnet placement: ext_id, name, cluster_function. A PRISM_CENTRAL cluster cannot host a subnet; an AOS one can."
  value       = local.existing_clusters_summary
}

output "existing_network_functions" {
  description = "Existing network functions discovered in the target Prism Central: ext_id, name. Null unless enable_data_lookups is true."
  value       = local.existing_network_functions_summary
}

##################################################
# Summary
##################################################

output "network_summary" {
  description = "Summary of networking resources managed by this module."
  value = {
    total_vpcs              = length(var.vpcs)
    total_subnets           = length(var.subnets)
    total_floating_ips      = length(var.floating_ips)
    total_routing_policies  = length(var.routing_policies)
    total_routes            = length(var.routes)
    total_network_functions = length(var.network_functions)
    vlan_subnets            = length(local.vlan_subnets)
    overlay_subnets         = length(local.overlay_subnets)
    external_subnets        = length(local.external_subnets)
  }
}

##################################################
# Aggregate Output (spec §7.6 contract)
##################################################

output "outputs" {
  description = "Aggregate of all module outputs (spec §7.6 contract, consumed by the landing zone as module.<x>.outputs)."
  value = {
    vpcs = {
      for k, v in nutanix_vpc_v2.vpc : k => {
        ext_id      = v.ext_id
        name        = v.name
        description = v.description
        vpc_type    = v.vpc_type
      }
    }
    vpc_ids    = { for k, v in nutanix_vpc_v2.vpc : k => v.ext_id }
    subnets    = local.all_managed_subnets
    subnet_ids = { for k, v in local.all_managed_subnets : k => v.ext_id }
    floating_ips = {
      for k, v in nutanix_floating_ip_v2.floating_ip : k => {
        ext_id                    = v.ext_id
        name                      = v.name
        external_subnet_reference = v.external_subnet_reference
      }
    }
    floating_ip_ids = { for k, v in nutanix_floating_ip_v2.floating_ip : k => v.ext_id }
    routing_policies = {
      for k, v in nutanix_pbr_v2.routing_policy : k => {
        ext_id     = v.ext_id
        name       = v.name
        vpc_ext_id = v.vpc_ext_id
        priority   = v.priority
      }
    }
    routing_policy_ids = { for k, v in nutanix_pbr_v2.routing_policy : k => v.ext_id }
    routes = {
      for k, v in nutanix_routes_v2.route : k => {
        ext_id             = v.ext_id
        name               = v.name
        route_table_ext_id = v.route_table_ext_id
        route_type         = v.route_type
      }
    }
    route_ids = { for k, v in nutanix_routes_v2.route : k => v.ext_id }
    network_functions = {
      for k, v in nutanix_network_function_v2.network_function : k => {
        ext_id                  = v.ext_id
        name                    = v.name
        high_availability_mode  = v.high_availability_mode
        traffic_forwarding_mode = v.traffic_forwarding_mode
        failure_handling        = v.failure_handling
      }
    }
    network_function_ids = { for k, v in nutanix_network_function_v2.network_function : k => v.ext_id }
    # Summaries, not the raw data sources — see the discovery summary locals.
    existing_vpcs              = local.existing_vpcs_summary
    existing_subnets           = local.existing_subnets_summary
    existing_floating_ips      = local.existing_floating_ips_summary
    existing_clusters          = local.existing_clusters_summary
    existing_network_functions = local.existing_network_functions_summary
    network_summary = {
      total_vpcs              = length(var.vpcs)
      total_subnets           = length(var.subnets)
      total_floating_ips      = length(var.floating_ips)
      total_routing_policies  = length(var.routing_policies)
      total_routes            = length(var.routes)
      total_network_functions = length(var.network_functions)
      vlan_subnets            = length(local.vlan_subnets)
      overlay_subnets         = length(local.overlay_subnets)
      external_subnets        = length(local.external_subnets)
    }
  }
}
