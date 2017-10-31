variable "name" { default = "public" }
variable "cidrs" {}
variable "ipv6_cidrs" {}
variable "azs" {}
variable "vpc_id" {}
variable "igw_id" {}

resource "aws_subnet" "public" {
  vpc_id            = "${var.vpc_id}"
  cidr_block        = "${element(split(",", var.cidrs), count.index)}"
  ipv6_cidr_block   = "${cidrsubnet(var.ipv6_cidrs, 8, count.index+1)}"
  availability_zone = "${element(split(",", var.azs), count.index)}"
  count             = "${length(split(",", var.cidrs))}"

  lifecycle { create_before_destroy = true }
  tags { Name = "${var.name}.${element(split(",", var.azs), count.index)}" }

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_id}"

  tags { Name = "${var.name}.${element(split(",", var.azs), count.index)}" }
}

resource "aws_route" "public_inet" {
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${var.igw_id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "public_inet-v6" {
  route_table_id              = "${aws_route_table.public.id}"
  gateway_id                  = "${var.igw_id}"
  destination_ipv6_cidr_block = "::/0"
}

resource "aws_route_table_association" "public" {
  count          = "${length(concat(split(",", var.cidrs), split(",", var.ipv6_cidrs)))}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

# TODO: Determine if there will be an ACL per subnet or 1 for all
/*
resource "aws_network_acl" "public" {
  vpc_id     = "${var.vpc_id}"
  subnet_ids = ["${aws_subnet.public.*.id}"]

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags { Name = "${var.name}" }
}
*/

output "subnet_ids" { value = "${join(",", aws_subnet.public.*.id)}" }
output "subnet_ipv6_cidr" { value = "${join(",", aws_subnet.public.*.ipv6_cidr_block)}" }
output "subnet_ipv6_association_id" { value = "${aws_subnet.public.ipv6_association_id}" }

output "route_table_id" { value = "${aws_route_table.public.id}" }

output "route_id" { value = "${aws_route.public_inet.id}" }
