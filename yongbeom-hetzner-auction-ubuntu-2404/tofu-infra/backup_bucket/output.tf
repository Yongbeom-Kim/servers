output "b2_bucket_name" {
  description = "Created Backblaze B2 bucket name"
  value       = b2_bucket.backup.bucket_name
}

output "r2_bucket_name" {
  description = "Created Cloudflare R2 bucket name"
  value       = cloudflare_r2_bucket.backup.name
}
