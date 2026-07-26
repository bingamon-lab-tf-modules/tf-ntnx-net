##################################################
# Unit Tests: Networking
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
