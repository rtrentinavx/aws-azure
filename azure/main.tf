resource "azurerm_resource_group" "ars_resource_group" {
  name     = var.ars_resource_group_name != "" ? var.ars_resource_group_name : "${var.name}-ars-rg"
  location = var.region
  tags     = var.tags
}
resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group != "" ? var.resource_group : "${var.name}-rg"
  location = var.region
  tags     = var.tags
}
module "ars-vnet" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  resource_group_name = azurerm_resource_group.ars_resource_group.name
  vnet_location       = var.region
  address_space       = [var.ars_cidr]
  subnet_names        = ["GatewaySubnet", "RouteServerSubnet"]
  subnet_prefixes     = cidrsubnets("${var.ars_cidr}", 3, 3)
  use_for_each        = false
  vnet_name           = var.ars_vnet != "" ? var.ars_vnet : "${var.name}-ars"
  tags                = var.tags
}
resource "azurerm_public_ip" "pip-vng" {
  name                = "pip-vng-${var.name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.ars_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}
resource "azurerm_public_ip" "pip-ars" {
  name                = "pip-ars-${var.name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.ars_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng-${var.name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.ars_resource_group.name
  type                = "ExpressRoute"
  enable_bgp          = false
  sku                 = var.vpn_sku
  tags                = var.tags
  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.pip-vng.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.ars-vnet.vnet_subnets_name_id["GatewaySubnet"]
  }
}
resource "azurerm_route_server" "ars" {
  name                             = "ars-${var.name}"
  location                         = var.region
  resource_group_name              = azurerm_resource_group.ars_resource_group.name
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.pip-ars.id
  subnet_id                        = module.ars-vnet.vnet_subnets_name_id["RouteServerSubnet"]
  branch_to_branch_traffic_enabled = true
  tags                             = var.tags
}
module "mc-transit" {
  source                   = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                  = "2.5.3"
  account                  = var.account
  bgp_ecmp                 = true
  bgp_lan_interfaces_count = 1
  cidr                     = var.transit_cidr
  cloud                    = "azure"
  connected_transit        = true
  enable_bgp_over_lan      = true
  insane_mode              = true
  instance_size            = var.instance_size
  local_as_number          = var.local_as_number
  name                     = var.name
  region                   = var.region
  resource_group           = azurerm_resource_group.resource_group.name
  #
  # Safe Mechanism: adversting a non-existent prefix 
  #
  bgp_manual_spoke_advertise_cidrs = var.bgp_manual_spoke_advertise_cidrs
  enable_preserve_as_path          = true
  tags                             = var.tags
}
resource "azurerm_virtual_network_peering" "transit_to_ars-virtual_network_peering" {
  depends_on                   = [azurerm_route_server.ars]
  name                         = "transit-to-ars"
  resource_group_name          = split(":", module.mc-transit.transit_gateway.vpc_id)[1]
  virtual_network_name         = split(":", module.mc-transit.transit_gateway.vpc_id)[0]
  remote_virtual_network_id    = module.ars-vnet.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}
resource "azurerm_virtual_network_peering" "ars_to_transit-virtual_network_peering" {
  depends_on                   = [azurerm_route_server.ars]
  name                         = "ars-to-transit"
  resource_group_name          = var.ars_resource_group_name != "" ? var.ars_resource_group_name : "${var.name}-ars-rg"
  virtual_network_name         = module.ars-vnet.vnet_name
  remote_virtual_network_id    = module.mc-transit.vpc.azure_vnet_resource_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}
resource "aviatrix_transit_external_device_conn" "transit_to_ars" {
  depends_on                = [azurerm_virtual_network_peering.ars_to_transit-virtual_network_peering, azurerm_virtual_network_peering.transit_to_ars-virtual_network_peering]
  backup_bgp_remote_as_num  = "65515"
  backup_local_lan_ip       = module.mc-transit.transit_gateway.ha_bgp_lan_ip_list[0]
  backup_remote_lan_ip      = tolist(azurerm_route_server.ars.virtual_router_ips)[1]
  bgp_local_as_num          = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num         = "65515"
  connection_type           = "bgp"
  connection_name           = "transit_to_ars"
  enable_bgp_lan_activemesh = true
  gw_name                   = module.mc-transit.transit_gateway.gw_name
  ha_enabled                = true
  local_lan_ip              = module.mc-transit.transit_gateway.bgp_lan_ip_list[0]
  remote_lan_ip             = tolist(azurerm_route_server.ars.virtual_router_ips)[0]
  remote_vpc_name           = "${module.ars-vnet.vnet_name}:${azurerm_resource_group.ars_resource_group.name}:${data.azurerm_subscription.subscription.subscription_id}"
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
module "mc-spoke" {
  for_each                         = var.spokes
  source                           = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version                          = "1.6.9"
  account                          = each.value.account
  attached                         = each.value.attached
  cloud                            = "azure"
  customized_spoke_vpc_routes      = each.value.customized_spoke_vpc_routes
  enable_max_performance           = each.value.enable_max_performance
  gw_subnet                        = each.value.gw_subnet
  hagw_subnet                      = each.value.hagw_subnet
  included_advertised_spoke_routes = each.value.included_advertised_spoke_routes
  insane_mode                      = true
  inspection                       = each.value.inspection
  instance_size                    = each.value.spoke_instance_size
  region                           = var.region
  resource_group                   = each.value.resource_group_name
  transit_gw                       = module.mc-transit.transit_gateway.gw_name
  tags                             = var.tags
  use_existing_vpc                 = true
  vpc_id                           = format("%s:%s:%s", each.value.vnet_name, each.value.resource_group_name, each.value.vnet_guid)
  name                             = each.key
}
#
# vnets without spokes: current peerings need to be deleted before creating connections to the new transit 
#