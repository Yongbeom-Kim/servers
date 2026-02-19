variable "cloudflare_account_id" {
  description = "Cloudflare account ID used for R2 bucket creation"
  type        = string

  validation {
    condition     = trimspace(var.cloudflare_account_id) != ""
    error_message = "cloudflare_account_id must be set."
  }
}

variable "bucket_name" {
  description = "Shared bucket name used for both Backblaze B2 and Cloudflare R2"
  type        = string

  validation {
    condition     = trimspace(var.bucket_name) != ""
    error_message = "bucket_name must be set."
  }
}

variable "b2_bucket_type" {
  description = "Backblaze B2 bucket type"
  type        = string
  default     = "allPrivate"
}
