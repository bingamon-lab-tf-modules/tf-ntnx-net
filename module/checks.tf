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
      v.subnet_type != "OVERLAY" || v.vpc_reference != null || v.vpc_key != null
    ])
    error_message = "OVERLAY subnets should have a 'vpc_key' or 'vpc_reference' specified."
  }
}

# A subnet's vpc_key must name a VPC this module manages.
#
# This lives here rather than as a validation on var.subnets deliberately:
# var.vpcs already validates against var.subnets (its external subnet_key), so
# a validation pointing back would make the two variables mutually dependent,
# which OpenTofu rejects outright as a cycle. A check block asserts the same
# condition without adding that edge.
check "overlay_subnet_vpc_keys_resolve" {
  assert {
    condition = alltrue([
      for k, v in var.subnets :
      v.vpc_key == null || contains(keys(var.vpcs), coalesce(v.vpc_key, ""))
    ])
    error_message = "A subnet's 'vpc_key' names a VPC that is not in var.vpcs."
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
