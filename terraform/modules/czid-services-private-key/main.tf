# Private key used to authenticate the user so they can use the GraphQL federated service & next-gen service
# >> openssl ecparam -name secp384r1 -genkey -noout -out czid-private-key.pem

locals {
  secret_name    = "${var.env}/czid-services-private-key"
  rotate_version = "1" // Increment this to rotate the secret
}

# TODO: Upgrade to a newer tls provider that supports ephemeral
# ephemeral "tls_private_key" "ecdsa-p384" {
#   algorithm   = "ECDSA"
#   ecdsa_curve = "P384"
# }

# Generate an ECDSA private key with the secp384r1 curve
resource "tls_private_key" "ecdsa-p384" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "aws_secretsmanager_secret" "services_private_key_pem" {
  name                    = local.secret_name
  description             = "Private key used to authenticate the user so they can use the GraphQL federated service & next-gen service >> openssl ecparam -name secp384r1 -genkey -noout -out czid-private-key.pem"
  recovery_window_in_days = 0 # Forces immediate deletion
}

resource "aws_secretsmanager_secret_version" "api_key_version" {
  secret_id                = aws_secretsmanager_secret.services_private_key_pem.id
  secret_string_wo         = trimspace(tls_private_key.ecdsa-p384.private_key_pem)
  secret_string_wo_version = local.rotate_version
}
