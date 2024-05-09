variable "account" { type = string }
variable "bgp_manual_spoke_advertise_cidrs" { type = string }
variable "cloud" { type = string }
variable "controller_ip" { type = string }
variable "gw_name" { type = string }
variable "gw_subnet" { type = string }
variable "hagw_subnet" { type = string }
variable "insane_mode" { type = bool }
variable "instance_size" { type = string }
variable "local_as_number" { type = string }
variable "password" { type = string }
variable "region" { type = string }
variable "use_existing_vpc" { type = bool }
variable "username" { type = string }
variable "vpc_name" { type = string }
variable "tgw_asn" { type = string }
variable "tgw_cidr" { type = list(string) }
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
    vpc_id                           = string
  }))
}