data "azurerm_subnet" "gateway-subnet" {
  name                 = "GatewaySUbnet"
  resource_group_name  = azurerm_resource_group.ars_resource_group.name
  virtual_network_name = module.ars-vnet.vnet_name
}
data "azurerm_subnet" "RouteServerSubnet-subnet" {
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.ars_resource_group.name
  virtual_network_name = module.ars-vnet.vnet_name
}
data "azurerm_virtual_network" "spoke_vnet" {
  for_each            = var.spokes
  name                = each.value.vpc_id
  resource_group_name = each.value.resource_group_name
}