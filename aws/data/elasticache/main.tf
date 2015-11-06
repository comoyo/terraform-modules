variable "name" { default = "redis" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_ids" {}
variable "engine" { default = "redis" }
variable "engine_version" { default = "2.8.19" }
variable "family" { default = "redis2.8" }
variable "instance_type" {}
variable "port" { default = "6379" }
variable "initial_cached_nodes" { default = 1 }
variable "apply_immediately" { default = false }
variable "maintenance_window" { default = "mon:05:00-mon:06:00" }

resource "aws_elasticache_parameter_group" "elasticache" {
  name        = "${var.name}"
  description = "Parameter group for Elasticache"
  family      = "${var.family}"

  parameter {
    name  = "appendfsync"
    value = "everysec"
  }

  parameter {
    name  = "appendonly"
    value = "yes"
  }
}

resource "aws_security_group" "elasticache" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Elasticache"

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

resource "aws_elasticache_subnet_group" "elasticache" {
  name        = "${var.name}"
  subnet_ids  = [ "${split(",", var.subnet_ids)}" ]
  description = "Subnet group for Elasticache"
}

resource "aws_elasticache_cluster" "elasticache" {
  cluster_id           = "${format("%.*s", 20, var.name)}" # 20 max chars
  engine               = "${var.engine}"
  node_type            = "${var.instance_type}"
  port                 = "${var.port}"
  num_cache_nodes      = "${var.initial_cached_nodes}"
  parameter_group_name = "${aws_elasticache_parameter_group.elasticache.name}"
  subnet_group_name    = "${aws_elasticache_subnet_group.elasticache.name}"
  security_group_ids   = ["${aws_security_group.elasticache.id}"]
  apply_immediately    = "${var.apply_immediately}"
  maintenance_window   = "${var.maintenance_window}"
  # snapshot_arns        = ["EXISTING_SNAPSHOT_ARN"]
}

output "host" { value = "${aws_elasticache_cluster.elasticache.cache_nodes.0.address}" }
output "port" { value = "${var.port}" }
output "password" { value = "" } # Elasticache has no auth
