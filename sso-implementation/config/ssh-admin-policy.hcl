# Policy for SSH CA administrators

# Allow full management of the SSH CA
path "ssh-client-signer/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow reading and listing auth methods
path "auth/*" {
  capabilities = ["read", "list"]
}

# Allow managing policies related to SSH
path "sys/policies/acl/ssh-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow access to audit logging configuration
path "sys/audit*" {
  capabilities = ["read", "list"]
}

# Allow listing audit devices
path "sys/audit" {
  capabilities = ["read", "list"]
}

# Allow viewing audit logs in UI
path "sys/audit-hash/*" {
  capabilities = ["read"]
}
