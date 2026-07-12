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

# Validate that every network function nic pair carries the ingress chain reference
# required for service chaining / traffic steering.
check "network_functions_have_chain_references" {
  assert {
    condition = alltrue([
      for k, v in var.network_functions : alltrue([
        for p in v.nic_pairs :
        p.ingress_nic_reference != null && p.ingress_nic_reference != ""
      ])
    ])
    error_message = "Network functions should reference an 'ingress_nic_reference' on every nic pair for service chaining."
  }
}
