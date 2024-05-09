data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.resource_group
}
data "azurerm_virtual_network" "ars_vnet" {
  name                = var.ars_virtual_network_name
  resource_group_name = var.ars_resource_group_name
}
data "azurerm_resource_group" "ars_resource_group" {
  name = var.ars_resource_group_name
}
data "azurerm_subnet" "RouteServerSubnet" {
  name                 = "RouteServerSubnet"
  resource_group_name  = var.ars_resource_group_name
  virtual_network_name = var.ars_virtual_network_name
}

data "azurerm_virtual_network" "spoke_vnet" {
  for_each            = var.spokes
  name                = each.value.vpc_id
  resource_group_name = each.value.resource_group_name
}