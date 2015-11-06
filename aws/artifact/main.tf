variable "type" { default = "amazon.ami" }
variable "atlas_username" {}
variable "latest_name"    {}
variable "pinned_name"    {}
variable "pinned_version" { default = "latest" }

resource "atlas_artifact" "latest" {
  name = "${var.atlas_username}/${var.latest_name}"
  type = "${var.type}"
  version = "latest"
}

resource "atlas_artifact" "pinned" {
  name = "${var.atlas_username}/${var.pinned_name}"
  type = "${var.type}"
  version = "${var.pinned_version}"
}

output "latest" { value = "${atlas_artifact.latest.metadata_full.region-us-east-1}" }
output "pinned" { value = "${atlas_artifact.pinned.metadata_full.region-us-east-1}" }
