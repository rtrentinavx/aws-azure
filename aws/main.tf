locals {
  rtbs = flatten(
    [
      for vpc_key, vpc_data in var.vpcs_without_spokes : [
        for rtb_id in data.aws_route_tables.rts[vpc_data.vpc_id].ids : [rtb_id]
      ]
    ]
  )
}
#
# Transit 
#
module "mc-transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.3"
  account                       = var.account
  bgp_ecmp                      = true
  cloud                         = "aws"
  cidr                          = var.cidr
  connected_transit             = true
  enable_egress_transit_firenet = false
  enable_encrypt_volume         = true
  enable_firenet                = false
  enable_s2c_rx_balancing       = true
  enable_transit_firenet        = false
  instance_size                 = var.instance_size
  insane_mode                   = true
  local_as_number               = var.local_as_number
  name                          = var.name
  region                        = var.region
  #
  # Safe Mechanism: adversting a non-existent prefix 
  #
  bgp_manual_spoke_advertise_cidrs = var.bgp_manual_spoke_advertise_cidrs
  enable_preserve_as_path          = true
  tags                             = var.tags
}
#
# TGW
#
resource "aws_ec2_transit_gateway" "tgw" {
  count                       = var.create_tgw ? 1 : 0
  amazon_side_asn             = var.tgw_asn
  transit_gateway_cidr_blocks = var.tgw_cidr
  tags                        = var.tags
}
#
# BGPoGRE 
#
resource "aws_route" "route" {
  route_table_id         = data.aws_route_table.route_table.id
  destination_cidr_block = element(var.tgw_cidr, 0)
  transit_gateway_id     = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
}
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids         = [data.aws_subnet.gw_subnet.id, data.aws_subnet.hagw_subnet.id]
  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
  vpc_id             = module.mc-transit.vpc.vpc_id
}
resource "aws_ec2_transit_gateway_connect" "connect" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment.id
  transit_gateway_id      = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
}
resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-1" {
  bgp_asn                       = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.101.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-1" {
  bgp_asn                       = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.201.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.ha_private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-2" {
  bgp_asn                       = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.102.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-2" {
  bgp_asn                       = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.202.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.ha_private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aviatrix_transit_external_device_conn" "external-1" {
  vpc_id                  = module.mc-transit.vpc.vpc_id
  connection_name         = "external-${var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id}-1"
  gw_name                 = module.mc-transit.transit_gateway.gw_name
  remote_gateway_ip       = "${aws_ec2_transit_gateway_connect_peer.connect_peer-1.transit_gateway_address}, ${aws_ec2_transit_gateway_connect_peer.ha_connect_peer-1.transit_gateway_address}"
  direct_connect          = true
  bgp_local_as_num        = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num       = aws_ec2_transit_gateway.tgw[0].amazon_side_asn
  tunnel_protocol         = "GRE"
  ha_enabled              = false
  local_tunnel_cidr       = "169.254.101.1/29,169.254.201.1/29"
  remote_tunnel_cidr      = "169.254.101.2/29,169.254.201.2/29"
  custom_algorithms       = false
  phase1_local_identifier = null
  #manual_bgp_advertised_cidrs = [ ]
  enable_jumbo_frame = true
}
resource "aviatrix_transit_external_device_conn" "external-2" {
  vpc_id                  = module.mc-transit.vpc.vpc_id
  connection_name         = "external-${var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id}-2"
  gw_name                 = module.mc-transit.transit_gateway.gw_name
  remote_gateway_ip       = "${aws_ec2_transit_gateway_connect_peer.connect_peer-2.transit_gateway_address}, ${aws_ec2_transit_gateway_connect_peer.ha_connect_peer-2.transit_gateway_address}"
  direct_connect          = true
  bgp_local_as_num        = module.mc-transit.transit_gateway.local_as_number
  bgp_remote_as_num       = aws_ec2_transit_gateway.tgw[0].amazon_side_asn
  tunnel_protocol         = "GRE"
  ha_enabled              = false
  local_tunnel_cidr       = "169.254.102.1/29,169.254.202.1/29"
  remote_tunnel_cidr      = "169.254.102.2/29,169.254.202.2/29"
  custom_algorithms       = false
  phase1_local_identifier = null
  #manual_bgp_advertised_cidrs = [ ]
  enable_jumbo_frame = true
}
#
# vpcs witht spokes
#
module "mc-spoke" {
  depends_on                       = [module.mc-transit]
  for_each                         = var.spokes
  source                           = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version                          = "1.6.9"
  account                          = each.value.account
  attached                         = each.value.attached
  cidr                             = each.value.cidr
  cloud                            = "aws"
  customized_spoke_vpc_routes      = each.value.customized_spoke_vpc_routes
  enable_max_performance           = each.value.insane_mode ? each.value.enable_max_performance : true
  included_advertised_spoke_routes = each.value.included_advertised_spoke_routes
  insane_mode                      = each.value.insane_mode
  instance_size                    = each.value.spoke_instance_size
  region                           = var.region
  transit_gw                       = module.mc-transit.transit_gateway.gw_name
  tags                             = var.tags
  name                             = each.key
  enable_bgp                       = each.value.enable_bgp
  local_as_number                  = each.value.enable_bgp ? each.value.local_as_number : null
}
#
# vpcs without spokes 
#
resource "aws_ec2_transit_gateway_vpc_attachment" "vpcs_without_spokes_attachment" {
  for_each           = var.vpcs_without_spokes
  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
  vpc_id             = each.value.vpc_id
}
resource "aws_route" "r10" {
  for_each               = toset(local.rtbs)
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
}
resource "aws_route" "r172" {
  for_each               = toset(local.rtbs)
  route_table_id         = each.value
  destination_cidr_block = "172.16.0.0/12"
  transit_gateway_id     = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
}
resource "aws_route" "r192" {
  for_each               = toset(local.rtbs)
  route_table_id         = each.value
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = var.create_tgw ? aws_ec2_transit_gateway.tgw[0].id : data.aws_ec2_transit_gateway.tgw[0].id
}
#
# S2C 
#
resource "aviatrix_spoke_external_device_conn" "spoke_external_device_conn" {
  depends_on               = [module.mc-spoke]
  for_each                 = var.connections
  vpc_id                   = module.mc-spoke[each.value.gw_name].vpc.vpc_id
  connection_name          = each.key
  gw_name                  = each.value.gw_name
  remote_gateway_ip        = each.value.remote_gateway_ip
  connection_type          = "static"
  direct_connect           = false
  remote_subnet            = each.value.remote_subnet
  ha_enabled               = false
  local_tunnel_cidr        = each.value.local_tunnel_cidr
  remote_tunnel_cidr       = each.value.remote_tunnel_cidr
  phase1_local_identifier  = null
  custom_algorithms        = each.value.custom_algorithms
  phase_1_authentication   = each.value.phase_1_authentication
  phase_2_authentication   = each.value.phase_2_authentication
  phase_1_dh_groups        = each.value.phase_1_dh_groups
  phase_2_dh_groups        = each.value.phase_2_dh_groups
  phase_1_encryption       = each.value.phase_1_encryption
  phase_2_encryption       = each.value.phase_2_encryption
  enable_ikev2             = each.value.enable_ikev2
  phase1_remote_identifier = each.value.phase1_remote_identifier
}
#
# SNAT/DNAT 
#
resource "aviatrix_gateway_snat" "gateway_snat_1" {
    gw_name =  var.custom_snat_gw
    snat_mode = "customized_snat"
    snat_policy {
        src_cidr = "10.208.112.0/22" 
        dst_cidr = "100.112.28.0/24"  
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.1"
    }
  snat_policy {
        src_cidr = "10.209.80.0/20"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.1"
    }
 snat_policy {
        src_cidr = "10.208.120.0/22"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.1"
    }
  snat_policy {
        src_cidr = "10.209.120.0/22"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.1"
    }
    snat_policy {
        src_cidr = "10.209.80.0/20"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.3"
    }
    snat_policy {
        src_cidr = "10.208.112.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.3"
    }
    snat_policy {
        src_cidr = "10.208.120.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.3"
    }
    snat_policy {
        src_cidr = "10.209.120.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.3"
    }
}
resource "aviatrix_gateway_snat" "gateway_snat_2" {
    gw_name = "${var.custom_snat_gw}-hagw"
    snat_mode = "customized_snat"
    snat_policy {
        src_cidr = "10.208.112.0/22" 
        dst_cidr = "100.112.28.0/24"  
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.2"
    }
  snat_policy {
        src_cidr = "10.209.80.0/20"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.2"
    }
 snat_policy {
        src_cidr = "10.208.120.0/22"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.2"
    }
  snat_policy {
        src_cidr = "10.209.120.0/22"
        dst_cidr = "100.112.28.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.2"
    }
    snat_policy {
        src_cidr = "10.209.80.0/20"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.4"
    }
    snat_policy {
        src_cidr = "10.208.112.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.4"
    }
    snat_policy {
        src_cidr = "10.208.120.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.4"
    }
    snat_policy {
        src_cidr = "10.209.120.0/22"
        dst_cidr = "100.112.58.0/24"
        protocol = "all"
        connection = "${var.custom_snat_connection_name}@site2cloud"
        snat_ips = "100.65.56.4"
    }
}
