# Validate that VLAN subnets have a cluster reference.
check "vlan_subnets_have_cluster" {
  assert {
    condition = alltrue([
      for k, v in var.subnets :
      v.subnet_type != "VLAN" || v.cluster_reference != null
    ])
    error_message = "VLAN subnets should have a 'cluster_reference' specified for proper placement."
  }
}

# Validate that overlay subnets belong to a VPC.
check "overlay_subnets_have_vpc" {
  assert {
    condition = alltrue([
      for k, v in var.subnets :
      v.subnet_type != "OVERLAY" || v.vpc_reference != null
    ])
    error_message = "OVERLAY subnets should have a 'vpc_reference' specified."
  }
}

# Validate that floating IPs have either an external subnet or VPC reference.
check "floating_ips_have_reference" {
  assert {
    condition = alltrue([
      for k, v in var.floating_ips :
      v.external_subnet_reference != null || v.vpc_reference != null
    ])
    error_message = "Floating IPs should have either 'external_subnet_reference' or 'vpc_reference' specified."
  }
}
