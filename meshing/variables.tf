variable "controller_ip" { type = string }
variable "username" { type = string }
variable "create_peerings" { type = bool }
variable "enable_peering_over_private_network" { type = bool }
variable "password" { type = string }
variable "transit_gateways" { type = list(string) }
variable "tunnel_count" { type = string }