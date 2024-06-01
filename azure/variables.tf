variable "account" { type = string }
variable "ars_vnet" {
  type    = string
  default = ""
}
variable "ars_virtual_network_name" {
  type    = string
  default = ""
}
variable "ars_resource_group_name" {
  type    = string
  default = ""
}
variable "ars_cidr" { type = string }
variable "bgp_manual_spoke_advertise_cidrs" { type = string }
variable "cloud" { type = string }
variable "controller_ip" { type = string }
variable "insane_mode" { type = bool }
variable "instance_size" { type = string }
variable "local_as_number" { type = string }
variable "name" { type = string }
variable "password" { type = string }
variable "region" { type = string }
variable "resource_group" { type = string }
variable "transit_cidr" { type = string }
variable "username" { type = string }
variable "vpn_sku" { type = string }
variable "spokes" {
  type = map(object({
    account                          = string
    attached                         = bool
    customized_spoke_vpc_routes      = string
    enable_max_performance           = bool
    gw_subnet                        = string
    hagw_subnet                      = string
    insane_mode                      = bool
    spoke_instance_size              = string
    inspection                       = bool
    included_advertised_spoke_routes = string
    region                           = string
    resource_group_name              = string
    vpc_id                           = string
  }))
}