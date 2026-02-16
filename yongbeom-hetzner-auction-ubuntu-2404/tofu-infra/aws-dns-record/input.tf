variable "hosted_zone_name" {
  description = "Public Route53 hosted zone name (apex), e.g. yongbeom.net"
  type        = string
}

variable "domain" {
  description = "FQDN for the service record, e.g. links.yongbeom.net"
  type        = string
}

variable "public_ipv4" {
  description = "Public IPv4 address for the service"
  type        = string
}

variable "public_ipv6" {
  description = "Public IPv6 address for the service"
  type        = string
}

variable "ttl" {
  description = "DNS TTL in seconds"
  type        = number
  default     = 300
}
