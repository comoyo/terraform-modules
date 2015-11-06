variable "name" { default = "haproxy" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "amis" {}
variable "count" {}
variable "instance_type" {}
variable "key_name" {}
variable "subnet_ids" {}

resource "aws_security_group" "haproxy" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "HAProxy security group"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
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

resource "template_file" "user_data" {
  filename = "${var.user_data}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}"
    service           = "${var.name}"
  }
}

resource "aws_instance" "haproxy" {
  ami           = "${element(split(",", var.amis), count.index)}"
  count         = "${var.count}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.haproxy.id}"]

  tags { Name = "${var.name}" }
}

output "private_ips" { value = "${join(",", aws_instance.haproxy.*.private_ip)}" }
output "public_ips"  { value = "${join(",", aws_instance.haproxy.*.public_ip)}" }
