variable "name" {}
variable "directory" {}

output "name"          { value = "${var.name}" }
output "crt_path"      { value = "${var.directory}/${var.name}.crt" }
output "key_path"      { value = "${var.directory}/${var.name}.key" }
