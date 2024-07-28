variable "account" { type = string }
variable "bgp_manual_spoke_advertise_cidrs" { type = string }
variable "cidr" { type = string }
variable "controller_ip" { type = string }
variable "create_tgw" { type = string }
variable "instance_size" { type = string }
variable "local_as_number" { type = string }
variable "name" { type = string }
variable "password" { type = string }
variable "region" { type = string }
variable "username" { type = string }
variable "tgw_asn" { type = string }
variable "tgw_cidr" { type = list(string) }
variable "tags" { type = map(string) }
variable "spokes" {}
variable "vpcs_without_spokes" {}
variable "connections" {}
# variable "custom_snat_gw" {}
# variable "custom_snat_connection_name" {}