##################################################
# Example - tf-ntnx-net
##################################################
#
# Demonstrates the networking module managing:
#   - one VLAN subnet placed on a cluster
#   - one (REGULAR) VPC with an overlay subnet inside it
#   - one floating IP on an external subnet
#   - one policy-based routing (PBR) rule
#   - one static route
#
# The ext_id placeholders below (cluster, VPC, subnet and route-table
# references) must be replaced with the real external IDs from your target
# Prism Central. They can be discovered via the module's `existing_*` outputs
# or the nutanix_*_v2 data sources.

terraform {
  required_version = ">= 1.9.0"
}

module "network" {
  source = "git::https://github.com/bingamon-lab-tf-modules/tf-ntnx-net.git//module?ref=v0.1.0"

  # A regular VPC to host overlay subnets.
  vpcs = {
    app = {
      name        = "app-vpc"
      description = "Application overlay VPC"
      vpc_type    = "REGULAR"
    }
  }

  # One VLAN subnet on a cluster and one overlay subnet inside the VPC above.
  subnets = {
    vlan_100 = {
      name              = "vlan-100"
      description       = "Management VLAN subnet"
      subnet_type       = "VLAN"
      network_id        = 100
      cluster_reference = "00000000-0000-0000-0000-000000000000" # cluster ext_id

      ip_config = {
        ipv4 = {
          ip_subnet = {
            ip            = { value = "10.0.100.0" }
            prefix_length = 24
          }
          default_gateway_ip = { value = "10.0.100.1" }
          pool_list = [
            {
              start_ip = { value = "10.0.100.10" }
              end_ip   = { value = "10.0.100.200" }
            }
          ]
        }
      }
    }

    overlay_app = {
      name          = "overlay-app"
      description   = "Application overlay subnet"
      subnet_type   = "OVERLAY"
      vpc_reference = "11111111-1111-1111-1111-111111111111" # VPC ext_id

      ip_config = {
        ipv4 = {
          ip_subnet = {
            ip            = { value = "192.168.10.0" }
            prefix_length = 24
          }
          default_gateway_ip = { value = "192.168.10.1" }
        }
      }
    }
  }

  # One floating IP taken from an external subnet.
  floating_ips = {
    app = {
      name                      = "app-fip"
      description               = "Floating IP for the application tier"
      external_subnet_reference = "22222222-2222-2222-2222-222222222222" # external subnet ext_id
    }
  }

  # One policy-based routing rule permitting all traffic in the VPC.
  routing_policies = {
    allow_all = {
      name        = "allow-all"
      description = "Permit all traffic within the VPC"
      vpc_ext_id  = "11111111-1111-1111-1111-111111111111" # VPC ext_id
      priority    = 1000

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

  # One static default route pointing at an external subnet next hop.
  routes = {
    default = {
      name               = "default-route"
      description        = "Default route to the external subnet"
      route_table_ext_id = "33333333-3333-3333-3333-333333333333" # route table ext_id
      route_type         = "STATIC"

      destination = {
        ipv4 = {
          ip            = { value = "0.0.0.0", prefix_length = 0 }
          prefix_length = 0
        }
      }

      next_hop = {
        next_hop_type      = "EXTERNAL_SUBNET"
        next_hop_reference = "22222222-2222-2222-2222-222222222222" # external subnet ext_id
      }
    }
  }
}
