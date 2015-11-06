variable "name" { default = "openvpn" }
variable "ami" {}
variable "instance_type" {}
variable "key_name" {}
variable "admin_user" {}
variable "admin_pw" {}
variable "dns_ips" { default = "" }
variable "vpn_cidr" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "ssl_cert" {}
variable "ssl_key" {}
variable "subnet_ids" {}
variable "key_path" {}
variable "bastion_host" {}
variable "bastion_user" {}

resource "aws_security_group" "openvpn" {
  name   = "${var.name}"
  vpc_id = "${var.vpc_id}"
  description = "OpenVPN security group"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # For OpenVPN Client Web Server & Admin Web UI
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "udp"
    from_port   = 1194
    to_port     = 1194
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "openvpn" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type}"
  key_name               = "${var.key_name}"
  subnet_id              = "${element(split(",", var.subnet_ids), count.index)}"
  vpc_security_group_ids = ["${aws_security_group.openvpn.id}"]

  tags { Name = "${var.name}" }

  user_data = <<USERDATA
admin_user=${var.admin_user}
admin_pw=${var.admin_pw}
USERDATA

  provisioner "remote-exec" {
    connection {
      user         = "openvpnas"
      host         = "${self.private_ip}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }
    inline = [
      # Insert our SSL cert
      "echo '${file("${var.ssl_cert}")}' | sudo tee /usr/local/openvpn_as/etc/web-ssl/server.crt > /dev/null",
      "echo '${file("${var.ssl_key}")}' | sudo tee /usr/local/openvpn_as/etc/web-ssl/server.key > /dev/null",
      # Turn on custom DNS
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.client.routing.reroute_dns -v custom ConfigPut",
      # Point custom DNS at consul
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.server.dhcp_option.dns.0 -v ${element(split(",", var.dns_ips), 0)} ConfigPut",
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.server.dhcp_option.dns.1 -v ${element(split(",", var.dns_ips), 1)} ConfigPut",
      # Set VPN network info
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.network -v ${element(split("/", var.vpn_cidr), 0)} ConfigPut",
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.daemon.0.client.netmask_bits -v ${element(split("/", var.vpn_cidr), 1)} ConfigPut",
      # Do a warm restart so the config is picked up
      "sudo /usr/local/openvpn_as/scripts/sacli start",
    ]
  }
}

output "ip" { value = "${aws_instance.openvpn.public_ip}" }
output "user" { value = "ubuntu" }
