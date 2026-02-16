data "aws_route53_zone" "selected" {
  name         = "${var.hosted_zone_name}."
  private_zone = false
}

resource "aws_route53_record" "service_a" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain
  type    = "A"
  ttl     = var.ttl
  records = [var.public_ipv4]
}

resource "aws_route53_record" "service_aaaa" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain
  type    = "AAAA"
  ttl     = var.ttl
  records = [var.public_ipv6]
}

resource "aws_route53_record" "service_www_a" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${var.domain}"
  type    = "A"
  ttl     = var.ttl
  records = [var.public_ipv4]
}

resource "aws_route53_record" "service_www_aaaa" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${var.domain}"
  type    = "AAAA"
  ttl     = var.ttl
  records = [var.public_ipv6]
}
