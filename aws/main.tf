module "mc-transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                       = "2.5.3"
  account                       = var.account
  bgp_ecmp                      = true
  cloud                         = var.cloud
  connected_transit             = true
  enable_egress_transit_firenet = false
  enable_encrypt_volume         = true
  enable_firenet                = false
  enable_s2c_rx_balancing       = true
  enable_transit_firenet        = false
  gw_name                       = var.gw_name
  gw_subnet                     = var.gw_subnet
  hagw_subnet                   = var.hagw_subnet
  instance_size                 = var.instance_size
  insane_mode = var.insane_mode
  local_as_number               = var.local_as_number
  region                        = var.region
  use_existing_vpc              = var.use_existing_vpc
  vpc_id                        = element(data.aws_vpcs.vpc.ids, 0)
  #
  # Safe Mechanism: adversting a non-existent prefix 
  #
  bgp_manual_spoke_advertise_cidrs = var.bgp_manual_spoke_advertise_cidrs
  enable_preserve_as_path = true 
}
resource "aws_route" "route" {
  route_table_id            = data.aws_route_table.route_table.id
  destination_cidr_block    = element(var.tgw_cidr,0)
  transit_gateway_id        = aws_ec2_transit_gateway.tgw.id
}
resource "aws_ec2_transit_gateway" "tgw" {
  amazon_side_asn = var.tgw_asn
  transit_gateway_cidr_blocks = var.tgw_cidr
} 
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids         = [data.aws_subnet.gw_subnet.id, data.aws_subnet.hagw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.aws_vpcs.vpc.ids[0]
}
resource "aws_ec2_transit_gateway_connect" "connect" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.attachment.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw.id
}
resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-1" {
  bgp_asn = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.101.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-1" {
  bgp_asn = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.201.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.ha_private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "connect_peer-2" {
  bgp_asn = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.102.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aws_ec2_transit_gateway_connect_peer" "ha_connect_peer-2" {
  bgp_asn = module.mc-transit.transit_gateway.local_as_number
  inside_cidr_blocks            = ["169.254.202.0/29"]
  peer_address                  = module.mc-transit.transit_gateway.ha_private_ip
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.connect.id
}
resource "aviatrix_spoke_external_device_conn" "external-1" {
    vpc_id =  data.aws_vpcs.vpc.ids[0]
    connection_name = "external-${module.mc-transit.transit_gateway.gw_name}-1"
    gw_name = module.mc-transit.transit_gateway.gw_name
    remote_gateway_ip =  "${aws_ec2_transit_gateway_connect_peer.connect_peer-1.transit_gateway_address}, ${aws_ec2_transit_gateway_connect_peer.ha_connect_peer-1.transit_gateway_address}"
    direct_connect = true
    bgp_local_as_num = module.mc-transit.transit_gateway.local_as_number
    bgp_remote_as_num = aws_ec2_transit_gateway.tgw.amazon_side_asn
    tunnel_protocol = "GRE"
    ha_enabled = false
    local_tunnel_cidr = "169.254.101.1/29,169.254.201.1/29"
    remote_tunnel_cidr = "169.254.101.2/29,169.254.201.2/29"
    custom_algorithms = false
    phase1_local_identifier = null
    #manual_bgp_advertised_cidrs = [ ]
}
resource "aviatrix_spoke_external_device_conn" "external-2" {
    vpc_id =  data.aws_vpcs.vpc.ids[0]
    connection_name = "external-${module.mc-transit.transit_gateway.gw_name}-2"
    gw_name = module.mc-transit.transit_gateway.gw_name
    remote_gateway_ip = "${aws_ec2_transit_gateway_connect_peer.connect_peer-2.transit_gateway_address}, ${aws_ec2_transit_gateway_connect_peer.ha_connect_peer-2.transit_gateway_address}"
    direct_connect = true
    bgp_local_as_num = module.mc-transit.transit_gateway.local_as_number
    bgp_remote_as_num = aws_ec2_transit_gateway.tgw.amazon_side_asn
    tunnel_protocol = "GRE"
    ha_enabled = false
    local_tunnel_cidr = "169.254.102.1/29,169.254.202.1/29"
    remote_tunnel_cidr = "169.254.102.2/29,169.254.202.2/29"
    custom_algorithms = false
    phase1_local_identifier = null
    #manual_bgp_advertised_cidrs = [ ]
}