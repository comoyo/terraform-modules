variable "name" { default = "consul" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "static_ips" {}
variable "subnet_ids" {}
variable "instance_type" {}
variable "amis" {}

variable "key_name" {}
variable "key_path" {}
variable "bastion_host" {}
variable "bastion_user" {}

variable "user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}

resource "aws_security_group" "consul" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Consul"

  tags { Name = "${var.name}" }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "template_file" "user_data" {
  filename = "${var.user_data}"
  count    = "${length(split(",", var.static_ips))}"

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    consul_server_count = "${length(split(",", var.static_ips))}"
    node_name           = "${var.name}.${count.index+1}"
    service             = "${var.name}"
  }
}

resource "aws_instance" "consul" {
  ami           = "${element(split(",", var.amis), count.index)}"
  count         = "${length(split(",", var.static_ips))}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  private_ip    = "${element(split(",", var.static_ips), count.index)}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

resource "null_resource" "consul_ready" {
  count      = "${length(split(",", var.static_ips))}"
  depends_on = ["aws_instance.consul"]

  provisioner "remote-exec" {
    connection {
      user         = "ubuntu"
      host         = "${element(aws_instance.consul.*.private_ip, count.index)}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }

    inline = [ <<COMMANDS
#!/bin/bash
set -e

# Report that Consul is ready to use. Consul's KV store is used in
# Vault setup and other places, set a ready value in its KV store
# to signify that it is ready.
SLEEPTIME=1
cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/consul/ready?raw"; }

# Wait for the Consul cluster to become ready
while ! cget | grep "true"; do
  if [ $SLEEPTIME -ge 24 ]; then
    echo "ERROR: CONSUL DID NOT COMPLETE SETUP! Manual intervention required on node ${element(aws_instance.consul.*.private_ip, count.index)}."
    exit 2
  else
    echo "Blocking until Consul is ready, waiting $SLEEPTIME second(s)..."
    consul join ${replace(var.static_ips, ",", " ")}
    curl -XPUT http://127.0.0.1:8500/v1/kv/service/consul/ready -d true
    sleep $SLEEPTIME
    ((SLEEPTIME+=1))
  fi
done

echo "Consul is ready!"

COMMANDS ]
  }
}

output "security_group_id" { value = "${aws_security_group.consul.id}" }
output "consul_ips" { value = "${join(",", aws_instance.consul.*.private_ip)}" }
