variable "domain" {}
variable "web_dns_name" {}
variable "web_zone_id" {}
variable "vault_dns_name" {}
variable "vpn_ip" {}

resource "aws_route53_zone" "mod" {
  name = "${var.domain}"
}

resource "aws_route53_record" "main" {
  zone_id = "${aws_route53_zone.mod.id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${var.web_dns_name}"
    zone_id                = "${var.web_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "vault" {
  zone_id = "${aws_route53_zone.mod.id}"
  name    = "vault.${var.domain}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${var.vault_dns_name}"]
}

resource "aws_route53_record" "vpn" {
  zone_id = "${aws_route53_zone.mod.id}"
  name    = "vpn.${var.domain}"
  type    = "A"
  ttl     = "60"
  records = ["${var.vpn_ip}"]
}

output "vpn" { value = "${aws_route53_record.vpn.fqdn}" }
output "main" { value = "${aws_route53_record.main.fqdn}" }
output "ns1" { value = "${aws_route53_zone.mod.name_servers.0}" }
output "ns2" { value = "${aws_route53_zone.mod.name_servers.1}" }
output "ns3" { value = "${aws_route53_zone.mod.name_servers.2}" }
output "ns4" { value = "${aws_route53_zone.mod.name_servers.3}" }
