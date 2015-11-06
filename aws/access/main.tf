variable "name" {}
variable "iam_admins" {}
variable "pub_path" {}

module "iam" {
  source = "./iam"

  name   = "${var.name}"
  admins = "${var.iam_admins}"
}

module "keypair" {
  source = "./keypair"

  name     = "${var.name}"
  pub_path = "${var.pub_path}"
}

output "admin_users"              { value = "${module.iam.admin_users}" }
output "admin_access_key_ids"     { value = "${module.iam.admin_access_key_ids}" }
output "admin_secret_access_keys" { value = "${module.iam.admin_secret_access_keys}" }

output "key_name" { value = "${module.keypair.key_name}" }
