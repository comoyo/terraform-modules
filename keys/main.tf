variable "name" {}
variable "directory" {}

output "name"          { value = "${var.name}" }
output "pem_path"      { value = "${var.directory}/${var.name}.pem" }
output "pub_path"      { value = "${var.directory}/${var.name}.pub" }
