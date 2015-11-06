variable "name" {}

output "name"          { value = "${var.name}" }
output "pem_path"      { value = "${path.module}/${var.name}.pem" }
output "pub_path"      { value = "${path.module}/${var.name}.pub" }
