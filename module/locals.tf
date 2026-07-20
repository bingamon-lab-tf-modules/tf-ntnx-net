locals {

  ##################################################
  # VPCs
  ##################################################



  ##################################################
  # Subnets
  ##################################################

  # VLAN subnets
  vlan_subnets = { for k, v in var.subnets : k => v if v.subnet_type == "VLAN" }

  # Overlay subnets
  overlay_subnets = { for k, v in var.subnets : k => v if v.subnet_type == "OVERLAY" }

  # External subnets
  external_subnets = { for k, v in var.subnets : k => v if v.is_external }



  ##################################################
  # Floating IPs
  ##################################################



}
