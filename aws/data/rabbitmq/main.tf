variable "name" { default = "rabbitmq" }
variable "azs" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "count" {}
variable "instance_type" {}
variable "amis" {}
# variable "blue_ami" {}
# variable "blue_nodes" {}
# variable "green_ami" {}
# variable "green_nodes" {}

variable "ssl_cert_crt" {}
variable "ssl_cert_key" {}
variable "key_name" {}
variable "key_path" {}
variable "bastion_host" {}
variable "bastion_user" {}

variable "user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "username" {}
variable "password" {}
variable "vhost" {}

/*
resource "aws_security_group" "elb" {
  name        = "${var.name}.elb"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for RabbitMQ ELB"

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

  ingress {
    protocol    = "tcp"
    from_port   = 5672
    to_port     = 5672
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_server_certificate" "rabbitmq" {
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

resource "aws_elb" "rabbitmq" {
  name                        = "${var.name}"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = true

  subnets         = ["${split(",", var.public_subnet_ids)}"]
  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "tcp"
    instance_port     = 5672
    instance_protocol = "tcp"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "tcp"
    instance_port      = 5672
    instance_protocol  = "tcp"
    ssl_certificate_id = "${aws_iam_server_certificate.rabbitmq.arn}"
  }

  listener {
    lb_port           = 5672
    lb_protocol       = "tcp"
    instance_port     = 5672
    instance_protocol = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 15
    target              = "HTTPS:5672/"
  }
}

resource "aws_security_group" "rabbitmq" {
  name        = "${var.name}.rabbitmq"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for RabbitMQ Launch Configuration"

  tags { Name = "${var.name}-rabbitmq" }

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

resource "template_file" "user_data_blue" {
  filename = "${var.user_data}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-blue"
    service           = "${var.name}"
    username          = "${var.username}"
    password          = "${var.password}"
    vhost             = "${var.vhost}"
  }
}

resource "aws_launch_configuration" "blue" {
  image_id        = "${var.blue_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.rabbitmq.id}"]
  user_data       = "${template_file.user_data_blue.rendered}"

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
  load_balancers       = ["${aws_elb.rabbitmq.id}"]

  # lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.blue"
    propagate_at_launch = true
  }
}

resource "template_file" "user_data_green" {
  filename = "${var.user_data}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-green"
    service           = "${var.name}"
    username          = "${var.username}"
    password          = "${var.password}"
    vhost             = "${var.vhost}"
  }
}

resource "aws_launch_configuration" "green" {
  image_id        = "${var.green_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.rabbitmq.id}"]
  user_data       = "${template_file.user_data_green.rendered}"

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
  load_balancers       = ["${aws_elb.rabbitmq.id}"]

  # lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.green"
    propagate_at_launch = true
  }
}
*/

resource "aws_security_group" "rabbitmq" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for RabbitMQ"

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

resource "template_file" "user_data" {
  filename = "${var.user_data}"
  count    = "${var.count}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}.${count.index+1}"
    service           = "${var.name}"
    username          = "${var.username}"
    password          = "${var.password}"
    vhost             = "${var.vhost}"
  }
}

resource "aws_instance" "rabbitmq" {
  ami           = "${element(split(",", var.amis), count.index)}"
  count         = "${var.count}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.private_subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.rabbitmq.id}"]

  tags { Name = "${var.name}" }
}

output "remote_commands" {
  value = <<COMMANDS
  setkey() { curl -X PUT 127.0.0.1:8500/v1/kv/service/rabbitmq/$1 -d "$2"; }
  setkey username '${var.username}'
  setkey password '${var.password}'
  setkey vhost '${var.vhost}'
COMMANDS
}

output "host"        { value = "rabbitmq.service.consul" }
output "port"        { value = "5672" }
output "username"    { value = "${var.username}" }
output "password"    { value = "${var.password}" }
output "vhost"       { value = "${var.vhost}" }
