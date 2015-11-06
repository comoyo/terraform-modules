variable "name" { default = "postgres" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "subnet_ids" {}
variable "db_name" {}
variable "username" {}
variable "password" {}
variable "engine" {}
variable "engine_version" {}
variable "port" {}

variable "az" {}
variable "multi_az" {}
variable "instance_type" {}
variable "storage_gbs" { default = "100" }
variable "iops" { default = "1000" }
variable "storage_type" { default = "gp2" }
variable "apply_immediately" { default = false }
variable "publicly_accessible" { default = false }
variable "storage_encrypted" { default = false }
variable "maintenance_window" { default = "mon:04:03-mon:04:33" }
variable "backup_retention_period" { default = 7 }
variable "backup_window" { default = "10:19-10:49" }

resource "aws_security_group" "rds" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for RDS"

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

resource "aws_db_subnet_group" "rds" {
  name        = "${var.name}"
  subnet_ids  = ["${split(",", var.subnet_ids)}"]
  description = "Subnet group for RDS"
}

resource "aws_db_instance" "master" {
  identifier     = "${var.name}"
  name           = "${var.db_name}"
  username       = "${var.username}"
  password       = "${var.password}"
  engine         = "${var.engine}"
  engine_version = "${var.engine_version}"
  port           = "${var.port}"

  # availability_zone       = "${var.az}"
  multi_az                = "${var.multi_az}"
  instance_class          = "${var.instance_type}"
  allocated_storage       = "${var.storage_gbs}"
  # iops                    = "${var.iops}"
  storage_type            = "${var.storage_type}"
  apply_immediately       = "${var.apply_immediately}"
  publicly_accessible     = "${var.publicly_accessible}"
  storage_encrypted       = "${var.storage_encrypted}"
  maintenance_window      = "${var.maintenance_window}"
  # backup_retention_period = "${var.backup_retention_period}"
  # backup_window           = "${var.backup_window}"

  # final_snapshot_identifier = "${var.name}"
  # snapshot_identifier     = "EXISTING_SNAPSHOT_ID"
  vpc_security_group_ids    = ["${aws_security_group.rds.id}"]
  db_subnet_group_name      = "${aws_db_subnet_group.rds.id}"
}

output "endpoint" { value = "${aws_db_instance.master.endpoint}" }
output "username" { value = "${var.username}" }
output "password" { value = "${var.password}" }
