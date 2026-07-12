##################################################
# Unit Tests: Network Functions (Flow service chaining)
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

  # Existing network function discovery (gated by enable_data_lookups)
  mock_data "nutanix_network_functions_v2" {
    defaults = {
      network_functions = []
    }
  }
}

#########################
# Tests
#########################

# Test 1: Empty map (default) plans zero network functions.
run "empty_network_functions" {
  command = plan

  assert {
    condition     = output.network_summary.total_network_functions == 0
    error_message = "Expected 0 network functions for empty config"
  }

  assert {
    condition     = length(output.network_function_ids) == 0
    error_message = "Expected no network function IDs for empty config"
  }

  assert {
    condition     = output.existing_network_functions == null
    error_message = "Expected existing_network_functions to be null when enable_data_lookups is false"
  }
}

# Test 2: Populated map plans exactly one nutanix_network_function_v2.
run "single_network_function" {
  command = plan

  variables {
    network_functions = {
      fw_chain = {
        name                    = "fw-chain"
        description             = "Firewall service chain for east-west inspection"
        high_availability_mode  = "ACTIVE_PASSIVE"
        traffic_forwarding_mode = "INLINE"
        failure_handling        = "FAIL_CLOSE"
        nic_pairs = [
          {
            ingress_nic_reference = "44444444-4444-4444-4444-444444444444"
            egress_nic_reference  = "55555555-5555-5555-5555-555555555555"
            vm_reference          = "66666666-6666-6666-6666-666666666666"
            is_enabled            = true
          }
        ]
      }
    }
  }

  assert {
    condition     = output.network_summary.total_network_functions == 1
    error_message = "Expected 1 network function"
  }

  assert {
    condition     = length(output.network_function_ids) == 1
    error_message = "Expected exactly one network function to be planned"
  }

  assert {
    condition     = output.network_functions["fw_chain"].name == "fw-chain"
    error_message = "Expected network function name fw-chain"
  }

  assert {
    condition     = output.network_functions["fw_chain"].high_availability_mode == "ACTIVE_PASSIVE"
    error_message = "Expected high_availability_mode ACTIVE_PASSIVE"
  }
}

# Test 3: Two nic pairs (max allowed) plans successfully.
run "network_function_two_nic_pairs" {
  command = plan

  variables {
    network_functions = {
      tap = {
        name                    = "tap-mirror"
        high_availability_mode  = "ACTIVE_PASSIVE"
        traffic_forwarding_mode = "VTAP"
        nic_pairs = [
          { ingress_nic_reference = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" },
          { ingress_nic_reference = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" }
        ]
      }
    }
  }

  assert {
    condition     = output.network_summary.total_network_functions == 1
    error_message = "Expected 1 network function"
  }
}

# Test 4: Invalid high_availability_mode should fail validation.
run "invalid_high_availability_mode" {
  command = plan

  variables {
    network_functions = {
      bad = {
        name                   = "bad-nf"
        high_availability_mode = "ACTIVE_ACTIVE"
        nic_pairs              = [{ ingress_nic_reference = "44444444-4444-4444-4444-444444444444" }]
      }
    }
  }

  expect_failures = [var.network_functions]
}

# Test 5: Invalid traffic_forwarding_mode should fail validation.
run "invalid_traffic_forwarding_mode" {
  command = plan

  variables {
    network_functions = {
      bad = {
        name                    = "bad-nf"
        high_availability_mode  = "ACTIVE_PASSIVE"
        traffic_forwarding_mode = "MIRROR"
        nic_pairs               = [{ ingress_nic_reference = "44444444-4444-4444-4444-444444444444" }]
      }
    }
  }

  expect_failures = [var.network_functions]
}

# Test 6: Invalid failure_handling should fail validation.
run "invalid_failure_handling" {
  command = plan

  variables {
    network_functions = {
      bad = {
        name                   = "bad-nf"
        high_availability_mode = "ACTIVE_PASSIVE"
        failure_handling       = "PANIC"
        nic_pairs              = [{ ingress_nic_reference = "44444444-4444-4444-4444-444444444444" }]
      }
    }
  }

  expect_failures = [var.network_functions]
}

# Test 7: Empty nic_pairs list should fail validation (minimum of one required).
run "network_function_requires_nic_pair" {
  command = plan

  variables {
    network_functions = {
      bad = {
        name                   = "bad-nf"
        high_availability_mode = "ACTIVE_PASSIVE"
        nic_pairs              = []
      }
    }
  }

  expect_failures = [var.network_functions]
}

# Test 8: enable_data_lookups exposes the discovery data source.
run "data_lookup_enabled" {
  command = plan

  variables {
    enable_data_lookups = true
  }

  assert {
    condition     = output.existing_network_functions != null
    error_message = "Expected existing_network_functions to be populated when enable_data_lookups is true"
  }
}
