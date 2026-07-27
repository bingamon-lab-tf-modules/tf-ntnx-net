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

  # Everything that is NOT an overlay: VLAN subnets, including external ones.
  #
  # These are split across two resource blocks on purpose. A VPC references its
  # external subnet, and an overlay subnet references its VPC. With a single
  # nutanix_subnet_v2 block those two references point at the same resource
  # node in opposite directions, which is a graph cycle — so key-based
  # resolution could only ever work in one direction. Splitting gives a linear
  # dependency chain instead:
  #
  #   nutanix_subnet_v2.subnet  ->  nutanix_vpc_v2.vpc  ->  nutanix_subnet_v2.overlay_subnet
  #        (external)                   (subnet_key)              (vpc_key)
  #
  # so a VPC and the overlay subnets inside it can be created in ONE apply.
  non_overlay_subnets = { for k, v in var.subnets : k => v if v.subnet_type != "OVERLAY" }

  # External subnets
  external_subnets = { for k, v in var.subnets : k => v if v.is_external }

  # Every subnet this module manages, across both resource blocks, in one map.
  # Callers should not have to know about the split — that is an internal
  # dependency-graph concern. Keys cannot collide: the two for_each maps
  # partition var.subnets on subnet_type.
  all_managed_subnets = merge(
    {
      for k, v in nutanix_subnet_v2.subnet : k => {
        ext_id            = v.ext_id
        name              = v.name
        subnet_type       = v.subnet_type
        network_id        = v.network_id
        cluster_reference = v.cluster_reference
        vpc_reference     = v.vpc_reference
        is_external       = v.is_external
      }
    },
    {
      for k, v in nutanix_subnet_v2.overlay_subnet : k => {
        ext_id            = v.ext_id
        name              = v.name
        subnet_type       = v.subnet_type
        network_id        = v.network_id
        cluster_reference = v.cluster_reference
        vpc_reference     = v.vpc_reference
        is_external       = v.is_external
      }
    },
  )



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

  # Each summary is built as a map keyed by ext_id and then flattened back to a
  # list. That is not decoration: the Prism APIs do not guarantee a stable
  # ordering, so returning the raw order made every plan show a spurious
  # "Changes to Outputs" diff — the same entities shuffled between indices,
  # rendered by OpenTofu as element-wise changes plus an add and a remove.
  # Terraform iterates map keys in lexical order, so keying by ext_id makes the
  # output deterministic and the diff disappears unless something really changed.

  existing_clusters_summary = [
    for _k, v in {
      for c in try(data.nutanix_clusters_v2.clusters.cluster_entities, []) : c.ext_id => {
        ext_id = c.ext_id
        name   = c.name
        # Which cluster can host a subnet: a PRISM_CENTRAL entity cannot, an AOS
        # one can. Kept because it is the field that decides placement.
        cluster_function = try(c.config[0].cluster_function, [])
      }
    } : v
  ]

  existing_subnets_summary = [
    for _k, v in {
      for s in try(data.nutanix_subnets_v2.existing_subnets.subnets, []) : s.ext_id => {
        ext_id            = s.ext_id
        name              = s.name
        subnet_type       = s.subnet_type
        network_id        = s.network_id
        cluster_reference = s.cluster_reference
        vpc_reference     = s.vpc_reference
        is_external       = s.is_external
      }
    } : v
  ]

  existing_vpcs_summary = [
    for _k, v in {
      for x in try(data.nutanix_vpcs_v2.existing_vpcs.vpcs, []) : x.ext_id => {
        ext_id      = x.ext_id
        name        = x.name
        description = x.description
        vpc_type    = x.vpc_type
      }
    } : v
  ]

  existing_floating_ips_summary = [
    for _k, v in {
      for f in try(data.nutanix_floating_ips_v2.existing_floating_ips.floating_ips, []) : f.ext_id => {
        ext_id                    = f.ext_id
        name                      = f.name
        external_subnet_reference = f.external_subnet_reference
      }
    } : v
  ]

  existing_network_functions_summary = var.enable_data_lookups ? [
    for _k, v in {
      for n in try(data.nutanix_network_functions_v2.existing_network_functions[0].network_functions, []) : n.ext_id => {
        ext_id = n.ext_id
        name   = n.name
      }
    } : v
  ] : null
}
