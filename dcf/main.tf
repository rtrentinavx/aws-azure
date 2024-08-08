locals {
  smart_groups_map = { for sg in data.aviatrix_smart_groups.foo.smart_groups : sg.name => sg.uuid }
}

resource "aviatrix_distributed_firewalling_config" "dcf" {
  enable_distributed_firewalling = var.enable_distributed_firewalling
}
resource "aviatrix_smart_group" "smarties" {
  for_each = var.smarties
  name     = each.key
  dynamic "selector" {
    for_each = contains(keys(each.value), "cidr") ? [1] : []
    content {
      match_expressions {
        cidr = each.value.cidr
      }
    }
  }
  dynamic "selector" {
    for_each = contains(keys(each.value), "cidr") ? [] : [1]
    content {
      match_expressions {
        type = "vm"
        tags = each.value.tags
      }
    }
  }
}
resource "aviatrix_web_group" "web_groups" {
  for_each = var.web_groups
  name     = each.key
  dynamic "selector" {
    for_each = contains(keys(each.value), "domain") ? [1] : []
    content {
      match_expressions {
        snifilter = each.value.domain
      }
    }
  }
  dynamic "selector" {
    for_each = contains(keys(each.value), "domain") ? [] : [1]
    content {
      match_expressions {
        urlfilter = each.value.url
      }
    }
  }
}
resource "aviatrix_distributed_firewalling_policy_list" "policies" {
  dynamic "policies" {
    for_each = var.policies
    content {
      name                     = policies.key
      action                   = policies.value.action
      priority                 = policies.value.priority
      protocol                 = policies.value.protocol
      logging                  = policies.value.logging
      watch                    = policies.value.watch
      src_smart_groups         = [for sg in policies.value.src_smart_groups : local.smart_groups_map[sg]]
      dst_smart_groups         = [for sg in policies.value.dst_smart_groups : local.smart_groups_map[sg]]
      web_groups               = policies.value.web_groups == null ? null : (length(policies.value.web_groups) == 0 ? null : [for sg in policies.value.web_groups : local.smart_groups_map[sg]])
      flow_app_requirement     = "APP_UNSPECIFIED"
      decrypt_policy           = policies.value.decrypt_policy == null ? "DECRYPT_UNSPECIFIED" : (length(policies.value.decrypt_policy) == 0 ? "DECRYPT_UNSPECIFIED" : policies.value.decrypt_policy )
      exclude_sg_orchestration = false
      dynamic "port_ranges" {
        for_each = can(policies.value.port_range_high) && can(policies.value.port_range_low) ? [1] : []
        content {
          hi = policies.value.port_range_high
          lo = policies.value.port_range_low
        }
      }
    }
  }
}
