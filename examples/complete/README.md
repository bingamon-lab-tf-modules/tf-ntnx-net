# Complete Example

This example demonstrates how to use the tf-ntnx-net module to create network resources in Nutanix.

## Usage

```hcl
module "network" {
  source = "../../module"

  # Create a VPC
  vpcs = {
    main = {
      name        = "production-vpc"
      description = "Production VPC"
      vpc_type    = "REGULAR"
      external_subnets = [
        {
          subnet_reference = "external-subnet-uuid"
        }
      ]
    }
  }

  # Create VLAN and overlay subnets
  subnets = {
    management = {
      name              = "management-vlan"
      subnet_type       = "VLAN"
      network_id        = 100
      cluster_reference = "cluster-uuid"
      ip_config = {
        ipv4 = {
          ip_subnet = {
            ip = {
              value = "10.0.100.0"
            }
            prefix_length = 24
          }
          default_gateway_ip = {
            value = "10.0.100.1"
          }
          pool_list = [
            {
              start_ip = {
                value = "10.0.100.10"
              }
              end_ip = {
                value = "10.0.100.250"
              }
            }
          ]
        }
      }
    }

    overlay = {
      name          = "app-overlay"
      subnet_type   = "OVERLAY"
      vpc_reference = "vpc-uuid"
      ip_config = {
        ipv4 = {
          ip_subnet = {
            ip = {
              value = "10.1.0.0"
            }
            prefix_length = 24
          }
          default_gateway_ip = {
            value = "10.1.0.1"
          }
        }
      }
    }
  }

  # Create floating IPs for external access
  floating_ips = {
    web_server = {
      name                      = "web-server-fip"
      external_subnet_reference = "external-subnet-uuid"
      association = {
        vm_nic_association = {
          vm_nic_reference = "vm-nic-uuid"
        }
      }
    }
  }
}
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.9.0 |
| nutanix   | >= 2.4.2 |

## Inputs

| Name             | Description                             | Type        | Default |
| ---------------- | --------------------------------------- | ----------- | ------- |
| nutanix_username | Nutanix Prism Central username          | string      | -       |
| nutanix_password | Nutanix Prism Central password          | string      | -       |
| nutanix_endpoint | Nutanix Prism Central endpoint          | string      | -       |
| nutanix_insecure | Skip TLS verification                   | bool        | false   |
| vpcs             | Map of VPCs to create                   | map(object) | {}      |
| subnets          | Map of subnets to create                | map(object) | {}      |
| floating_ips     | Map of floating IPs to create           | map(object) | {}      |
| routing_policies | Map of routing policies (PBR) to create | map(object) | {}      |
| routes           | Map of routes to create                 | map(object) | {}      |

## Outputs

| Name               | Description                 |
| ------------------ | --------------------------- |
| vpcs               | Created VPCs                |
| vpc_ids            | VPC external IDs            |
| subnets            | Created subnets             |
| subnet_ids         | Subnet external IDs         |
| floating_ips       | Created floating IPs        |
| floating_ip_ids    | Floating IP external IDs    |
| routing_policies   | Created routing policies    |
| routing_policy_ids | Routing policy external IDs |
| routes             | Created routes              |
| route_ids          | Route external IDs          |
