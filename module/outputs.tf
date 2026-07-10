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

output "subnets" {
  description = "Map of created subnets with their details."
  value = {
    for k, v in nutanix_subnet_v2.subnet : k => {
      ext_id            = v.ext_id
      name              = v.name
      subnet_type       = v.subnet_type
      network_id        = v.network_id
      cluster_reference = v.cluster_reference
      vpc_reference     = v.vpc_reference
      is_external       = v.is_external
    }
  }
}

output "subnet_ids" {
  description = "Map of subnet keys to their external IDs."
  value       = { for k, v in nutanix_subnet_v2.subnet : k => v.ext_id }
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
# Discovery Outputs (Existing Resources)
##################################################

output "existing_vpcs" {
  description = "Existing VPCs discovered in the target Prism Central."
  value       = data.nutanix_vpcs_v2.existing_vpcs
}

output "existing_subnets" {
  description = "Existing subnets discovered in the target Prism Central."
  value       = data.nutanix_subnets_v2.existing_subnets
}

output "existing_floating_ips" {
  description = "Existing floating IPs discovered in the target Prism Central."
  value       = data.nutanix_floating_ips_v2.existing_floating_ips
}

output "existing_clusters" {
  description = "Existing clusters available for subnet placement."
  value       = data.nutanix_clusters_v2.clusters
}

##################################################
# Summary
##################################################

output "network_summary" {
  description = "Summary of networking resources managed by this module."
  value = {
    total_vpcs             = length(var.vpcs)
    total_subnets          = length(var.subnets)
    total_floating_ips     = length(var.floating_ips)
    total_routing_policies = length(var.routing_policies)
    total_routes           = length(var.routes)
    vlan_subnets           = length(local.vlan_subnets)
    overlay_subnets        = length(local.overlay_subnets)
    external_subnets       = length(local.external_subnets)
  }
}
