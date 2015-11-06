variable "name" { default = "bastion" }
variable "instance_type" {}
variable "region" {}
variable "key_name" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_ids" {}

resource "aws_security_group" "bastion" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Bastion security group"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ami" {
  source        = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  instance_type = "${var.instance_type}"
  region        = "${var.region}"
  distribution  = "trusty"
}

resource "aws_instance" "bastion" {
  ami                    = "${module.ami.ami_id}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(split(",", var.subnet_ids), count.index)}"
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]

  tags { Name = "${var.name}" }
}

output "ip" { value = "${aws_instance.bastion.public_ip}" }
output "user" { value = "ubuntu" }
