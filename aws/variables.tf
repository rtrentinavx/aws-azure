variable "account" { type = string }
variable "bgp_manual_spoke_advertise_cidrs" { type = string }
variable "cidr" { type = string }
variable "cloud" { type = string }
variable "controller_ip" { type = string }
variable "create_tgw" { type = string }
variable "instance_size" { type = string }
variable "local_as_number" { type = string }
variable name { type = string }
variable "password" { type = string }
variable "region" { type = string }
variable "username" { type = string }
variable "tgw_asn" { type = string }
variable "tgw_cidr" { type = list(string) }
variable "tags" { type = map(string)}
variable "spokes" {
  type = map(object({
    account                          = string
    attached                         = bool
    cidr                             = string
    customized_spoke_vpc_routes      = string
    enable_max_performance           = bool
    insane_mode                      = bool
    spoke_instance_size              = string
    included_advertised_spoke_routes = string
    region                           = string
  }))
}
variable "vpcs_without_spokes" {
  type = map(object({
    subnet_ids = list(string)
    vpc_id     = string
  }))
}