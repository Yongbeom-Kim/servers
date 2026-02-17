variable "public_ipv4" {
  description = "Public IPv4 address for the service"
  type        = string
}

variable "public_ipv6" {
  description = "Public IPv6 address for the service"
  type        = string
}

module "aws-dns" {
  source           = "./aws-dns-record"
  hosted_zone_name = "yongbeom.net"
  for_each = toset([
    "auth.yongbeom.net",
    "links.yongbeom.net",
    "drive.yongbeom.net",
    "pw.yongbeom.net",
    "bao.yongbeom.net",
    "photos.yongbeom.net",
    "notion.yongbeom.net",
    "v1.notion.yongbeom.net",
  ])
  domain           = each.value
  public_ipv4      = var.public_ipv4
  public_ipv6      = var.public_ipv6
}
