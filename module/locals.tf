locals {

  ##################################################
  # VPCs
  ##################################################

  # VPCs with external subnets
  vpcs_with_external_subnets = {
    for k, v in var.vpcs : k => v if length(v.external_subnets) > 0
  }

  # Transit VPCs
  transit_vpcs = { for k, v in var.vpcs : k => v if v.vpc_type == "TRANSIT" }

  ##################################################
  # Subnets
  ##################################################

  # VLAN subnets
  vlan_subnets = { for k, v in var.subnets : k => v if v.subnet_type == "VLAN" }

  # Overlay subnets
  overlay_subnets = { for k, v in var.subnets : k => v if v.subnet_type == "OVERLAY" }

  # External subnets
  external_subnets = { for k, v in var.subnets : k => v if v.is_external }

  # Subnets with IP configuration
  subnets_with_ip_config = { for k, v in var.subnets : k => v if v.ip_config != null }

  ##################################################
  # Floating IPs
  ##################################################

  # Floating IPs with VM NIC association
  floating_ips_with_vm_nic = {
    for k, v in var.floating_ips : k => v
    if v.association != null && v.association.vm_nic_association != null
  }

  # Floating IPs with private IP association
  floating_ips_with_private_ip = {
    for k, v in var.floating_ips : k => v
    if v.association != null && v.association.private_ip_association != null
  }
}
