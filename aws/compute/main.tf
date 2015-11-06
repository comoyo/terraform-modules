variable "name" {}
variable "vpc_cidr" {}
variable "azs" {}
variable "domain" {}
variable "vpc_id" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "key_name" {}
variable "key_path" {}
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

variable "web_instance_type" {}
variable "web_blue_ami" {}
variable "web_blue_nodes" {}
variable "web_green_ami" {}
variable "web_green_nodes" {}

module "web" {
  source = "./web"

  name               = "${var.name}-web"
  vpc_cidr           = "${var.vpc_cidr}"
  azs                = "${var.azs}"
  domain             = "${var.domain}"
  key_name           = "${var.key_name}"
  key_path           = "${var.key_path}"
  vpc_id             = "${var.vpc_id}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids  = "${var.public_subnet_ids}"
  ssl_cert_crt       = "${var.ssl_cert_crt}"
  ssl_cert_key       = "${var.ssl_cert_key}"
  bastion_host       = "${var.bastion_host}"
  bastion_user       = "${var.bastion_user}"

  user_data         = "${var.user_data}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  consul_ips        = "${var.consul_ips}"

  db_endpoint = "${var.db_endpoint}"
  db_username = "${var.db_username}"
  db_password = "${var.db_password}"
  db_name     = "${var.db_name}"

  redis_host     = "${var.redis_host}"
  redis_port     = "${var.redis_port}"
  redis_password = "${var.redis_password}"

  vault_private_ip   = "${var.vault_private_ip}"
  vault_domain       = "${var.vault_domain}"

  rabbitmq_host     = "${var.rabbitmq_host}"
  rabbitmq_port     = "${var.rabbitmq_port}"
  rabbitmq_username = "${var.rabbitmq_username}"
  rabbitmq_password = "${var.rabbitmq_password}"
  rabbitmq_vhost    = "${var.rabbitmq_vhost}"

  instance_type = "${var.web_instance_type}"
  blue_ami      = "${var.web_blue_ami}"
  blue_nodes    = "${var.web_blue_nodes}"
  green_ami     = "${var.web_green_ami}"
  green_nodes   = "${var.web_green_nodes}"
}

output "web_dns_name" { value = "${module.web.dns_name}" }
output "web_zone_id"  { value = "${module.web.zone_id}" }

output "remote_commands" {
  value = <<COMMANDS
${module.web.remote_commands}
COMMANDS
}
