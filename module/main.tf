##################################################
# VPCs
##################################################

resource "nutanix_vpc_v2" "vpc" {
  for_each = var.vpcs

  name        = each.value.name
  description = each.value.description
  vpc_type    = each.value.vpc_type

  external_routing_domain_reference = each.value.external_routing_domain_reference

  dynamic "external_subnets" {
    for_each = each.value.external_subnets
    content {
      # subnet_key resolves to a subnet this module creates; subnet_reference
      # is the literal escape hatch. Variable validation guarantees exactly one
      # is set, so this never has to arbitrate.
      subnet_reference = (
        external_subnets.value.subnet_key != null
        ? nutanix_subnet_v2.subnet[external_subnets.value.subnet_key].ext_id
        : external_subnets.value.subnet_reference
      )

      dynamic "external_ips" {
        for_each = external_subnets.value.external_ips
        content {
          dynamic "ipv4" {
            for_each = external_ips.value.ipv4 != null ? [external_ips.value.ipv4] : []
            content {
              value         = ipv4.value.value
              prefix_length = ipv4.value.prefix_length
            }
          }
        }
      }
    }
  }

  dynamic "externally_routable_prefixes" {
    for_each = each.value.externally_routable_prefixes
    content {
      dynamic "ipv4" {
        for_each = externally_routable_prefixes.value.ipv4 != null ? [externally_routable_prefixes.value.ipv4] : []
        content {
          ip {
            value         = ipv4.value.ip.value
            prefix_length = ipv4.value.ip.prefix_length
          }
          prefix_length = ipv4.value.prefix_length
        }
      }
    }
  }

  dynamic "common_dhcp_options" {
    for_each = each.value.common_dhcp_options != null ? [each.value.common_dhcp_options] : []
    content {
      dynamic "domain_name_servers" {
        for_each = common_dhcp_options.value.domain_name_servers
        content {
          dynamic "ipv4" {
            for_each = domain_name_servers.value.ipv4 != null ? [domain_name_servers.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
        }
      }
    }
  }
}

##################################################
# Subnets
##################################################

##################################################
# Subnets (VLAN, including external)
#
# OVERLAY subnets are a SEPARATE resource below. See the note on
# local.non_overlay_subnets: keeping them together would make the
# VPC->external-subnet and overlay-subnet->VPC references a graph cycle.
#
# The two blocks are intentional duplicates. Terraform has no way to share a
# resource body, so any change to the arguments below must be mirrored in
# nutanix_subnet_v2.overlay_subnet.
##################################################

resource "nutanix_subnet_v2" "subnet" {
  for_each = local.non_overlay_subnets

  name                             = each.value.name
  description                      = each.value.description
  subnet_type                      = each.value.subnet_type
  network_id                       = local.subnet_network_ids[each.key]
  cluster_reference                = each.value.cluster_reference
  vpc_reference                    = each.value.vpc_reference
  is_external                      = each.value.is_external
  is_nat_enabled                   = each.value.is_nat_enabled
  is_advanced_networking           = each.value.is_advanced_networking
  virtual_switch_reference         = each.value.virtual_switch_reference
  network_function_chain_reference = each.value.network_function_chain_reference
  bridge_name                      = each.value.bridge_name

  dynamic "reserved_ip_addresses" {
    for_each = each.value.reserved_ip_addresses
    content {
      value = reserved_ip_addresses.value.value
    }
  }

  dynamic "ip_config" {
    for_each = each.value.ip_config != null ? [each.value.ip_config] : []
    content {
      dynamic "ipv4" {
        for_each = ip_config.value.ipv4 != null ? [ip_config.value.ipv4] : []
        content {
          ip_subnet {
            ip {
              value = ipv4.value.ip_subnet.ip.value
            }
            prefix_length = ipv4.value.ip_subnet.prefix_length
          }

          dynamic "default_gateway_ip" {
            for_each = ipv4.value.default_gateway_ip != null ? [ipv4.value.default_gateway_ip] : []
            content {
              value = default_gateway_ip.value.value
            }
          }

          dynamic "dhcp_server_address" {
            for_each = ipv4.value.dhcp_server_address != null ? [ipv4.value.dhcp_server_address] : []
            content {
              value = dhcp_server_address.value.value
            }
          }

          dynamic "pool_list" {
            for_each = ipv4.value.pool_list
            content {
              start_ip {
                value = pool_list.value.start_ip.value
              }
              end_ip {
                value = pool_list.value.end_ip.value
              }
            }
          }
        }
      }
    }
  }

  dynamic "dhcp_options" {
    for_each = each.value.dhcp_options != null ? [each.value.dhcp_options] : []
    content {
      domain_name      = dhcp_options.value.domain_name
      search_domains   = length(dhcp_options.value.search_domains) > 0 ? dhcp_options.value.search_domains : null
      tftp_server_name = dhcp_options.value.tftp_server_name
      boot_file_name   = dhcp_options.value.boot_file_name

      dynamic "domain_name_servers" {
        for_each = dhcp_options.value.domain_name_servers
        content {
          dynamic "ipv4" {
            for_each = domain_name_servers.value.ipv4 != null ? [domain_name_servers.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
        }
      }

      dynamic "ntp_servers" {
        for_each = dhcp_options.value.ntp_servers
        content {
          dynamic "ipv4" {
            for_each = ntp_servers.value.ipv4 != null ? [ntp_servers.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
        }
      }
    }
  }
}

##################################################
# Overlay Subnets (inside a VPC)
#
# Split from nutanix_subnet_v2.subnet so the dependency chain stays linear:
#   subnet (external) -> vpc -> overlay_subnet
# which lets a VPC and the overlay subnets inside it be created in one apply.
#
# Body is a deliberate duplicate of nutanix_subnet_v2.subnet apart from
# for_each and vpc_reference — keep the two in sync.
##################################################

resource "nutanix_subnet_v2" "overlay_subnet" {
  for_each = local.overlay_subnets

  name              = each.value.name
  description       = each.value.description
  subnet_type       = each.value.subnet_type
  network_id        = local.subnet_network_ids[each.key]
  cluster_reference = each.value.cluster_reference
  vpc_reference = (
    each.value.vpc_key != null
    ? nutanix_vpc_v2.vpc[each.value.vpc_key].ext_id
    : each.value.vpc_reference
  )
  is_external                      = each.value.is_external
  is_nat_enabled                   = each.value.is_nat_enabled
  is_advanced_networking           = each.value.is_advanced_networking
  virtual_switch_reference         = each.value.virtual_switch_reference
  network_function_chain_reference = each.value.network_function_chain_reference
  bridge_name                      = each.value.bridge_name

  dynamic "reserved_ip_addresses" {
    for_each = each.value.reserved_ip_addresses
    content {
      value = reserved_ip_addresses.value.value
    }
  }

  dynamic "ip_config" {
    for_each = each.value.ip_config != null ? [each.value.ip_config] : []
    content {
      dynamic "ipv4" {
        for_each = ip_config.value.ipv4 != null ? [ip_config.value.ipv4] : []
        content {
          ip_subnet {
            ip {
              value = ipv4.value.ip_subnet.ip.value
            }
            prefix_length = ipv4.value.ip_subnet.prefix_length
          }

          dynamic "default_gateway_ip" {
            for_each = ipv4.value.default_gateway_ip != null ? [ipv4.value.default_gateway_ip] : []
            content {
              value = default_gateway_ip.value.value
            }
          }

          dynamic "dhcp_server_address" {
            for_each = ipv4.value.dhcp_server_address != null ? [ipv4.value.dhcp_server_address] : []
            content {
              value = dhcp_server_address.value.value
            }
          }

          dynamic "pool_list" {
            for_each = ipv4.value.pool_list
            content {
              start_ip {
                value = pool_list.value.start_ip.value
              }
              end_ip {
                value = pool_list.value.end_ip.value
              }
            }
          }
        }
      }
    }
  }

  dynamic "dhcp_options" {
    for_each = each.value.dhcp_options != null ? [each.value.dhcp_options] : []
    content {
      domain_name      = dhcp_options.value.domain_name
      search_domains   = length(dhcp_options.value.search_domains) > 0 ? dhcp_options.value.search_domains : null
      tftp_server_name = dhcp_options.value.tftp_server_name
      boot_file_name   = dhcp_options.value.boot_file_name

      dynamic "domain_name_servers" {
        for_each = dhcp_options.value.domain_name_servers
        content {
          dynamic "ipv4" {
            for_each = domain_name_servers.value.ipv4 != null ? [domain_name_servers.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
        }
      }

      dynamic "ntp_servers" {
        for_each = dhcp_options.value.ntp_servers
        content {
          dynamic "ipv4" {
            for_each = ntp_servers.value.ipv4 != null ? [ntp_servers.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
        }
      }
    }
  }
}

##################################################
# Floating IPs
##################################################

resource "nutanix_floating_ip_v2" "floating_ip" {
  for_each = var.floating_ips

  name                      = each.value.name
  description               = each.value.description
  external_subnet_reference = each.value.external_subnet_reference
  vpc_reference             = each.value.vpc_reference

  dynamic "floating_ip" {
    for_each = each.value.floating_ip != null ? [each.value.floating_ip] : []
    content {
      dynamic "ipv4" {
        for_each = floating_ip.value.ipv4 != null ? [floating_ip.value.ipv4] : []
        content {
          value         = ipv4.value.value
          prefix_length = ipv4.value.prefix_length
        }
      }
    }
  }

  dynamic "association" {
    for_each = each.value.association != null ? [each.value.association] : []
    content {
      dynamic "vm_nic_association" {
        for_each = association.value.vm_nic_association != null ? [association.value.vm_nic_association] : []
        content {
          vm_nic_reference = vm_nic_association.value.vm_nic_reference
          vpc_reference    = vm_nic_association.value.vpc_reference
        }
      }

      dynamic "private_ip_association" {
        for_each = association.value.private_ip_association != null ? [association.value.private_ip_association] : []
        content {
          vpc_reference = private_ip_association.value.vpc_reference
          private_ip {
            ipv4 {
              value         = private_ip_association.value.private_ip.ipv4.value
              prefix_length = private_ip_association.value.private_ip.ipv4.prefix_length
            }
          }
        }
      }
    }
  }
}

##################################################
# Routing Policies (PBR)
##################################################

resource "nutanix_pbr_v2" "routing_policy" {
  for_each = var.routing_policies

  name        = each.value.name
  description = each.value.description
  vpc_ext_id  = each.value.vpc_ext_id
  priority    = each.value.priority

  policies {
    is_bidirectional = each.value.policies.is_bidirectional

    policy_match {
      source {
        address_type = each.value.policies.policy_match.source.address_type

        dynamic "subnet_prefix" {
          for_each = each.value.policies.policy_match.source.subnet_prefix != null ? [each.value.policies.policy_match.source.subnet_prefix] : []
          content {
            dynamic "ipv4" {
              for_each = subnet_prefix.value.ipv4 != null ? [subnet_prefix.value.ipv4] : []
              content {
                ip {
                  value         = ipv4.value.ip.value
                  prefix_length = ipv4.value.ip.prefix_length
                }
                prefix_length = ipv4.value.prefix_length
              }
            }
          }
        }
      }

      destination {
        address_type = each.value.policies.policy_match.destination.address_type

        dynamic "subnet_prefix" {
          for_each = each.value.policies.policy_match.destination.subnet_prefix != null ? [each.value.policies.policy_match.destination.subnet_prefix] : []
          content {
            dynamic "ipv4" {
              for_each = subnet_prefix.value.ipv4 != null ? [subnet_prefix.value.ipv4] : []
              content {
                ip {
                  value         = ipv4.value.ip.value
                  prefix_length = ipv4.value.ip.prefix_length
                }
                prefix_length = ipv4.value.prefix_length
              }
            }
          }
        }
      }

      protocol_type = each.value.policies.policy_match.protocol_type

      dynamic "protocol_parameters" {
        for_each = each.value.policies.policy_match.protocol_parameters != null ? [each.value.policies.policy_match.protocol_parameters] : []
        content {
          dynamic "layer_four_protocol_object" {
            for_each = protocol_parameters.value.layer_four_protocol_object != null ? [protocol_parameters.value.layer_four_protocol_object] : []
            content {
              dynamic "source_port_ranges" {
                for_each = layer_four_protocol_object.value.source_port_ranges
                content {
                  start_port = source_port_ranges.value.start_port
                  end_port   = source_port_ranges.value.end_port
                }
              }
              dynamic "destination_port_ranges" {
                for_each = layer_four_protocol_object.value.destination_port_ranges
                content {
                  start_port = destination_port_ranges.value.start_port
                  end_port   = destination_port_ranges.value.end_port
                }
              }
            }
          }

          dynamic "icmp_object" {
            for_each = protocol_parameters.value.icmp_object != null ? [protocol_parameters.value.icmp_object] : []
            content {
              icmp_type = icmp_object.value.icmp_type
              icmp_code = icmp_object.value.icmp_code
            }
          }

          dynamic "protocol_number_object" {
            for_each = protocol_parameters.value.protocol_number_object != null ? [protocol_parameters.value.protocol_number_object] : []
            content {
              protocol_number = protocol_number_object.value.protocol_number
            }
          }
        }
      }
    }

    policy_action {
      action_type = each.value.policies.policy_action.action_type

      dynamic "reroute_params" {
        for_each = each.value.policies.policy_action.reroute_params != null ? [each.value.policies.policy_action.reroute_params] : []
        content {
          reroute_fallback_action = reroute_params.value.reroute_fallback_action

          dynamic "service_ip" {
            for_each = reroute_params.value.service_ip != null ? [reroute_params.value.service_ip] : []
            content {
              ipv4 {
                value = service_ip.value.ipv4.value
              }
            }
          }

          dynamic "ingress_service_ip" {
            for_each = reroute_params.value.ingress_service_ip != null ? [reroute_params.value.ingress_service_ip] : []
            content {
              ipv4 {
                value = ingress_service_ip.value.ipv4.value
              }
            }
          }

          dynamic "egress_service_ip" {
            for_each = reroute_params.value.egress_service_ip != null ? [reroute_params.value.egress_service_ip] : []
            content {
              ipv4 {
                value = egress_service_ip.value.ipv4.value
              }
            }
          }
        }
      }
    }
  }
}

##################################################
# Routes
##################################################

resource "nutanix_routes_v2" "route" {
  for_each = var.routes

  name               = each.value.name
  description        = each.value.description
  vpc_reference      = each.value.vpc_reference
  route_table_ext_id = each.value.route_table_ext_id
  route_type         = each.value.route_type

  dynamic "destination" {
    for_each = [each.value.destination]
    content {
      dynamic "ipv4" {
        for_each = destination.value.ipv4 != null ? [destination.value.ipv4] : []
        content {
          ip {
            value         = ipv4.value.ip.value
            prefix_length = ipv4.value.ip.prefix_length
          }
          prefix_length = ipv4.value.prefix_length
        }
      }
      dynamic "ipv6" {
        for_each = destination.value.ipv6 != null ? [destination.value.ipv6] : []
        content {
          ip {
            value         = ipv6.value.ip.value
            prefix_length = ipv6.value.ip.prefix_length
          }
          prefix_length = ipv6.value.prefix_length
        }
      }
    }
  }

  dynamic "next_hop" {
    for_each = each.value.next_hop != null ? [each.value.next_hop] : []
    content {
      next_hop_type      = next_hop.value.next_hop_type
      next_hop_reference = next_hop.value.next_hop_reference

      dynamic "next_hop_ip_address" {
        for_each = next_hop.value.next_hop_ip_address != null ? [next_hop.value.next_hop_ip_address] : []
        content {
          dynamic "ipv4" {
            for_each = next_hop_ip_address.value.ipv4 != null ? [next_hop_ip_address.value.ipv4] : []
            content {
              value = ipv4.value.value
            }
          }
          dynamic "ipv6" {
            for_each = next_hop_ip_address.value.ipv6 != null ? [next_hop_ip_address.value.ipv6] : []
            content {
              value = ipv6.value.value
            }
          }
        }
      }
    }
  }
}

##################################################
# Network Functions (Flow service chaining)
##################################################

resource "nutanix_network_function_v2" "network_function" {
  for_each = var.network_functions

  name                    = each.value.name
  description             = each.value.description
  high_availability_mode  = each.value.high_availability_mode
  traffic_forwarding_mode = each.value.traffic_forwarding_mode
  failure_handling        = each.value.failure_handling

  dynamic "nic_pairs" {
    for_each = each.value.nic_pairs
    content {
      ingress_nic_reference = nic_pairs.value.ingress_nic_reference
      egress_nic_reference  = nic_pairs.value.egress_nic_reference
      vm_reference          = nic_pairs.value.vm_reference
      is_enabled            = nic_pairs.value.is_enabled
    }
  }

  dynamic "data_plane_health_check_config" {
    for_each = each.value.data_plane_health_check_config != null ? [each.value.data_plane_health_check_config] : []
    content {
      failure_threshold = data_plane_health_check_config.value.failure_threshold
      interval_secs     = data_plane_health_check_config.value.interval_secs
      success_threshold = data_plane_health_check_config.value.success_threshold
      timeout_secs      = data_plane_health_check_config.value.timeout_secs
    }
  }

  dynamic "metadata" {
    for_each = each.value.metadata != null ? [each.value.metadata] : []
    content {
      category_ids         = metadata.value.category_ids
      owner_reference_id   = metadata.value.owner_reference_id
      project_reference_id = metadata.value.project_reference_id
    }
  }
}
