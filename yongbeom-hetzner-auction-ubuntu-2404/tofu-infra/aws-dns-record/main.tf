variable "passphrase" {
  # Change passphrase to be at least 16 characters long:
  default   = "changeme!"
  sensitive = true
}

terraform {
  encryption {
    key_provider "pbkdf2" "my_key_provider_name" {
      passphrase = var.passphrase
    }
    method "aes_gcm" "my_method_name" {
      keys = key_provider.pbkdf2.my_key_provider_name
    }

    state {
      method = method.aes_gcm.my_method_name
    }
  }
}