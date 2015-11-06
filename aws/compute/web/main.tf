variable "name" { default = "web" }
variable "vpc_cidr" {}
variable "azs" {}
variable "domain" {}
variable "key_name" {}
variable "key_path" {}
variable "vpc_id" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "ssl_cert_crt" {}
variable "ssl_cert_key" {}
variable "bastion_host" {}
variable "bastion_user" {}

variable "user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "consul_ips" {}

variable "db_endpoint" {}
variable "db_username" {}
variable "db_password" {}
variable "db_name" {}

variable "redis_host" {}
variable "redis_port" {}
variable "redis_password" {}

variable "rabbitmq_host" {}
variable "rabbitmq_port" {}
variable "rabbitmq_username" {}
variable "rabbitmq_password" {}
variable "rabbitmq_vhost" {}

variable "vault_private_ip" {}
variable "vault_domain" {}

variable "instance_type" {}
variable "blue_ami" {}
variable "blue_nodes" {}
variable "green_ami" {}
variable "green_nodes" {}

resource "aws_security_group" "elb" {
  name        = "${var.name}.elb"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Web ELB"

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

resource "aws_iam_server_certificate" "web" {
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

resource "aws_elb" "web" {
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
    ssl_certificate_id = "${aws_iam_server_certificate.web.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 15
    target              = "HTTP:80/"
  }
}

resource "aws_security_group" "web" {
  name        = "${var.name}.web"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Web Launch Configuration"

  tags { Name = "${var.name}-web" }

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
  }
}

resource "aws_launch_configuration" "blue" {
  image_id        = "${var.blue_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.web.id}"]
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
  load_balancers       = ["${aws_elb.web.id}"]

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
  }
}

resource "aws_launch_configuration" "green" {
  image_id        = "${var.green_ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.web.id}"]
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
  load_balancers       = ["${aws_elb.web.id}"]

  # lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.green"
    propagate_at_launch = true
  }
}

module "vault_setup" {
  source = "../vault_setup"

  name             = "${var.name}"
  vault_private_ip = "${var.vault_private_ip}"
  key_path         = "${var.key_path}"
  bastion_host     = "${var.bastion_host}"
  bastion_user     = "${var.bastion_user}"
  consul_ips       = "${var.consul_ips}"
}

output "remote_commands" {
  value = <<COMMANDS
  curl -XPUT http://127.0.0.1:8500/v1/kv/service/${var.name}/vault-addr -d 'https://${var.vault_domain}'
  (cat <<EOF
AMQP_URL='amqp://${var.rabbitmq_username}:${var.rabbitmq_password}@${var.rabbitmq_host}:${var.rabbitmq_port}/${var.rabbitmq_vhost}'
ANALYTICS_ENABLED='1'
ASSET_HOST=''
BASE_DOMAIN='${var.domain}'
DATABASE_URL='postgres://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}'
PRETTY_URL='https://${var.domain}'
ENV='${var.name}'
PGBACKUPS_URL=''
REDIS_URL='redis://:${var.redis_password}@${var.redis_host}:${var.redis_port}'
SENTRY_DSN=''
SENTRY_FRONTEND_DSN=''
VAULT_APP='${var.name}'
VAULT_ADDR=''
VAULT_TOKEN=''
EOF
) | curl -X PUT 127.0.0.1:8500/v1/kv/service/${var.name}/env --data-binary @-
COMMANDS
}

output "dns_name" { value = "${aws_elb.web.dns_name}" }
output "zone_id"  { value = "${aws_elb.web.zone_id}" }
