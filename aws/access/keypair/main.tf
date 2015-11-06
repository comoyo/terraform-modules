variable "name" {}
variable "pub_path" {}

resource "aws_key_pair" "key" {
  key_name   = "${var.name}"
  public_key = "${file("${var.pub_path}")}"
}

output "key_name" { value = "${aws_key_pair.key.key_name}" }
