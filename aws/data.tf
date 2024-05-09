data "aws_vpcs" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
data "aws_subnet" "gw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = element(data.aws_vpcs.vpc.ids, 0)
  filter {
    name   = "tag:Name"
    values = ["aviatrix-aws-transit"]
  }
}
data "aws_subnet" "hagw_subnet" {
  depends_on = [module.mc-transit]
  vpc_id     = element(data.aws_vpcs.vpc.ids, 0)
  filter {
    name   = "tag:Name"
    values = ["aviatrix-aws-transit-hagw"]
  }
}
data "aws_route_table" "route_table" {
  subnet_id = data.aws_subnet.gw_subnet.id
}
