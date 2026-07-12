##################################################
# Outputs
##################################################

output "vpcs" {
  description = "Created VPCs"
  value       = module.network.vpcs
}

output "vpc_ids" {
  description = "VPC external IDs"
  value       = module.network.vpc_ids
}

output "subnets" {
  description = "Created subnets"
  value       = module.network.subnets
}

output "subnet_ids" {
  description = "Subnet external IDs"
  value       = module.network.subnet_ids
}

output "floating_ips" {
  description = "Created floating IPs"
  value       = module.network.floating_ips
}

output "floating_ip_ids" {
  description = "Floating IP external IDs"
  value       = module.network.floating_ip_ids
}

output "routing_policies" {
  description = "Created routing policies"
  value       = module.network.routing_policies
}

output "routing_policy_ids" {
  description = "Routing policy external IDs"
  value       = module.network.routing_policy_ids
}

output "routes" {
  description = "Created routes"
  value       = module.network.routes
}

output "route_ids" {
  description = "Route external IDs"
  value       = module.network.route_ids
}
