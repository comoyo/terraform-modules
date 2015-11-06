variable "name" {}
variable "azs" {}
variable "key_name" {}
variable "key_path" {}
variable "vpc_id" {}
variable "vpc_cidr" {}

variable "private_subnet_ids" {}
variable "ephemeral_subnet_ids" {}
variable "public_subnet_ids" {}

variable "consul_server_user_data" {}
variable "vault_user_data" {}
variable "rabbitmq_user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}

variable "db_name" {}
variable "db_username" {}
variable "db_password" {}
variable "db_engine" {}
variable "db_engine_version" {}
variable "db_port" {}

variable "db_az" {}
variable "db_multi_az" {}
variable "db_instance_type" {}
variable "db_storage_gbs" {}
variable "db_iops" {}
variable "db_storage_type" {}
variable "db_apply_immediately" {}
variable "db_publicly_accessible" {}
variable "db_storage_encrypted" {}
variable "db_maintenance_window" {}
variable "db_backup_retention_period" {}
variable "db_backup_window" {}

variable "redis_instance_type" {}
variable "redis_port" {}
variable "redis_initial_cached_nodes" {}
variable "redis_apply_immediately" {}
variable "redis_maintenance_window" {}

variable "ssl_cert_name" {}
variable "ssl_cert_crt" {}
variable "ssl_cert_key" {}
variable "bastion_host" {}
variable "bastion_user" {}

variable "consul_instance_type" {}
variable "consul_amis" {}
variable "consul_ips" {}

variable "vault_count" {}
variable "vault_instance_type" {}
variable "vault_amis" {}

variable "rabbitmq_count" {}
variable "rabbitmq_instance_type" {}
variable "rabbitmq_amis" {}
# variable "rabbitmq_blue_ami" {}
# variable "rabbitmq_blue_nodes" {}
# variable "rabbitmq_green_ami" {}
# variable "rabbitmq_green_nodes" {}
variable "rabbitmq_username" {}
variable "rabbitmq_password" {}
variable "rabbitmq_vhost" {}

module "rds_postgres" {
  source = "./rds"

  name           = "${var.name}-postgres"
  vpc_id         = "${var.vpc_id}"
  vpc_cidr       = "${var.vpc_cidr}"
  subnet_ids     = "${var.private_subnet_ids}"
  db_name        = "${var.db_name}"
  username       = "${var.db_username}"
  password       = "${var.db_password}"
  engine         = "${var.db_engine}"
  engine_version = "${var.db_engine_version}"
  port           = "${var.db_port}"

  az                      = "${var.db_az}"
  multi_az                = "${var.db_multi_az}"
  instance_type           = "${var.db_instance_type}"
  storage_gbs             = "${var.db_storage_gbs}"
  iops                    = "${var.db_iops}"
  storage_type            = "${var.db_storage_type}"
  apply_immediately       = "${var.db_apply_immediately}"
  publicly_accessible     = "${var.db_publicly_accessible}"
  storage_encrypted       = "${var.db_storage_encrypted}"
  maintenance_window      = "${var.db_maintenance_window}"
  backup_retention_period = "${var.db_backup_retention_period}"
  backup_window           = "${var.db_backup_window}"
}

module "ec_redis" {
  source = "./elasticache"

  name                 = "${var.name}-redis"
  vpc_id               = "${var.vpc_id}"
  vpc_cidr             = "${var.vpc_cidr}"
  subnet_ids           = "${var.ephemeral_subnet_ids}"
  instance_type        = "${var.redis_instance_type}"
  port                 = "${var.redis_port}"
  initial_cached_nodes = "${var.redis_initial_cached_nodes}"
  apply_immediately    = "${var.redis_apply_immediately}"
  maintenance_window   = "${var.redis_maintenance_window}"
}

module "consul" {
  source = "./consul"

  name          = "${var.name}-consul"
  vpc_id        = "${var.vpc_id}"
  vpc_cidr      = "${var.vpc_cidr}"
  static_ips    = "${var.consul_ips}"
  subnet_ids    = "${var.private_subnet_ids}"
  instance_type = "${var.consul_instance_type}"
  amis          = "${var.consul_amis}"

  key_name     = "${var.key_name}"
  key_path     = "${var.key_path}"
  bastion_host = "${var.bastion_host}"
  bastion_user = "${var.bastion_user}"

  user_data         = "${var.consul_server_user_data}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
}

module "vault" {
  source = "./vault"

  name               = "${var.name}-vault"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  azs                = "${var.azs}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids  = "${var.public_subnet_ids}"
  count              = "${var.vault_count}"
  instance_type      = "${var.vault_instance_type}"
  amis               = "${var.vault_amis}"

  ssl_cert_name = "${var.ssl_cert_name}"
  ssl_cert_crt  = "${var.ssl_cert_crt}"
  ssl_cert_key  = "${var.ssl_cert_key}"
  key_name      = "${var.key_name}"
  key_path      = "${var.key_path}"
  bastion_host  = "${var.bastion_host}"
  bastion_user  = "${var.bastion_user}"

  user_data         = "${var.vault_user_data}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  consul_ips        = "${var.consul_ips}"
}

module "rabbitmq" {
  source = "./rabbitmq"

  name               = "${var.name}-rabbitmq"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  azs                = "${var.azs}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids  = "${var.public_subnet_ids}"
  count              = "${var.rabbitmq_count}"
  instance_type      = "${var.rabbitmq_instance_type}"
  count              = "${var.rabbitmq_count}"
  amis               = "${var.rabbitmq_amis}"
  # blue_ami           = "${var.rabbitmq_blue_ami}"
  # blue_nodes         = "${var.rabbitmq_blue_nodes}"
  # green_ami          = "${var.rabbitmq_green_ami}"
  # green_nodes        = "${var.rabbitmq_green_nodes}"

  ssl_cert_crt = "${var.ssl_cert_crt}"
  ssl_cert_key = "${var.ssl_cert_key}"
  key_name     = "${var.key_name}"
  key_path     = "${var.key_path}"
  bastion_host = "${var.bastion_host}"
  bastion_user = "${var.bastion_user}"

  user_data         = "${var.rabbitmq_user_data}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"

  username = "${var.rabbitmq_username}"
  password = "${var.rabbitmq_password}"
  vhost    = "${var.rabbitmq_vhost}"
}

output "db_endpoint" { value = "${module.rds_postgres.endpoint}" }
output "db_username" { value = "${module.rds_postgres.username}" }
output "db_password" { value = "${module.rds_postgres.password}" }

output "redis_host"     { value = "${module.ec_redis.host}" }
output "redis_port"     { value = "${module.ec_redis.port}" }
output "redis_password" { value = "${module.ec_redis.password}" }

output "rabbitmq_host"        { value = "${module.rabbitmq.host}" }
output "rabbitmq_port"        { value = "${module.rabbitmq.port}" }
output "rabbitmq_username"    { value = "${module.rabbitmq.username}" }
output "rabbitmq_password"    { value = "${module.rabbitmq.password}" }
output "rabbitmq_vhost"       { value = "${module.rabbitmq.vhost}" }

output "consul_ips" { value = "${module.consul.consul_ips}" }

output "vault_dns_name"    { value = "${module.vault.dns_name}" }
output "vault_private_ips" { value = "${module.vault.private_ips}" }

output "remote_commands" {
  value = <<COMMANDS
${module.rabbitmq.remote_commands}
COMMANDS
}
