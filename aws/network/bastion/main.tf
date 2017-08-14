variable "name" {
  default = "bastion"
}

variable "instance_type" {}

variable "region" {}

variable "iam_instance_profile" {}

variable "vpc_id" {}

variable "vpc_cidr" {}

variable "subnet_ids" {}

variable "user_data" {}

variable "ami" {}

variable "owner" {
  default = ""
}

variable "open_sesame" {
  default     = false
  description = "Boolean variable to avoid attaching the default rule which opens port 22 for all IPs. It is set to true, should the port be open to everyone and false, if the open_sesame is used in eu-central-1 region."
}

variable "extra_security_groups" {
  description = "Additional list of security groups the Bastion instance shall have, that are not created by the module"

  type    = "list"
  default = []
}

resource "aws_security_group_rule" "open_to_world" {
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"

  count = "${1 - var.open_sesame}"
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Bastion security group"

  tags {
    Name  = "${var.name}"
    Owner = "${var.owner}"
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

resource "aws_security_group" "ssh_from_bastion" {
  name        = "ssh_from_bastion"
  description = "Allow ssh from bastion hosts"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name  = "ssh_from_bastion"
    Owner = "${var.owner}"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami                  = "${var.ami}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${var.iam_instance_profile}"
  subnet_id            = "${element(split(",", var.subnet_ids), count.index)}"

  vpc_security_group_ids = ["${aws_security_group.bastion.id}",
    "${var.extra_security_groups}",
  ]

  user_data = "${var.user_data}"
  count     = 1

  tags {
    Name  = "${var.name}"
    Owner = "${var.owner}"
  }
}

output "instance_id" {
  value = "${aws_instance.bastion.id}"
}

output "instance_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}

output "instance_private_ip" {
  value = "${aws_instance.bastion.private_ip}"
}

output "sg_from_bastion" {
  value = "${aws_security_group.ssh_from_bastion.id}"
}

output "sg_bastion" {
  value = "${aws_security_group.bastion.id}"
}
