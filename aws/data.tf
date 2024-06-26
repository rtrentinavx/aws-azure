data "aws_ec2_transit_gateway" "tgw" {
  count = var.create_tgw ? 0 : 1
  filter {
    name   = "options.amazon-side-asn"
    values = [var.tgw_asn]
  }
}
data "aws_subnet" "gw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = module.mc-transit.vpc.vpc_id
  filter {
    name   = "tag:Name"
    values = var.name != null ? ["${var.name}-Public-gateway-and-firewall-mgmt-${var.region}a"] : ["aviatrix-avx-us-*-transit"]
  }
}

data "aws_subnet" "hagw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = module.mc-transit.vpc.vpc_id
  filter {
    name   = "tag:Name"
    values = var.name != null ? ["${var.name}-Public-gateway-and-firewall-mgmt-${var.region}b"] : ["aviatrix-avx-us-*-transit-hagw"]
  }
}
data "aws_route_table" "route_table" {
  subnet_id = data.aws_subnet.gw_subnet.id
}
data "aws_route_tables" "rts" {
  for_each = var.vpcs_without_spokes
  vpc_id   = each.value.vpc_id
}

