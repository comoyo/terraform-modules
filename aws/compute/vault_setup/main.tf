variable "name" { default = "compute" }
variable "vault_private_ip" {}
variable "key_path" {}
variable "bastion_host" {}
variable "bastion_user" {}
variable "consul_ips" {}

resource "null_resource" "vault_setup" {
  provisioner "remote-exec" {
    connection {
      user         = "ubuntu"
      host         = "${var.vault_private_ip}"
      key_file     = "${var.key_path}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }

    inline = [ <<COMMANDS
#!/bin/bash
set -e

# Join Consul cluster
consul join ${replace(var.consul_ips, ",", " ")}

# Wait for Vault to become ready
SLEEPTIME=1
cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

while ! cget ready | grep "true"; do
  if [ $SLEEPTIME -gt 24 ]; then
    echo "ERROR: VAULT SETUP NOT COMPLETE! Manual intervention required."
    exit 2
  else
    echo "Blocking until Vault is ready, waiting $SLEEPTIME second(s)..."
    sleep $SLEEPTIME
    ((SLEEPTIME+=1))
  fi
done

echo "Authenticating as root..."
cget root-token | vault auth -

echo "Adding web policy..."
(cat <<POLICY
# Allow renewal of leases for secrets
path "sys/renew/*" {
  policy = "write"
}

# Allow renewal of token leases
path "auth/token/renew/*" {
  policy = "write"
}

path "transit/encrypt/${var.name}_*" {
  policy = "write"
}

path "transit/decrypt/${var.name}_*" {
  policy = "write"
}
POLICY
) > /tmp/${var.name}-policy.hcl

echo "Writing Vault policy..."
vault policy-write ${var.name} /tmp/${var.name}-policy.hcl

echo "Creating Vault token..."
TOKEN=$(vault token-create -policy=${var.name} | grep ^token[^_] | awk '{print $2}')

echo "Saving Vault token to Consul"
curl -XPUT http://127.0.0.1:8500/v1/kv/service/${var.name}/vault-token -d $TOKEN

if [ -e ~/.vault-token ]; then
  echo "Shredding vault-token"
  shred -u -z ~/.vault-token
fi
COMMANDS ]
  }
}
