##################################################
# VPCs
##################################################

variable "vpcs" {
  description = "A map of VPCs to manage in Nutanix."
  type = map(object({
    name        = string
    description = optional(string, null)
    vpc_type    = optional(string, "REGULAR")

    external_subnets = optional(list(object({
      subnet_reference = string
      external_ips = optional(list(object({
        ipv4 = optional(object({
          value         = string
          prefix_length = optional(number, 32)
        }), null)
      })), [])
    })), [])

    externally_routable_prefixes = optional(list(object({
      ipv4 = optional(object({
        ip = object({
          value         = string
          prefix_length = optional(number, 32)
        })
        prefix_length = number
      }), null)
    })), [])

    common_dhcp_options = optional(object({
      domain_name_servers = optional(list(object({
        ipv4 = optional(object({
          value = string
        }), null)
      })), [])
    }), null)

    external_routing_domain_reference = optional(string, null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.vpcs :
      contains(["REGULAR", "TRANSIT"], v.vpc_type)
    ])
    error_message = "VPC 'vpc_type' must be one of: REGULAR, TRANSIT."
  }
}

##################################################
# Subnets
##################################################

variable "subnets" {
  description = "A map of subnets to manage in Nutanix."
  type = map(object({
    name                             = string
    description                      = optional(string, null)
    subnet_type                      = string # VLAN, OVERLAY
    network_id                       = optional(number, null)
    cluster_reference                = optional(string, null)
    vpc_reference                    = optional(string, null)
    is_external                      = optional(bool, false)
    is_nat_enabled                   = optional(bool, null)
    is_advanced_networking           = optional(bool, null)
    virtual_switch_reference         = optional(string, null)
    network_function_chain_reference = optional(string, null)
    bridge_name                      = optional(string, null)
    reserved_ip_addresses = optional(list(object({
      value = string
    })), [])

    ip_config = optional(object({
      ipv4 = optional(object({
        ip_subnet = object({
          ip = object({
            value = string
          })
          prefix_length = number
        })
        default_gateway_ip = optional(object({
          value = string
        }), null)
        dhcp_server_address = optional(object({
          value = string
        }), null)
        pool_list = optional(list(object({
          start_ip = object({
            value = string
          })
          end_ip = object({
            value = string
          })
        })), [])
      }), null)
    }), null)

    dhcp_options = optional(object({
      domain_name_servers = optional(list(object({
        ipv4 = optional(object({
          value = string
        }), null)
      })), [])
      domain_name      = optional(string, null)
      search_domains   = optional(list(string), [])
      tftp_server_name = optional(string, null)
      boot_file_name   = optional(string, null)
      ntp_servers = optional(list(object({
        ipv4 = optional(object({
          value = string
        }), null)
      })), [])
    }), null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      contains(["VLAN", "OVERLAY"], v.subnet_type)
    ])
    error_message = "Subnet 'subnet_type' must be one of: VLAN, OVERLAY."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.subnet_type != "VLAN" || v.network_id != null
    ])
    error_message = "VLAN subnets require a 'network_id'."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets :
      v.subnet_type != "OVERLAY" || v.vpc_reference != null
    ])
    error_message = "OVERLAY subnets require a 'vpc_reference'."
  }
}

##################################################
# Floating IPs
##################################################

variable "floating_ips" {
  description = "A map of floating IPs to manage in Nutanix."
  type = map(object({
    name                      = string
    description               = optional(string, null)
    external_subnet_reference = optional(string, null)
    vpc_reference             = optional(string, null)

    floating_ip = optional(object({
      ipv4 = optional(object({
        value         = string
        prefix_length = optional(number, 32)
      }), null)
    }), null)

    association = optional(object({
      vm_nic_association = optional(object({
        vm_nic_reference = string
        vpc_reference    = optional(string, null)
      }), null)
      private_ip_association = optional(object({
        vpc_reference = string
        private_ip = object({
          ipv4 = object({
            value         = string
            prefix_length = optional(number, 32)
          })
        })
      }), null)
    }), null)
  }))
  default = {}
}

##################################################
# Routing Policies (PBR)
##################################################

variable "routing_policies" {
  description = "A map of routing policies (PBR) to manage in Nutanix VPCs."
  type = map(object({
    name        = string
    description = optional(string, null)
    vpc_ext_id  = string
    priority    = number

    policies = object({
      policy_match = object({
        source = object({
          address_type = string # ANY, EXTERNAL, SUBNET
          subnet_prefix = optional(object({
            ipv4 = optional(object({
              ip = object({
                value         = string
                prefix_length = optional(number, 32)
              })
              prefix_length = optional(number, null)
            }), null)
          }), null)
        })
        destination = object({
          address_type = string # ANY, EXTERNAL, SUBNET
          subnet_prefix = optional(object({
            ipv4 = optional(object({
              ip = object({
                value         = string
                prefix_length = optional(number, 32)
              })
              prefix_length = optional(number, null)
            }), null)
          }), null)
        })
        protocol_type = string # TCP, UDP, ANY, ICMP, PROTOCOL_NUMBER
        protocol_parameters = optional(object({
          layer_four_protocol_object = optional(object({
            source_port_ranges = optional(list(object({
              start_port = number
              end_port   = number
            })), [])
            destination_port_ranges = optional(list(object({
              start_port = number
              end_port   = number
            })), [])
          }), null)
          icmp_object = optional(object({
            icmp_type = optional(number, null)
            icmp_code = optional(number, null)
          }), null)
          protocol_number_object = optional(object({
            protocol_number = number
          }), null)
        }), null)
      })
      policy_action = object({
        action_type = string # PERMIT, DENY, REROUTE
        reroute_params = optional(object({
          service_ip = optional(object({
            ipv4 = object({
              value = string
            })
          }), null)
          reroute_fallback_action = optional(string, null)
          ingress_service_ip = optional(object({
            ipv4 = object({
              value = string
            })
          }), null)
          egress_service_ip = optional(object({
            ipv4 = object({
              value = string
            })
          }), null)
        }), null)
      })
      is_bidirectional = optional(bool, false)
    })
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.routing_policies :
      contains(["ANY", "EXTERNAL", "SUBNET"], v.policies.policy_match.source.address_type)
    ])
    error_message = "Routing policy source 'address_type' must be one of: ANY, EXTERNAL, SUBNET."
  }

  validation {
    condition = alltrue([
      for k, v in var.routing_policies :
      contains(["ANY", "EXTERNAL", "SUBNET"], v.policies.policy_match.destination.address_type)
    ])
    error_message = "Routing policy destination 'address_type' must be one of: ANY, EXTERNAL, SUBNET."
  }

  validation {
    condition = alltrue([
      for k, v in var.routing_policies :
      contains(["TCP", "UDP", "ANY", "ICMP", "PROTOCOL_NUMBER"], v.policies.policy_match.protocol_type)
    ])
    error_message = "Routing policy 'protocol_type' must be one of: TCP, UDP, ANY, ICMP, PROTOCOL_NUMBER."
  }

  validation {
    condition = alltrue([
      for k, v in var.routing_policies :
      contains(["PERMIT", "DENY", "REROUTE"], v.policies.policy_action.action_type)
    ])
    error_message = "Routing policy 'action_type' must be one of: PERMIT, DENY, REROUTE."
  }
}

##################################################
# Routes
##################################################

variable "routes" {
  description = "A map of routes to manage in Nutanix VPCs."
  type = map(object({
    name               = optional(string, null)
    description        = optional(string, null)
    vpc_reference      = optional(string, null)
    route_table_ext_id = string
    route_type         = optional(string, "STATIC")

    destination = object({
      ipv4 = optional(object({
        ip = object({
          value         = string
          prefix_length = optional(number, 32)
        })
        prefix_length = number
      }), null)
      ipv6 = optional(object({
        ip = object({
          value         = string
          prefix_length = optional(number, 128)
        })
        prefix_length = number
      }), null)
    })

    next_hop = optional(object({
      next_hop_type      = optional(string, null)
      next_hop_reference = optional(string, null)
      next_hop_ip_address = optional(object({
        ipv4 = optional(object({
          value = string
        }), null)
        ipv6 = optional(object({
          value = string
        }), null)
      }), null)
    }), null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.routes :
      contains(["STATIC", "LOCAL", "DYNAMIC"], v.route_type)
    ])
    error_message = "Route 'route_type' must be one of: STATIC, LOCAL, DYNAMIC."
  }
}
