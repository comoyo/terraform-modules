variable "name" { default = "simple" }
variable "vpc_cidr" {}
variable "azs" {}
variable "key_name" {}
variable "vpc_id" {}
variable "public_subnet_ids" {}
variable "private_subnet_ids" {}
variable "ssl_cert_crt" {}
variable "ssl_cert_key" {}

variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}

variable "instance_type" {}
variable "blue_ami" {}
variable "blue_nodes" {}
variable "green_ami" {}
variable "green_nodes" {}

resource "aws_security_group" "elb" {
  name        = "${var.name}.elb"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Simple ELB"

  tags { Name = "${var.name}-elb" }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_server_certificate" "simple" {
  name             = "${var.name}"
  certificate_body = "${file("${var.ssl_cert_crt}")}"
  private_key      = "${file("${var.ssl_cert_key}")}"

  provisioner "local-exec" {
    command = <<EOF
      echo "Sleep 10 secends so that mycert is propagated by aws iam service"
      echo "See https://github.com/hashicorp/terraform/issues/2499 (terraform ~v0.6.1)"
      sleep 10
EOF
  }
}

resource "aws_elb" "simple" {
  name                        = "${var.name}"
  connection_draining         = true
  connection_draining_timeout = 400

  subnets         = ["${split(",", var.public_subnet_ids)}"]
  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = 80
    instance_protocol  = "http"
    ssl_certificate_id = "${aws_iam_server_certificate.simple.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 15
    target              = "HTTP:80/"
  }
}

resource "aws_security_group" "simple" {
  name        = "${var.name}.simple"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Simple Launch Configuration"

  tags { Name = "${var.name}-simple" }

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

resource "aws_launch_configuration" "blue" {
  image_id        = "${var.blue_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.simple.id}"]

  # lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "blue" {
  name                 = "${var.name}.blue"
  launch_configuration = "${aws_launch_configuration.blue.name}"
  desired_capacity     = "${var.blue_nodes}"
  min_size             = "${var.blue_nodes}"
  max_size             = "${var.blue_nodes}"
  min_elb_capacity     = "${var.blue_nodes}"
  availability_zones   = ["${split(",", var.azs)}"]
  vpc_zone_identifier  = ["${split(",", var.private_subnet_ids)}"]
  load_balancers       = ["${aws_elb.simple.id}"]

  # lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.blue"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "green" {
  image_id        = "${var.green_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.simple.id}"]

  # lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "green" {
  name                 = "${var.name}.green"
  launch_configuration = "${aws_launch_configuration.green.name}"
  desired_capacity     = "${var.green_nodes}"
  min_size             = "${var.green_nodes}"
  max_size             = "${var.green_nodes}"
  min_elb_capacity     = "${var.green_nodes}"
  availability_zones   = ["${split(",", var.azs)}"]
  vpc_zone_identifier  = ["${split(",", var.private_subnet_ids)}"]
  load_balancers       = ["${aws_elb.simple.id}"]

  # lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.green"
    propagate_at_launch = true
  }
}

output "dns_name" { value = "${aws_elb.simple.dns_name}" }
output "zone_id"  { value = "${aws_elb.simple.zone_id}" }
