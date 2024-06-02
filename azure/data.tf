data "azurerm_subscription" "subscription" {}
data "azurerm_virtual_network" "spoke_vnet" {
  for_each            = var.spokes
  name                = each.value.vpc_id
  resource_group_name = each.value.resource_group_name 
}