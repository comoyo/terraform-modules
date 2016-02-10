variable "name" {
  default = "bastion"
}
variable "instance_type" {
}
variable "region" {
}
variable "iam_instance_profile" {
}
variable "vpc_id" {
}
variable "vpc_cidr" {
}
variable "subnet_ids" {
}
variable "user_data" {
}
variable "ami" {
}
variable "key_name" {
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Bastion security group"

  tags {
    Name = "${var.name}"
  }

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

resource "aws_instance" "bastion" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"
  iam_instance_profile   = "${var.iam_instance_profile}"
  subnet_id              = "${element(split(",", var.subnet_ids), count.index)}"
  vpc_security_group_ids = [ "${aws_security_group.bastion.id}" ]
  user_data              = "${var.user_data}"
  count                  = 1
  key_name               = "${var.key_name}"

  tags {
    Name = "${var.name}"
  }
}

output "instance_id" {
  value = "${aws_instance.bastion.id}"
}