locals {

  ##################################################
  # VPCs
  ##################################################



  ##################################################
  # Subnets
  ##################################################

  # The Nutanix API field is 'network_id', but for a VLAN subnet its value is
  # the 802.1Q VLAN tag, so 'vlan_id' is what callers actually mean. Both spell
  # the same field; variables.tf rejects disagreeing values, so either may win
  # here. OVERLAY subnets carry no network_id and resolve to null.
  subnet_network_ids = {
    for k, v in var.subnets : k => try(coalesce(v.vlan_id, v.network_id), null)
  }

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
