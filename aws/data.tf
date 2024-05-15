
data "aws_availability_zones" "available" {}
data "aws_vpcs" "vpc" {
  count = var.create_transit_vpc ? 0 : 1
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
data "aws_subnet" "gw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = var.create_transit_vpc ? aws_vpc.vpc[0].id : data.aws_vpcs.vpc[0].ids[0]
  filter {
    name   = "tag:Name"
    values = ["aviatrix-aws-transit"]
  }
}
data "aws_subnet" "hagw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = var.create_transit_vpc ? aws_vpc.vpc[0].id : data.aws_vpcs.vpc[0].ids[0]
  filter {
    name   = "tag:Name"
    values = ["aviatrix-aws-transit-hagw"]
  }
}
data "aws_route_table" "route_table" {
  subnet_id = data.aws_subnet.gw_subnet.id
}
