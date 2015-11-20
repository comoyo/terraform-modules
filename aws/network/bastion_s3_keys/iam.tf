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

//resource "aws_iam_role_policy" "bastion_s3_policy" {
//    name = "${var.instance_profile_name}-s3-policy"
//    role = "${aws_iam_role.bastion.id}"
//    policy = <<EOF
//{
//    "Version": "2012-10-17",
//    "Statement": [
//        {
//            "Sid": "Stmt1425916919000",
//            "Effect": "Allow",
//            "Action": [
//                "s3:List*",
//                "s3:Get*"
//            ],
//            "Resource": "*"
//        }
//    ]
//}
//EOF
//}