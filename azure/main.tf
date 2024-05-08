module "mc-transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.3"
  account                       = var.account
  bgp_ecmp                      = true
  bgp_lan_interfaces_count      = 1
  cloud                         = var.cloud
  connected_transit             = true
  enable_bgp_over_lan           = true
  enable_egress_transit_firenet = false
  enable_firenet                = false
  enable_s2c_rx_balancing       = false
  enable_transit_firenet        = false
  gw_name                       = var.gw_name
  gw_subnet                     = var.gw_subnet
  hagw_subnet                   = var.hagw_subnet
  insane_mode = var.insane_mode
  instance_size                 = var.instance_size
  local_as_number               = var.local_as_number
  region                        = var.region
  use_existing_vpc              = var.use_existing_vpc
  vpc_id                        = format("%s:%s:%s", data.azurerm_virtual_network.vnet.name, var.resource_group, data.azurerm_virtual_network.vnet.guid)
  resource_group                = var.resource_group
  #
  # Safe Mechanism: adversting a non-existent prefix 
  #
  bgp_manual_spoke_advertise_cidrs = var.bgp_manual_spoke_advertise_cidrs
  enable_preserve_as_path = true 
}
resource "azurerm_public_ip" "pip-ars" {
  name                = "pip-ars-${var.ars_virtual_network_name}"
  location            = var.region
  resource_group_name = var.ars_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_route_server" "ars" {
  name                             = "ars-${var.ars_virtual_network_name}"
  location                         = var.region
  resource_group_name              = var.ars_resource_group_name
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.pip-ars.id
  subnet_id                        = data.azurerm_subnet.RouteServerSubnet.id
  branch_to_branch_traffic_enabled = true
}

resource "azurerm_virtual_network_peering" "transit_to_ars-virtual_network_peering" {
  depends_on = [ azurerm_route_server.ars ]
  name                         = "transit-to-ars"
  resource_group_name          = split(":", module.mc-transit.transit_gateway.vpc_id)[1]
  virtual_network_name         = split(":", module.mc-transit.transit_gateway.vpc_id)[0]
  remote_virtual_network_id    = data.azurerm_virtual_network.ars_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}

resource "azurerm_virtual_network_peering" "ars_to_transit-virtual_network_peering" {
  depends_on = [ azurerm_route_server.ars ]
  name                         = "ars-to-transit"
  resource_group_name          = var.ars_resource_group_name
  virtual_network_name         = var.ars_virtual_network_name
  remote_virtual_network_id    = data.azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "aviatrix_transit_external_device_conn" "transit_to_ars" {
  depends_on = [ azurerm_virtual_network_peering.ars_to_transit-virtual_network_peering, azurerm_virtual_network_peering.transit_to_ars-virtual_network_peering ]
  backup_bgp_remote_as_num  = azurerm_route_server.ars.virtual_router_asn
  backup_local_lan_ip       = module.mc-transit.transit_gateway.ha_bgp_lan_ip_list[0]
  backup_remote_lan_ip      = tolist(azurerm_route_server.ars.virtual_router_ips)[1]
  bgp_local_as_num          = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num         = azurerm_route_server.ars.virtual_router_asn
  connection_type           = "bgp"
  connection_name           = "transit_to_ars"
  enable_bgp_lan_activemesh = true
  gw_name                   = module.mc-transit.transit_gateway.gw_name
  ha_enabled                = true
  local_lan_ip              = module.mc-transit.transit_gateway.bgp_lan_ip_list[0]
  remote_lan_ip             = tolist(azurerm_route_server.ars.virtual_router_ips)[0]
  remote_vpc_name           = "${var.ars_virtual_network_name}:${var.ars_resource_group_name}:${split("/", data.azurerm_virtual_network.ars_vnet.id)[2]}"
  vpc_id                    = module.mc-transit.transit_gateway.vpc_id
  tunnel_protocol           = "LAN"
}

resource "azurerm_route_server_bgp_connection" "ars_to_transit_primary" {
  name            = module.mc-transit.transit_gateway.gw_name
  route_server_id = azurerm_route_server.ars.id
  peer_asn        = module.mc-transit.transit_gateway.local_as_number
  peer_ip         = module.mc-transit.transit_gateway.bgp_lan_ip_list[0]
}

resource "azurerm_route_server_bgp_connection" "ars_to_transit_secondary" {
  name            = module.mc-transit.transit_gateway.ha_gw_name
  route_server_id = azurerm_route_server.ars.id
  peer_asn        = module.mc-transit.transit_gateway.local_as_number
  peer_ip         = module.mc-transit.transit_gateway.ha_bgp_lan_ip_list[0]
}