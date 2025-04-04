# Policy for developers to sign SSH certificates

# Allow reading the SSH CA configuration (public key)
path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}

# Allow signing SSH keys with the developer role
path "ssh-client-signer/sign/developer" {
  capabilities = ["create", "update"]
}

# Allow reading the public CA certificate
path "ssh-client-signer/public_key" {
  capabilities = ["read"]
}

# Deny all other access
path "*" {
  capabilities = ["deny"]
}
