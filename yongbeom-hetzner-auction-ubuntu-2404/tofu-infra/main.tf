variable "public_ipv4" {
  description = "Public IPv4 address for the service"
  type        = string
}

variable "public_ipv6" {
  description = "Public IPv6 address for the service"
  type        = string
}

module "aws-dns" {
  source            = "./aws-dns-record"
  hosted_zone_name  = "yongbeom.net"
  domain            = "auth.yongbeom.net"
  public_ipv4       = var.public_ipv4
  public_ipv6       = var.public_ipv6
}