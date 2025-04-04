#!/bin/bash
set -e

# Install necessary packages
apt-get update
apt-get install -y curl jq unzip

# Install Vault
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install -y vault

# Configure Vault
cat > /etc/vault.d/vault.hcl << EOF
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true" # Only for demo purposes, use TLS in production
}

api_addr = "http://$(hostname -I | awk '{print $1}'):8200"
ui = true

# Log configuration
log_level = "info"
EOF

# Create data directories
mkdir -p /opt/vault/data
mkdir -p /var/log/vault
chown -R vault:vault /opt/vault
chown -R vault:vault /var/log/vault

# Start Vault service
systemctl enable vault
systemctl start vault
sleep 10

# Initialize and unseal Vault (simplified for demo)
export VAULT_ADDR="http://127.0.0.1:8200"

# Initialize Vault
vault operator init -key-shares=1 -key-threshold=1 > /root/vault-init.txt

# Extract root token and unseal key
VAULT_TOKEN=$(grep "Initial Root Token" /root/vault-init.txt | awk '{print $NF}')
UNSEAL_KEY=$(grep "Unseal Key 1" /root/vault-init.txt | awk '{print $NF}')

# Unseal Vault
vault operator unseal $UNSEAL_KEY

# Set token for subsequent operations
export VAULT_TOKEN=$VAULT_TOKEN

# Enable audit logging
vault audit enable file file_path=/var/log/vault/audit.log

# Install CloudWatch agent for centralized logging
apt-get install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/vault/audit.log",
            "log_group_name": "vault-audit-logs",
            "log_stream_name": "{instance_id}-audit",
            "retention_in_days": 30
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Enable userpass authentication
vault auth enable userpass

# Create admin user
vault write auth/userpass/users/admin password=adminpassword policies=admin

# Create admin policy
cat > /tmp/admin-policy.hcl << EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

vault policy write admin /tmp/admin-policy.hcl

# Enable SSH secrets engine
vault secrets enable -path=ssh-client-signer ssh

# Create SSH CA
vault write ssh-client-signer/config/ca generate_signing_key=true

# Get SSH CA public key
vault read -field=public_key ssh-client-signer/config/ca > /etc/ssh/trusted-user-ca-key.pub

# Create SSH certificate issuance logging script
cat > /usr/local/bin/log-ssh-cert << 'EOF'
#!/bin/bash
# Log SSH certificate issuance

LOG_FILE="/var/log/vault/ssh-certs.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
USERNAME="$1"
ENVIRONMENT="$2"
PRINCIPALS="$3"
TTL="$4"

echo "$TIMESTAMP - Certificate issued: User=$USERNAME, Env=$ENVIRONMENT, Principals=$PRINCIPALS, TTL=$TTL" >> $LOG_FILE
EOF

chmod +x /usr/local/bin/log-ssh-cert

# Create roles for different environments
%{ for env in environments ~}
# Create role for ${env} environment
vault write ssh-client-signer/roles/${env} -<<EOF
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "default_extensions": {
    "permit-pty": ""
  },
  "key_type": "ca",
  "default_user": "ubuntu",
  "ttl": "24h"
}
EOF

# Create policy for ${env} environment
cat > /tmp/${env}-policy.hcl << EOF
path "ssh-client-signer/sign/${env}" {
  capabilities = ["create", "update"]
}
EOF

vault policy write ${env} /tmp/${env}-policy.hcl

# Create ${env} user
vault write auth/userpass/users/${env}-user password=${env}password policies=${env}
%{ endfor ~}

# Output SSH CA public key (this would be retrieved in a real-world scenario)
echo "SSH CA Public Key:"
cat /etc/ssh/trusted-user-ca-key.pub
