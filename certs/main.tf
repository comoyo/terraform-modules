variable "name" {}

output "name"          { value = "${var.name}" }
output "crt_path"      { value = "${path.module}/${var.name}.crt" }
output "key_path"      { value = "${path.module}/${var.name}.key" }
