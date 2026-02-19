terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = ">= 0.12"
    }
  }
}

variable "aws_region" {
  description = "AWS region for Route53"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  # API token via CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY
}

provider "b2" {
  # B2_APPLICATION_KEY_ID and B2_APPLICATION_KEY
}

variable "public_ipv4" {
  description = "Public IPv4 address for the service"
  type        = string
}

variable "public_ipv6" {
  description = "Public IPv6 address for the service"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID used for R2 bucket creation"
  type        = string
  default     = ""
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
  domain      = each.value
  public_ipv4 = var.public_ipv4
  public_ipv6 = var.public_ipv6
}

module "backup_bucket" {
  source                = "./backup_bucket"
  for_each              = toset([
    "backup-auth-yongbeom-net",
    "backup-links-yongbeom-net",
    # "drive.yongbeom.net", # TODO: Research NextCloud Backup
    "backup-pw-yongbeom-net",
    "backup-bao-yongbeom-net",
    "backup-photos-yongbeom-net", # TODO
    # "notion.yongbeom.net", # TODO: low priority
    # "v1.notion.yongbeom.net", # TODO: low priority
  ])
  cloudflare_account_id = var.cloudflare_account_id
  bucket_name           = each.value
}
