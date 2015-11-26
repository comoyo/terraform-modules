resource "aws_iam_instance_profile" "bastion" {
    name = "${var.instance_profile_name}"
    roles = ["${aws_iam_role.bastion.name}"]
}

resource "aws_iam_role" "bastion" {
    name = "${var.instance_profile_name}"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
