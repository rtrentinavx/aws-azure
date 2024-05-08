module "mc-transit-peering" {
  source                                      = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version                                     = "1.0.9"
  create_peerings                             = var.create_peerings
  enable_insane_mode_encryption_over_internet = true
  enable_peering_over_private_network         = false
  excluded_cidrs                              = []
  full_mesh_prepending                        = null
  prepending                                  = null
  prune_list                                  = []
  transit_gateways                            = var.transit_gateways
  tunnel_count                                = var.tunnel_count
}

