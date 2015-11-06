variable "name" { default = "vault" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "azs" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "count" {}
variable "instance_type" {}
variable "amis" {}

variable "ssl_cert_name" {}
variable "ssl_cert_crt" {}
variable "ssl_cert_key" {}
variable "key_name" {}
variable "key_path" {}
variable "bastion_host" {}
variable "bastion_user" {}

variable "user_data" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "consul_ips" {}

resource "aws_security_group" "vault" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Vault"

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
  count    = "${var.count}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    service           = "${var.name}"
    node_name         = "${var.name}.${count.index+1}"
    cert_name         = "${var.ssl_cert_name}"
  }
}

resource "aws_instance" "vault" {
  ami           = "${element(split(",", var.amis), count.index)}"
  count         = "${var.count}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.private_subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.vault.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

resource "null_resource" "vault_init" {
  provisioner "remote-exec" {
    connection {
      user         = "ubuntu"
      host         = "${element(aws_instance.vault.*.private_ip, 0)}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }

    inline = [ <<COMMANDS
#!/bin/bash
set -e

# Join Consul cluster
consul join ${replace(var.consul_ips, ",", " ")}

# Remote commands utilize Consul's KV store, wait until ready
SLEEPTIME=1
cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/consul/ready?raw"; }

# Wait for the Consul cluster to become ready
while ! cget | grep "true"; do
  if [ $SLEEPTIME -gt 24 ]; then
    echo "ERROR: CONSUL DID NOT COMPLETE SETUP! Manual intervention required."
    exit 2
  else
    echo "Blocking until Consul is ready, waiting $SLEEPTIME second(s)..."
    sleep $SLEEPTIME
    ((SLEEPTIME+=1))
  fi
done

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

if [ ! $(cget root-token) ]; then
  echo "Initialize Vault"
  vault init | tee /tmp/vault.init > /dev/null

  # Store master keys in consul for operator to retrieve and remove
  i=1
  cat /tmp/vault.init | grep '^Key' | awk '{print $3}' | for key in $(cat -); do
    curl -fX PUT 127.0.0.1:8500/v1/kv/service/vault/unseal-key-$i -d $key
    ((i = i + 1))
  done

  export ROOT_TOKEN=$(cat /tmp/vault.init | grep '^Initial' | awk '{print $4}')
  curl -fX PUT 127.0.0.1:8500/v1/kv/service/vault/root-token -d $ROOT_TOKEN

  # Remove master keys from disk
  shred /tmp/vault.init
else
  echo "Vault has already been initialized, skipping"
fi
COMMANDS ]
  }
}

resource "null_resource" "vault_unseal" {
  count = "${var.count}"
  depends_on = ["null_resource.vault_init"]

  provisioner "remote-exec" {
    connection {
      user         = "ubuntu"
      host         = "${element(aws_instance.vault.*.private_ip, count.index)}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }

    inline = [ <<COMMANDS
#!/bin/bash
set -e

# Join Consul cluster
consul join ${replace(var.consul_ips, ",", " ")}

# Remote commands utilize Consul's KV store, wait until ready
SLEEPTIME=1
cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/consul/ready?raw"; }

# Wait for the Consul cluster to become ready
while ! cget | grep "true"; do
  if [ $SLEEPTIME -gt 24 ]; then
    echo "ERROR: CONSUL DID NOT COMPLETE SETUP! Manual intervention required."
    exit 2
  else
    echo "Blocking until Consul is ready, waiting $SLEEPTIME second(s)..."
    sleep $SLEEPTIME
    ((SLEEPTIME+=1))
  fi
done

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

echo "Unsealing Vault"
vault unseal $(cget unseal-key-1)
vault unseal $(cget unseal-key-2)
vault unseal $(cget unseal-key-3)
COMMANDS ]
  }
}

resource "null_resource" "vault_mount_transit" {
  count = "${var.count}"
  depends_on = ["null_resource.vault_unseal"]

  provisioner "remote-exec" {
    connection {
      user         = "ubuntu"
      host         = "${element(aws_instance.vault.*.private_ip, count.index)}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }

    inline = [ <<COMMANDS
#!/bin/bash
set -e

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

if vault status | grep standby > /dev/null; then
  echo "Mounts only run on the leader. Exiting."
  exit 0
fi

cget root-token | vault auth -
vault mount transit
shred -u -z ~/.vault-token

# Report that vault is ready to use. This is used over in app setup to
# wait for vault to be ready before inserting the vault policy.
curl -XPUT http://127.0.0.1:8500/v1/kv/service/vault/ready -d true
COMMANDS ]
  }
}

resource "aws_security_group" "elb" {
  name   = "${var.name}-elb"
  vpc_id = "${var.vpc_id}"
  description = "Security group for Vault ELB"

  tags { Name = "${var.name}-elb" }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_server_certificate" "vault" {
  name             = "${var.name}"
  certificate_body = "${file("${var.ssl_cert_crt}")}"
  private_key      = "${file("${var.ssl_cert_key}")}"

  provisioner "local-exec" {
    command = <<EOF
      echo "Sleep 10 secends so that mycert is propagated by aws iam service"
      echo "See https://github.com/hashicorp/terraform/issues/2499 (terraform ~v0.6.1)"
      sleep 10
EOF
  }
}

resource "aws_elb" "vault" {
  name                        = "${var.name}"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = true

  subnets         = ["${split(",", var.public_subnet_ids)}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.vault.*.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "tcp"
    instance_port     = 8200
    instance_protocol = "tcp"
  }

  listener {
    lb_port           = 443
    lb_protocol       = "tcp"
    instance_port     = 8200
    instance_protocol = "tcp"
    # There is a bug with setting ssl_certificate_id right now. When it's not set,
    # you will see TLS warnings every 5 minutes in the Vault logs due to the load
    # balancer not using the proper version of TLS when doing health checks.
    # ssl_certificate_id = "${aws_iam_server_certificate.vault.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    target              = "HTTPS:8200/v1/sys/health"
  }
}

output "dns_name" { value = "${aws_elb.vault.dns_name}" }
output "private_ips" { value = "${join(",", aws_instance.vault.*.private_ip)}" }
output "instructions" {
  value = <<EOF

We use an instance of HashiCorp Vault for secrets management.

It has been automatically initialized and unsealed once. Future unsealing must
be done manually.

The unseal keys and root token have been temporarily stored in Consul K/V.

  /service/vault/root-token
  /service/vault/unseal-key-{1..5}

Please securely distribute and record these secrets and remove them from Consul.
EOF }
