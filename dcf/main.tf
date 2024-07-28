locals {
  smart_groups_map = { for sg in data.aviatrix_smart_groups.foo.smart_groups : sg.name => sg.uuid }
}

resource "aviatrix_distributed_firewalling_config" "dcf" {
  enable_distributed_firewalling = var.enable_distributed_firewalling
}
resource "aviatrix_smart_group" "smarties" {
  for_each = var.smarties
  name     = each.key
  selector {
    match_expressions {
      cidr = each.value.cidr
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "test" {
  dynamic "policies" {
    for_each = var.policies
    content {
      name             = policies.key
      action           = policies.value.action
      priority         = policies.value.priority
      protocol         = policies.value.protocol
      logging          = policies.value.logging
      watch            = policies.value.watch
      src_smart_groups = [local.smart_groups_map[policies.value.src_smart_groups]]
      dst_smart_groups = [local.smart_groups_map[policies.value.dst_smart_groups]]
      flow_app_requirement = "APP_UNSPECIFIED"
      decrypt_policy = "DECRYPT_UNSPECIFIED"
      exclude_sg_orchestration = false
      port_ranges {
        hi = policies.value.port_range_high
        lo = policies.value.port_range_low
      }
    }
  }
}
