variable "name" {}
variable "vpc_cidr" {}
variable "azs" {}
variable "region" {}
variable "key_name" {}
variable "key_path" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "ephemeral_subnets" {}
variable "bastion_instance_type" {}
variable "nat_instance_type" {}
variable "openvpn_instance_type" {}
variable "openvpn_ami" {}
variable "openvpn_admin_user" {}
variable "openvpn_admin_pw" {}
variable "openvpn_dns_ips" {}
variable "openvpn_cidr" {}
variable "openvpn_ssl_crt" {}
variable "openvpn_ssl_key" {}

module "vpc" {
  source = "./vpc"

  name = "${var.name}-vpc"
  cidr = "${var.vpc_cidr}"
}

module "public_subnet" {
  source = "./public_subnet"

  name   = "${var.name}-public"
  cidrs  = "${var.public_subnets}"
  azs    = "${var.azs}"
  vpc_id = "${module.vpc.vpc_id}"
}

module "bastion" {
  source = "./bastion"

  name          = "${var.name}-bastion"
  instance_type = "${var.bastion_instance_type}"
  region        = "${var.region}"
  key_name      = "${var.key_name}"
  vpc_id        = "${module.vpc.vpc_id}"
  vpc_cidr      = "${module.vpc.vpc_cidr}"
  subnet_ids    = "${module.public_subnet.subnet_ids}"
}

module "nat" {
  source = "./nat"

  name           = "${var.name}-nat"
  public_subnets = "${var.public_subnets}"
  instance_type  = "${var.nat_instance_type}"
  region         = "${var.region}"
  key_name       = "${var.key_name}"
  vpc_id         = "${module.vpc.vpc_id}"
  vpc_cidr       = "${module.vpc.vpc_cidr}"
  subnet_ids     = "${module.public_subnet.subnet_ids}"
  key_path       = "${var.key_path}"
  bastion_host   = "${module.bastion.ip}"
  bastion_user   = "${module.bastion.user}"
}

module "igw" {
  source = "./igw"

  vpc_id = "${module.vpc.vpc_id}"
}

module "private_subnet_igw" {
  source = "./private_subnet_igw"

  name   = "${var.name}-private"
  cidrs  = "${var.private_subnets}"
  azs    = "${var.azs}"
  vpc_id = "${module.vpc.vpc_id}"

  igw_gateway_ids = "${module.igw.id}"
}

module "private_subnet_nat" {
  source = "./private_subnet_nat"

  name   = "${var.name}-private"
  cidrs  = "${var.private_subnets}"
  azs    = "${var.azs}"
  vpc_id = "${module.vpc.vpc_id}"

  nat_instance_ids = "${module.nat.instance_ids}"
}

module "ephemeral_subnets" {
  source = "./private_subnet"

  name   = "${var.name}-ephemeral"
  cidrs  = "${var.ephemeral_subnets}"
  azs    = "${var.azs}"
  vpc_id = "${module.vpc.vpc_id}"

  nat_instance_ids = "${module.nat.instance_ids}"
}

module "openvpn" {
  source = "./openvpn"

  name          = "${var.name}-openvpn"
  ami           = "${var.openvpn_ami}"
  instance_type = "${var.openvpn_instance_type}"
  key_name      = "${var.key_name}"
  admin_user    = "${var.openvpn_admin_user}"
  admin_pw      = "${var.openvpn_admin_pw}"
  dns_ips       = "${var.openvpn_dns_ips}"
  vpn_cidr      = "${var.openvpn_cidr}"
  ssl_cert      = "${var.openvpn_ssl_crt}"
  ssl_key       = "${var.openvpn_ssl_key}"
  vpc_id        = "${module.vpc.vpc_id}"
  vpc_cidr      = "${module.vpc.vpc_cidr}"
  subnet_ids    = "${module.public_subnet.subnet_ids}"
  key_path      = "${var.key_path}"
  bastion_host  = "${module.bastion.ip}"
  bastion_user  = "${module.bastion.user}"
}

/*
resource "aws_network_acl" "mod" {
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${concat(split(",", module.public_subnet.subnet_ids), split(",", module.private_subnet.subnet_ids), split(",", module.ephemeral_subnets.subnet_ids))}"]

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

  tags { Name = "${var.name}-all" }
}
*/

output "azs" { value = "${var.azs}" }
output "vpc_id" { value = "${module.vpc.vpc_id}" }
output "vpc_cidr" { value = "${module.vpc.vpc_cidr}" }
output "public_subnet_ids" { value = "${module.public_subnet.subnet_ids}" }
output "bastion_ip" { value = "${module.bastion.ip}" }
output "bastion_user" { value = "${module.bastion.user}" }
output "private_subnet_ids" { value = "${module.private_subnet.subnet_ids}" }
output "ephemeral_subnet_ids" { value = "${module.ephemeral_subnets.subnet_ids}" }
output "openvpn_ip" { value = "${module.openvpn.ip}" }
