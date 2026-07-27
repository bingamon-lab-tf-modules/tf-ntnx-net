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



  ##################################################
  # Discovery summaries
  #
  # The existing_* outputs used to return the raw data source objects. That put
  # every field of every discovered entity into module output — and therefore
  # into the state file and into every plan/apply log. For clusters in
  # particular that meant the full config tree: build info, node lists, and the
  # authorized SSH public key of every CVM and host, for both Prism Element and
  # Prism Central. The result was plan output that could not practically be
  # reviewed, a bloated remote state, and Prism Central's internal node topology
  # printed in the clear.
  #
  # These locals keep only what a caller can act on: the identity of each
  # discovered entity, plus the few fields needed to choose between them.
  # Anything else can be read back from Prism Central on demand.
  ##################################################

  existing_clusters_summary = [
    for c in try(data.nutanix_clusters_v2.clusters.cluster_entities, []) : {
      ext_id = c.ext_id
      name   = c.name
      # Which cluster can host a subnet: a PRISM_CENTRAL entity cannot, an AOS
      # one can. Kept because it is the field that decides placement.
      cluster_function = try(c.config[0].cluster_function, [])
    }
  ]

  existing_subnets_summary = [
    for s in try(data.nutanix_subnets_v2.existing_subnets.subnets, []) : {
      ext_id            = s.ext_id
      name              = s.name
      subnet_type       = s.subnet_type
      network_id        = s.network_id
      cluster_reference = s.cluster_reference
      vpc_reference     = s.vpc_reference
      is_external       = s.is_external
    }
  ]

  existing_vpcs_summary = [
    for v in try(data.nutanix_vpcs_v2.existing_vpcs.vpcs, []) : {
      ext_id      = v.ext_id
      name        = v.name
      description = v.description
      vpc_type    = v.vpc_type
    }
  ]

  existing_floating_ips_summary = [
    for f in try(data.nutanix_floating_ips_v2.existing_floating_ips.floating_ips, []) : {
      ext_id                    = f.ext_id
      name                      = f.name
      external_subnet_reference = f.external_subnet_reference
    }
  ]

  existing_network_functions_summary = var.enable_data_lookups ? [
    for n in try(data.nutanix_network_functions_v2.existing_network_functions[0].network_functions, []) : {
      ext_id = n.ext_id
      name   = n.name
    }
  ] : null
}
