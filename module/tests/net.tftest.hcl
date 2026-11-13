##################################################
# Unit Tests: Networking
# cspell:words snat
##################################################

#########################
# Provider
#########################

provider "nutanix" {
  username     = "dummy"
  password     = "dummy"
  endpoint     = "dummy.local"
  port         = 9440
  insecure     = true
  wait_timeout = 1
}

#########################
# Mock Data (Nutanix Provider)
#########################

mock_provider "nutanix" {

  # Existing VPC discovery
  mock_data "nutanix_vpcs_v2" {
    defaults = {
      vpcs = []
    }
  }

  # Existing subnet discovery
  mock_data "nutanix_subnets_v2" {
    defaults = {
      subnets = []
    }
  }

  # Existing floating IP discovery
  mock_data "nutanix_floating_ips_v2" {
    defaults = {
      floating_ips = []
    }
  }

  # Cluster lookup for subnet placement
  mock_data "nutanix_clusters_v2" {
    defaults = {
      cluster_entities = []
    }
  }
}

#########################
# Tests
#########################

# Test 1: Empty configuration plans zero resources.
run "empty_config" {
  command = plan

  assert {
    condition     = output.network_summary.total_vpcs == 0
    error_message = "Expected 0 VPCs for empty config"
  }

  assert {
    condition     = output.network_summary.total_subnets == 0
    error_message = "Expected 0 subnets for empty config"
  }

  assert {
    condition     = output.network_summary.total_floating_ips == 0
    error_message = "Expected 0 floating IPs for empty config"
  }
}

# Test 2: One VPC with a VLAN subnet and an overlay subnet.
run "vpc_and_subnets" {
  command = plan

  variables {
    vpcs = {
      app = {
        name     = "app-vpc"
        vpc_type = "REGULAR"
      }
    }
    subnets = {
      vlan_100 = {
        name              = "vlan-100"
        subnet_type       = "VLAN"
        network_id        = 100
        cluster_reference = "00000000-0000-0000-0000-000000000000"
      }
      overlay_app = {
        name          = "overlay-app"
        subnet_type   = "OVERLAY"
        vpc_reference = "11111111-1111-1111-1111-111111111111"
      }
    }
  }

  assert {
    condition     = output.network_summary.total_vpcs == 1
    error_message = "Expected 1 VPC"
  }

  assert {
    condition     = output.network_summary.total_subnets == 2
    error_message = "Expected 2 subnets"
  }

  assert {
    condition     = output.network_summary.vlan_subnets == 1
    error_message = "Expected 1 VLAN subnet"
  }

  assert {
    condition     = output.network_summary.overlay_subnets == 1
    error_message = "Expected 1 overlay subnet"
  }

  assert {
    condition     = output.vpcs["app"].name == "app-vpc"
    error_message = "Expected VPC name app-vpc"
  }
}

# Test 3: Full stack — VPC, subnet, floating IP, PBR rule and static route.
run "full_networking" {
  command = plan

  variables {
    vpcs = {
      app = {
        name     = "app-vpc"
        vpc_type = "REGULAR"
      }
    }
    subnets = {
      overlay_app = {
        name          = "overlay-app"
        subnet_type   = "OVERLAY"
        vpc_reference = "11111111-1111-1111-1111-111111111111"
      }
    }
    floating_ips = {
      app = {
        name                      = "app-fip"
        external_subnet_reference = "22222222-2222-2222-2222-222222222222"
      }
    }
    routing_policies = {
      allow_all = {
        name       = "allow-all"
        vpc_ext_id = "11111111-1111-1111-1111-111111111111"
        priority   = 1000
        policies = {
          policy_match = {
            source        = { address_type = "ANY" }
            destination   = { address_type = "ANY" }
            protocol_type = "ANY"
          }
          policy_action = {
            action_type = "PERMIT"
          }
        }
      }
    }
    routes = {
      default = {
        name               = "default-route"
        route_table_ext_id = "33333333-3333-3333-3333-333333333333"
        route_type         = "STATIC"
        destination = {
          ipv4 = {
            ip            = { value = "0.0.0.0", prefix_length = 0 }
            prefix_length = 0
          }
        }
        next_hop = {
          next_hop_type      = "EXTERNAL_SUBNET"
          next_hop_reference = "22222222-2222-2222-2222-222222222222"
        }
      }
    }
  }

  assert {
    condition     = output.network_summary.total_floating_ips == 1
    error_message = "Expected 1 floating IP"
  }

  assert {
    condition     = output.network_summary.total_routing_policies == 1
    error_message = "Expected 1 routing policy"
  }

  assert {
    condition     = output.network_summary.total_routes == 1
    error_message = "Expected 1 route"
  }
}

# Test 4: Invalid VPC type should fail validation.
run "invalid_vpc_type" {
  command = plan

  variables {
    vpcs = {
      bad = {
        name     = "bad-vpc"
        vpc_type = "INVALID"
      }
    }
  }

  expect_failures = [var.vpcs]
}

# Test 5: Invalid subnet type should fail validation.
run "invalid_subnet_type" {
  command = plan

  variables {
    subnets = {
      bad = {
        name        = "bad-subnet"
        subnet_type = "INVALID"
      }
    }
  }

  expect_failures = [var.subnets]
}

# Test 6: VLAN subnet with neither vlan_id nor network_id should fail validation.
run "vlan_subnet_requires_network_id" {
  command = plan

  variables {
    subnets = {
      vlan = {
        name        = "vlan-no-id"
        subnet_type = "VLAN"
      }
    }
  }

  expect_failures = [var.subnets]
}

# Test 6a: 'vlan_id' alone satisfies a VLAN subnet and reaches nutanix_subnet_v2
# as network_id.
run "vlan_subnet_accepts_vlan_id_alias" {
  command = plan

  variables {
    subnets = {
      vlan = {
        name              = "vlan-by-vlan-id"
        cluster_reference = "00000000-0000-0000-0000-000000000001"
        subnet_type       = "VLAN"
        vlan_id           = 82
      }
    }
  }

  assert {
    condition     = nutanix_subnet_v2.subnet["vlan"].network_id == 82
    error_message = "vlan_id should resolve to the nutanix_subnet_v2 network_id"
  }
}

# Test 6b: 'network_id' alone still works — the alias must not be a breaking change.
run "vlan_subnet_accepts_network_id" {
  command = plan

  variables {
    subnets = {
      vlan = {
        name              = "vlan-by-network-id"
        cluster_reference = "00000000-0000-0000-0000-000000000001"
        subnet_type       = "VLAN"
        network_id        = 83
      }
    }
  }

  assert {
    condition     = nutanix_subnet_v2.subnet["vlan"].network_id == 83
    error_message = "network_id should still populate the nutanix_subnet_v2 network_id"
  }
}

# Test 6c: Both set and in agreement is permitted.
run "vlan_subnet_accepts_matching_aliases" {
  command = plan

  variables {
    subnets = {
      vlan = {
        name              = "vlan-both-agree"
        cluster_reference = "00000000-0000-0000-0000-000000000001"
        subnet_type       = "VLAN"
        vlan_id           = 84
        network_id        = 84
      }
    }
  }

  assert {
    condition     = nutanix_subnet_v2.subnet["vlan"].network_id == 84
    error_message = "matching vlan_id/network_id should resolve to that value"
  }
}

# Test 6d: Both set but disagreeing is a caller error, not something to resolve
# silently in favour of one field.
run "vlan_subnet_rejects_conflicting_aliases" {
  command = plan

  variables {
    subnets = {
      vlan = {
        name        = "vlan-conflict"
        subnet_type = "VLAN"
        vlan_id     = 82
        network_id  = 99
      }
    }
  }

  expect_failures = [var.subnets]
}

# Test 7: Overlay subnet without a vpc_reference should fail validation.
run "overlay_subnet_requires_vpc_reference" {
  command = plan

  variables {
    subnets = {
      overlay = {
        name        = "overlay-no-vpc"
        subnet_type = "OVERLAY"
      }
    }
  }

  expect_failures = [var.subnets]
}

# Test 8: Floating IP without an external_subnet_reference should fail validation.
run "floating_ip_requires_external_subnet" {
  command = plan

  variables {
    floating_ips = {
      fip = {
        name = "orphan-fip"
      }
    }
  }

  expect_failures = [var.floating_ips]
}

# Test 9: Invalid route type should fail validation.
run "invalid_route_type" {
  command = plan

  variables {
    routes = {
      bad = {
        name               = "bad-route"
        route_table_ext_id = "33333333-3333-3333-3333-333333333333"
        route_type         = "INVALID"
        destination = {
          ipv4 = {
            ip            = { value = "0.0.0.0", prefix_length = 0 }
            prefix_length = 0
          }
        }
      }
    }
  }

  expect_failures = [var.routes]
}

# Test 10: Invalid PBR action type should fail validation.
run "invalid_pbr_action_type" {
  command = plan

  variables {
    routing_policies = {
      bad = {
        name       = "bad-policy"
        vpc_ext_id = "11111111-1111-1111-1111-111111111111"
        priority   = 1
        policies = {
          policy_match = {
            source        = { address_type = "ANY" }
            destination   = { address_type = "ANY" }
            protocol_type = "ANY"
          }
          policy_action = {
            action_type = "INVALID"
          }
        }
      }
    }
  }

  expect_failures = [var.routing_policies]
}

# Test 11: Route with multiple next_hops blocks (v2.5.0+ schema).
run "route_multiple_next_hops" {
  command = plan

  variables {
    routes = {
      multipath = {
        name               = "multipath-route"
        route_table_ext_id = "33333333-3333-3333-3333-333333333333"
        route_type         = "STATIC"
        destination = {
          ipv4 = {
            ip            = { value = "10.200.0.0", prefix_length = 16 }
            prefix_length = 16
          }
        }
        next_hops = [
          {
            next_hop_type      = "EXTERNAL_SUBNET"
            next_hop_reference = "22222222-2222-2222-2222-222222222221"
          },
          {
            next_hop_type      = "EXTERNAL_SUBNET"
            next_hop_reference = "22222222-2222-2222-2222-222222222222"
          }
        ]
      }
    }
  }

  assert {
    condition     = length(nutanix_routes_v2.route["multipath"].next_hop) == 2
    error_message = "Expected 2 next_hop blocks planned on nutanix_routes_v2"
  }
}

# Test 12: Route setting both next_hop and next_hops should fail validation.
run "route_rejects_both_next_hop_and_next_hops" {
  command = plan

  variables {
    routes = {
      conflict = {
        name               = "conflict-route"
        route_table_ext_id = "33333333-3333-3333-3333-333333333333"
        route_type         = "STATIC"
        destination = {
          ipv4 = {
            ip            = { value = "10.200.0.0", prefix_length = 16 }
            prefix_length = 16
          }
        }
        next_hop = {
          next_hop_type      = "EXTERNAL_SUBNET"
          next_hop_reference = "22222222-2222-2222-2222-222222222221"
        }
        next_hops = [
          {
            next_hop_type      = "EXTERNAL_SUBNET"
            next_hop_reference = "22222222-2222-2222-2222-222222222222"
          }
        ]
      }
    }
  }

  expect_failures = [var.routes]
}

# Test 13: Populated discovery data sources match Nutanix v2.5.1 schemas and sort deterministically.
run "discovery_summaries_populated" {
  command = plan

  override_data {
    target = data.nutanix_clusters_v2.clusters
    values = {
      cluster_entities = [
        {
          ext_id                   = "00000000-0000-4000-8000-000000000002"
          name                     = "pc-cluster"
          backup_eligibility_score = null
          categories               = null
          cluster_profile_ext_id   = null
          container_name           = null
          expand                   = null
          inefficient_vm_count     = null
          links                    = null
          nodes                    = null
          tenant_id                = null
          upgrade_status           = null
          vm_count                 = null
          config = [
            {
              authorized_public_key_list       = null
              build_info                       = null
              cluster_arch                     = "X86_64"
              cluster_function                 = ["PRISM_CENTRAL"]
              cluster_software_map             = null
              encryption_in_transit_status     = null
              encryption_option                = null
              encryption_scope                 = null
              fault_tolerance_state            = null
              hypervisor_types                 = null
              incarnation_id                   = null
              is_available                     = true
              is_lts                           = null
              is_password_remote_login_enabled = null
              is_remote_support_enabled        = null
              operation_mode                   = null
              pulse_status                     = null
              redundancy_factor                = null
              timezone                         = null
            }
          ]
          network = [
            {
              backplane                  = null
              external_address           = null
              external_data_services_ip  = null
              external_subnet            = null
              fqdn                       = null
              http_proxy_list            = null
              http_proxy_white_list      = null
              internal_subnet            = null
              key_management_server_type = null
              masquerading_ip            = null
              masquerading_port          = null
              name_server_ip_list        = null
              nfs_subnet_white_list      = null
              ntp_server_ip_list         = null
              smtp_server                = null
              management_server = [
                {
                  ip             = null
                  is_drs_enabled = false
                  is_in_use      = true
                  is_registered  = true
                  type           = "VCENTER"
                }
              ]
            }
          ]
        },
        {
          ext_id                   = "00000000-0000-4000-8000-000000000001"
          name                     = "pe-cluster-01"
          backup_eligibility_score = null
          categories               = null
          cluster_profile_ext_id   = null
          container_name           = null
          expand                   = null
          inefficient_vm_count     = null
          links                    = null
          network                  = null
          nodes                    = null
          tenant_id                = null
          upgrade_status           = null
          vm_count                 = null
          config = [
            {
              authorized_public_key_list       = null
              build_info                       = null
              cluster_arch                     = "X86_64"
              cluster_function                 = ["AOS"]
              cluster_software_map             = null
              encryption_in_transit_status     = null
              encryption_option                = null
              encryption_scope                 = null
              fault_tolerance_state            = null
              hypervisor_types                 = ["AHV"]
              incarnation_id                   = null
              is_available                     = true
              is_lts                           = null
              is_password_remote_login_enabled = null
              is_remote_support_enabled        = null
              operation_mode                   = null
              pulse_status                     = null
              redundancy_factor                = 2
              timezone                         = "UTC"
            }
          ]
        }
      ]
    }
  }

  override_data {
    target = data.nutanix_vpcs_v2.existing_vpcs
    values = {
      vpcs = [
        {
          ext_id                                  = "00000000-0000-4000-8000-000000000010"
          name                                    = "shared-vpc"
          description                             = "Shared application VPC"
          vpc_type                                = "REGULAR"
          common_dhcp_options                     = null
          external_routing_domain_reference       = null
          external_subnets                        = null
          externally_routable_prefixes            = null
          kubernetes_clusters                     = null
          links                                   = null
          metadata                                = null
          project_ext_id                          = null
          scope                                   = "GLOBAL"
          shared_with_projects                    = null
          should_advertise_connected_subnets      = false
          snat_ips                                = null
          supported_multiple_external_subnet_type = null
          tenant_id                               = null
        }
      ]
    }
  }

  override_data {
    target = data.nutanix_subnets_v2.existing_subnets
    values = {
      subnets = [
        {
          ext_id                           = "00000000-0000-4000-8000-000000000020"
          name                             = "ext-vlan-100"
          subnet_type                      = "VLAN"
          network_id                       = 100
          cluster_reference                = "00000000-0000-4000-8000-000000000001"
          vpc_reference                    = null
          is_external                      = true
          is_connected                     = true
          is_nat_enabled                   = true
          is_advanced_networking           = false
          bridge_name                      = null
          cluster_name                     = null
          description                      = null
          dhcp_options                     = null
          dynamic_ip_addresses             = null
          hypervisor_type                  = null
          ip_config                        = null
          ip_prefix                        = null
          ip_usage                         = null
          links                            = null
          metadata                         = null
          migration_state                  = null
          network_function_chain_reference = null
          project_ext_id                   = null
          reserved_ip_addresses            = null
          shared_with_projects             = null
          virtual_switch                   = null
          virtual_switch_reference         = null
          vpc                              = null
        }
      ]
    }
  }

  override_data {
    target = data.nutanix_floating_ips_v2.existing_floating_ips
    values = {
      floating_ips = [
        {
          ext_id                    = "00000000-0000-4000-8000-000000000030"
          name                      = "existing-fip"
          external_subnet_reference = "00000000-0000-4000-8000-000000000020"
          association               = null
          association_status        = null
          description               = null
          external_subnet           = null
          floating_ip               = null
          floating_ip_value         = null
          links                     = null
          metadata                  = null
          private_ip                = null
          project_ext_id            = null
          tenant_id                 = null
          vm_nic                    = null
          vm_nic_reference          = null
          vpc                       = null
          vpc_reference             = null
        }
      ]
    }
  }

  assert {
    condition     = length(output.existing_clusters) == 2 && output.existing_clusters[0].name == "pe-cluster-01" && output.existing_clusters[0].cluster_function == tolist(["AOS"])
    error_message = "Expected existing_clusters sorted by ext_id with AOS cluster first"
  }

  assert {
    condition     = length(output.existing_vpcs) == 1 && output.existing_vpcs[0].name == "shared-vpc"
    error_message = "Expected existing_vpcs summary to expose shared-vpc"
  }

  assert {
    condition     = length(output.existing_subnets) == 1 && output.existing_subnets[0].is_external == true
    error_message = "Expected existing_subnets summary to expose ext-vlan-100"
  }

  assert {
    condition     = length(output.existing_floating_ips) == 1 && output.existing_floating_ips[0].name == "existing-fip"
    error_message = "Expected existing_floating_ips summary to expose existing-fip"
  }
}
