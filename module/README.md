# tf-ntnx-net

## Table of Contents

## Overview

A description of the module goes here.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_nutanix"></a> [nutanix](#requirement\_nutanix) | >= 2.4.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_nutanix"></a> [nutanix](#provider\_nutanix) | 2.4.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [nutanix_floating_ip_v2.floating_ip](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/floating_ip_v2) | resource |
| [nutanix_network_function_v2.network_function](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/network_function_v2) | resource |
| [nutanix_pbr_v2.routing_policy](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/pbr_v2) | resource |
| [nutanix_routes_v2.route](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/routes_v2) | resource |
| [nutanix_subnet_v2.subnet](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/subnet_v2) | resource |
| [nutanix_vpc_v2.vpc](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/resources/vpc_v2) | resource |
| [nutanix_clusters_v2.clusters](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/clusters_v2) | data source |
| [nutanix_floating_ips_v2.existing_floating_ips](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/floating_ips_v2) | data source |
| [nutanix_network_functions_v2.existing_network_functions](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/network_functions_v2) | data source |
| [nutanix_subnets_v2.existing_subnets](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/subnets_v2) | data source |
| [nutanix_vpcs_v2.existing_vpcs](https://registry.terraform.io/providers/nutanix/nutanix/latest/docs/data-sources/vpcs_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_data_lookups"></a> [enable\_data\_lookups](#input\_enable\_data\_lookups) | When true, enable discovery data sources for existing network functions (nutanix\_network\_functions\_v2). | `bool` | `false` | no |
| <a name="input_floating_ips"></a> [floating\_ips](#input\_floating\_ips) | A map of floating IPs to manage in Nutanix. | <pre>map(object({<br/>    name                      = string<br/>    description               = optional(string, null)<br/>    external_subnet_reference = optional(string, null)<br/>    vpc_reference             = optional(string, null)<br/><br/>    floating_ip = optional(object({<br/>      ipv4 = optional(object({<br/>        value         = string<br/>        prefix_length = optional(number, 32)<br/>      }), null)<br/>    }), null)<br/><br/>    association = optional(object({<br/>      vm_nic_association = optional(object({<br/>        vm_nic_reference = string<br/>        vpc_reference    = optional(string, null)<br/>      }), null)<br/>      private_ip_association = optional(object({<br/>        vpc_reference = string<br/>        private_ip = object({<br/>          ipv4 = object({<br/>            value         = string<br/>            prefix_length = optional(number, 32)<br/>          })<br/>        })<br/>      }), null)<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_network_functions"></a> [network\_functions](#input\_network\_functions) | A map of network functions (Flow service chaining / traffic steering) to manage in Nutanix. | <pre>map(object({<br/>    name                    = string<br/>    description             = optional(string, null)<br/>    high_availability_mode  = string                 # ACTIVE_PASSIVE<br/>    traffic_forwarding_mode = optional(string, null) # INLINE, VTAP<br/>    failure_handling        = optional(string, null) # NO_ACTION, FAIL_CLOSE, FAIL_OPEN<br/><br/>    nic_pairs = list(object({<br/>      ingress_nic_reference = string<br/>      egress_nic_reference  = optional(string, null)<br/>      vm_reference          = optional(string, null)<br/>      is_enabled            = optional(bool, true)<br/>    }))<br/><br/>    data_plane_health_check_config = optional(object({<br/>      failure_threshold = optional(number, null)<br/>      interval_secs     = optional(number, null)<br/>      success_threshold = optional(number, null)<br/>      timeout_secs      = optional(number, null)<br/>    }), null)<br/><br/>    metadata = optional(object({<br/>      category_ids         = optional(list(string), null)<br/>      owner_reference_id   = optional(string, null)<br/>      project_reference_id = optional(string, null)<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | A map of routes to manage in Nutanix VPCs. | <pre>map(object({<br/>    name               = optional(string, null)<br/>    description        = optional(string, null)<br/>    vpc_reference      = optional(string, null)<br/>    route_table_ext_id = string<br/>    route_type         = optional(string, "STATIC")<br/><br/>    destination = object({<br/>      ipv4 = optional(object({<br/>        ip = object({<br/>          value         = string<br/>          prefix_length = optional(number, 32)<br/>        })<br/>        prefix_length = number<br/>      }), null)<br/>      ipv6 = optional(object({<br/>        ip = object({<br/>          value         = string<br/>          prefix_length = optional(number, 128)<br/>        })<br/>        prefix_length = number<br/>      }), null)<br/>    })<br/><br/>    next_hop = optional(object({<br/>      next_hop_type      = optional(string, null)<br/>      next_hop_reference = optional(string, null)<br/>      next_hop_ip_address = optional(object({<br/>        ipv4 = optional(object({<br/>          value = string<br/>        }), null)<br/>        ipv6 = optional(object({<br/>          value = string<br/>        }), null)<br/>      }), null)<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_routing_policies"></a> [routing\_policies](#input\_routing\_policies) | A map of routing policies (PBR) to manage in Nutanix VPCs. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/>    vpc_ext_id  = string<br/>    priority    = number<br/><br/>    policies = object({<br/>      policy_match = object({<br/>        source = object({<br/>          address_type = string # ANY, EXTERNAL, SUBNET<br/>          subnet_prefix = optional(object({<br/>            ipv4 = optional(object({<br/>              ip = object({<br/>                value         = string<br/>                prefix_length = optional(number, 32)<br/>              })<br/>              prefix_length = optional(number, null)<br/>            }), null)<br/>          }), null)<br/>        })<br/>        destination = object({<br/>          address_type = string # ANY, EXTERNAL, SUBNET<br/>          subnet_prefix = optional(object({<br/>            ipv4 = optional(object({<br/>              ip = object({<br/>                value         = string<br/>                prefix_length = optional(number, 32)<br/>              })<br/>              prefix_length = optional(number, null)<br/>            }), null)<br/>          }), null)<br/>        })<br/>        protocol_type = string # TCP, UDP, ANY, ICMP, PROTOCOL_NUMBER<br/>        protocol_parameters = optional(object({<br/>          layer_four_protocol_object = optional(object({<br/>            source_port_ranges = optional(list(object({<br/>              start_port = number<br/>              end_port   = number<br/>            })), [])<br/>            destination_port_ranges = optional(list(object({<br/>              start_port = number<br/>              end_port   = number<br/>            })), [])<br/>          }), null)<br/>          icmp_object = optional(object({<br/>            icmp_type = optional(number, null)<br/>            icmp_code = optional(number, null)<br/>          }), null)<br/>          protocol_number_object = optional(object({<br/>            protocol_number = number<br/>          }), null)<br/>        }), null)<br/>      })<br/>      policy_action = object({<br/>        action_type = string # PERMIT, DENY, REROUTE<br/>        reroute_params = optional(object({<br/>          service_ip = optional(object({<br/>            ipv4 = object({<br/>              value = string<br/>            })<br/>          }), null)<br/>          reroute_fallback_action = optional(string, null)<br/>          ingress_service_ip = optional(object({<br/>            ipv4 = object({<br/>              value = string<br/>            })<br/>          }), null)<br/>          egress_service_ip = optional(object({<br/>            ipv4 = object({<br/>              value = string<br/>            })<br/>          }), null)<br/>        }), null)<br/>      })<br/>      is_bidirectional = optional(bool, false)<br/>    })<br/>  }))</pre> | `{}` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A map of subnets to manage in Nutanix. | <pre>map(object({<br/>    name                             = string<br/>    description                      = optional(string, null)<br/>    subnet_type                      = string # VLAN, OVERLAY<br/>    network_id                       = optional(number, null)<br/>    cluster_reference                = optional(string, null)<br/>    vpc_reference                    = optional(string, null)<br/>    is_external                      = optional(bool, false)<br/>    is_nat_enabled                   = optional(bool, null)<br/>    is_advanced_networking           = optional(bool, null)<br/>    virtual_switch_reference         = optional(string, null)<br/>    network_function_chain_reference = optional(string, null)<br/>    bridge_name                      = optional(string, null)<br/>    reserved_ip_addresses = optional(list(object({<br/>      value = string<br/>    })), [])<br/><br/>    ip_config = optional(object({<br/>      ipv4 = optional(object({<br/>        ip_subnet = object({<br/>          ip = object({<br/>            value = string<br/>          })<br/>          prefix_length = number<br/>        })<br/>        default_gateway_ip = optional(object({<br/>          value = string<br/>        }), null)<br/>        dhcp_server_address = optional(object({<br/>          value = string<br/>        }), null)<br/>        pool_list = optional(list(object({<br/>          start_ip = object({<br/>            value = string<br/>          })<br/>          end_ip = object({<br/>            value = string<br/>          })<br/>        })), [])<br/>      }), null)<br/>    }), null)<br/><br/>    dhcp_options = optional(object({<br/>      domain_name_servers = optional(list(object({<br/>        ipv4 = optional(object({<br/>          value = string<br/>        }), null)<br/>      })), [])<br/>      domain_name      = optional(string, null)<br/>      search_domains   = optional(list(string), [])<br/>      tftp_server_name = optional(string, null)<br/>      boot_file_name   = optional(string, null)<br/>      ntp_servers = optional(list(object({<br/>        ipv4 = optional(object({<br/>          value = string<br/>        }), null)<br/>      })), [])<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | A map of VPCs to manage in Nutanix. | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, null)<br/>    vpc_type    = optional(string, "REGULAR")<br/><br/>    external_subnets = optional(list(object({<br/>      subnet_reference = string<br/>      external_ips = optional(list(object({<br/>        ipv4 = optional(object({<br/>          value         = string<br/>          prefix_length = optional(number, 32)<br/>        }), null)<br/>      })), [])<br/>    })), [])<br/><br/>    externally_routable_prefixes = optional(list(object({<br/>      ipv4 = optional(object({<br/>        ip = object({<br/>          value         = string<br/>          prefix_length = optional(number, 32)<br/>        })<br/>        prefix_length = number<br/>      }), null)<br/>    })), [])<br/><br/>    common_dhcp_options = optional(object({<br/>      domain_name_servers = optional(list(object({<br/>        ipv4 = optional(object({<br/>          value = string<br/>        }), null)<br/>      })), [])<br/>    }), null)<br/><br/>    external_routing_domain_reference = optional(string, null)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_existing_clusters"></a> [existing\_clusters](#output\_existing\_clusters) | Existing clusters available for subnet placement. |
| <a name="output_existing_floating_ips"></a> [existing\_floating\_ips](#output\_existing\_floating\_ips) | Existing floating IPs discovered in the target Prism Central. |
| <a name="output_existing_network_functions"></a> [existing\_network\_functions](#output\_existing\_network\_functions) | Existing network functions discovered in the target Prism Central (null unless enable\_data\_lookups is true). |
| <a name="output_existing_subnets"></a> [existing\_subnets](#output\_existing\_subnets) | Existing subnets discovered in the target Prism Central. |
| <a name="output_existing_vpcs"></a> [existing\_vpcs](#output\_existing\_vpcs) | Existing VPCs discovered in the target Prism Central. |
| <a name="output_floating_ip_ids"></a> [floating\_ip\_ids](#output\_floating\_ip\_ids) | Map of floating IP keys to their external IDs. |
| <a name="output_floating_ips"></a> [floating\_ips](#output\_floating\_ips) | Map of created floating IPs with their details. |
| <a name="output_network_function_ids"></a> [network\_function\_ids](#output\_network\_function\_ids) | Map of network function keys to their external IDs. |
| <a name="output_network_functions"></a> [network\_functions](#output\_network\_functions) | Map of created network functions with their details. |
| <a name="output_network_summary"></a> [network\_summary](#output\_network\_summary) | Summary of networking resources managed by this module. |
| <a name="output_outputs"></a> [outputs](#output\_outputs) | Aggregate of all module outputs (spec §7.6 contract, consumed by the landing zone as module.<x>.outputs). |
| <a name="output_route_ids"></a> [route\_ids](#output\_route\_ids) | Map of route keys to their external IDs. |
| <a name="output_routes"></a> [routes](#output\_routes) | Map of created routes with their details. |
| <a name="output_routing_policies"></a> [routing\_policies](#output\_routing\_policies) | Map of created routing policies with their details. |
| <a name="output_routing_policy_ids"></a> [routing\_policy\_ids](#output\_routing\_policy\_ids) | Map of routing policy keys to their external IDs. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Map of subnet keys to their external IDs. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of created subnets with their details. |
| <a name="output_vpc_ids"></a> [vpc\_ids](#output\_vpc\_ids) | Map of VPC keys to their external IDs. |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | Map of created VPCs with their details. |
<!-- END_TF_DOCS -->
