output "private_key_pem" {
  value     = trimspace(tls_private_key.ecdsa-p384.private_key_pem)
  sensitive = true
}

output "public_key_pem" {
  value     = trimspace(tls_private_key.ecdsa-p384.public_key_pem)
  sensitive = false
}

output "public_key_openssh" {
  value     = trimspace(tls_private_key.ecdsa-p384.public_key_openssh)
  sensitive = false
}
