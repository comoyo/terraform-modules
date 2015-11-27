variable "name" {
  default = "nat"
}
variable "public_subnets" {
}
variable "instance_type" {
}
variable "instance_profile_name_id" {
}
variable "key_name" {
  default = ""
}
variable "s3_bucket_name" {
}
variable "region" {
}
variable "vpc_id" {
}
variable "vpc_cidr" {
}
variable "subnet_ids" {
}
variable "key_path" {
}

resource "aws_security_group" "nat" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "NAT security group"

  tags {
    Name = "${var.name}"
  }

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

module "nat_ami" {
  source = "github.com/atsaki/tf_aws_nat_ami"
  region = "${var.region}"
}

# This file is copied from bastion_s3_keys module
resource "template_file" "scripts_update_authorized_keys_from_s3" {
  filename = "${path.module}/scripts/update_authorized_keys_from_s3.sh"

  vars {
    s3_bucket_name = "${var.s3_bucket_name}"
    ssh_user = "ec2-user"
  }
}

resource "aws_instance" "nat" {
  ami                         = "${module.nat_ami.ami_id}"
  count                       = "${length(split(",", var.public_subnets))}" # Comment out count to only have 1 NAT
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${var.instance_profile_name_id}"
  subnet_id                   = "${element(split(",", var.subnet_ids), count.index)}"
  key_name                    = "${var.key_name}"

  associate_public_ip_address = true
  source_dest_check           = false
  vpc_security_group_ids      = ["${aws_security_group.nat.id}"]

  user_data                   = "${template_file.scripts_update_authorized_keys_from_s3.rendered}"

  tags {
    Name = "${var.name}.${count.index+1}"
  }
}

output "instance_ids" {
  value = "${join(",", aws_instance.nat.*.id)}"
}
