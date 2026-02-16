output "route53_zone_id" {
  description = "Route53 hosted zone ID used for record creation"
  value       = data.aws_route53_zone.selected.zone_id
}

output "a_record_fqdn" {
  description = "FQDN of the created A record"
  value       = aws_route53_record.service_a.fqdn
}

output "aaaa_record_fqdn" {
  description = "FQDN of the created AAAA record"
  value       = aws_route53_record.service_aaaa.fqdn
}
