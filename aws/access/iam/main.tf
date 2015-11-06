variable "name" {}
variable "admins" {}

resource "aws_iam_group" "admins" {
  name = "${var.name}-admins"
}

resource "aws_iam_group_policy" "admins" {
  name   = "${var.name}-admins"
  group  = "${aws_iam_group.admins.id}"
  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Effect"  : "Allow",
      "Action"  : "*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "admins" {
  name   = "${element(split(",", var.admins), count.index)}"
  count  = "${length(split(",", var.admins))}"
}

resource "aws_iam_access_key" "admins" {
  user = "${element(aws_iam_user.admins.*.name, count.index)}"
  count  = "${length(split(",", var.admins))}"
}

resource "aws_iam_group_membership" "admins" {
  name  = "${var.name}-admins"
  group = "${aws_iam_group.admins.name}"
  users = ["${aws_iam_user.admins.*.name}"]
}

output "admin_users" { value = "${join(",", aws_iam_access_key.admins.*.user)}" }
output "admin_access_key_ids" { value = "${join(",", aws_iam_access_key.admins.*.id)}" }
output "admin_secret_access_keys" { value = "${join(",", aws_iam_access_key.admins.*.secret)}" }
output "admin_statuses" { value = "${join(",", aws_iam_access_key.admins.*.status)}" }
