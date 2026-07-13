##################################################
# Complete Example - tf-ntnx-net
##################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = ">= 2.4.2"
    }
  }
}

provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
  insecure = var.nutanix_insecure
}

module "network" {
  source = "../../module"

  # VPCs
  vpcs = var.vpcs

  # Subnets (VLAN and Overlay)
  subnets = var.subnets

  # Floating IPs
  floating_ips = var.floating_ips

  # Routing Policies (PBR)
  routing_policies = var.routing_policies

  # Routes
  routes = var.routes
}
