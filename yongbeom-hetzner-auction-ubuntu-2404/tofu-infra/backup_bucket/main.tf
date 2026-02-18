terraform {
  required_providers {
    b2 = {
      source = "Backblaze/b2"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

resource "b2_bucket" "backup" {
  bucket_name = var.bucket_name
  bucket_type = var.b2_bucket_type
}

resource "cloudflare_r2_bucket" "backup" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
}
