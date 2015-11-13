variable "name" { default = "nat" }
variable "public_subnets" {}
variable "instance_type" {}
variable "region" {}
variable "key_name" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_ids" {}
variable "key_path" {}

resource "aws_security_group" "nat" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "NAT security group"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//resource "template_file" "nat" {
//  filename = "${path.module}/nat.conf.tpl"
//
//  vars {
//    vpc_cidr = "${var.vpc_cidr}"
//  }
//}

module "nat_ami" {
  source = "github.com/atsaki/tf_aws_nat_ami"
  region = "${var.region}"
}

resource "aws_instance" "nat" {
  ami           = "${module.nat_ami.ami_id}"
  count         = "${length(split(",", var.public_subnets))}" # Comment out count to only have 1 NAT
  # count         = "${length(split(",", var.subnet_ids))}" # This doesn't work if the subnets are not yet created
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"
  # user_data     = "${template_file.nat.rendered}"

  associate_public_ip_address = true
  source_dest_check      = false
  vpc_security_group_ids = ["${aws_security_group.nat.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

output "instance_ids" { value = "${join(",", aws_instance.nat.*.id)}" }
