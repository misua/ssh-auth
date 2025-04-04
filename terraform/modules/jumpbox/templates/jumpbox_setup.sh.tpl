#!/bin/bash
set -e

# Install necessary packages
apt-get update
apt-get install -y curl jq unzip

# Install CloudWatch agent for centralized logging
apt-get install -y amazon-cloudwatch-agent

# Configure SSH to trust the CA
echo "${vault_ca_pub_key}" > /etc/ssh/trusted-user-ca-key.pub
chmod 644 /etc/ssh/trusted-user-ca-key.pub

# Configure SSH to use the CA for verification
cat > /etc/ssh/sshd_config.d/ca.conf << EOF
# SSH CA Configuration
TrustedUserCAKeys /etc/ssh/trusted-user-ca-key.pub
EOF

# Create the authorized principals directory
mkdir -p /etc/ssh/auth_principals

# Create role-based authorized principals files
# This file lists the principals (roles) that are allowed to connect as this user
echo "${environment}-admin" > /etc/ssh/auth_principals/ubuntu
echo "${environment}-admin" > /etc/ssh/auth_principals/root

# Update sshd_config to use authorized principals
cat > /etc/ssh/sshd_config.d/principals.conf << EOF
# Authorized principals configuration
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
EOF

# Configure enhanced SSH logging
cat > /etc/ssh/sshd_config.d/logging.conf << EOF
# Enhanced SSH logging configuration
LogLevel VERBOSE
SyslogFacility AUTH
PrintLastLog yes

# Log all accepted and rejected connections
AcceptEnv LANG LC_*
PrintMotd no

# Enable audit logging for SSH sessions
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
EOF

# Configure CloudWatch agent for SSH logs
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "ssh-auth-logs",
            "log_stream_name": "{instance_id}-auth",
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

# Create SSH certificate logs directory
mkdir -p /var/log/ssh-certs
chmod 755 /var/log/ssh-certs

# Set proper permissions
chmod 755 /etc/ssh/auth_principals
chmod 644 /etc/ssh/auth_principals/*

# Restart SSH service
systemctl restart sshd

# Add vault server to /etc/hosts
echo "${vault_ip} vault.internal" >> /etc/hosts

# Install Vault client for testing
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install -y vault

# Create a helper script for users to obtain certificates
cat > /usr/local/bin/get-ssh-cert << 'EOF'
#!/bin/bash
set -e

# Default values
VAULT_ADDR="http://vault.internal:8200"
ROLE="${environment}"
TTL="24h"

# Check if a key is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-ssh-public-key> [username]"
    echo "Example: $0 ~/.ssh/id_rsa.pub john.doe"
    exit 1
fi

SSH_PUB_KEY=$1
USERNAME=$${2:-$USER}

# Authenticate to Vault
echo "Authenticating to Vault..."
echo "Please enter your Vault username: "
read VAULT_USER
echo "Please enter your password: "
read -s VAULT_PASS

# Get token from Vault
TOKEN=$$(curl -s \
    --request POST \
    --data "{\\"password\\": \\"$VAULT_PASS\\"}" \
    $VAULT_ADDR/v1/auth/userpass/login/$VAULT_USER | jq -r '.auth.client_token')

if [ "$TOKEN" = "null" ]; then
    echo "Authentication failed!"
    exit 1
fi

echo "Authentication successful!"

# Read the public key
SSH_PUB_KEY_CONTENT=$$(cat $SSH_PUB_KEY)

# Sign the public key
echo "Signing your SSH key..."
SIGN_RESULT=$$(curl -s \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data "{
        \\"public_key\\": \\"$SSH_PUB_KEY_CONTENT\\",
        \\"valid_principals\\": \\"${environment}-admin\\",
        \\"ttl\\": \\"$TTL\\"
    }" \
    $VAULT_ADDR/v1/ssh-client-signer/sign/${environment})

# Extract the signed key
SIGNED_KEY=$$(echo $SIGN_RESULT | jq -r '.data.signed_key')

if [ "$SIGNED_KEY" = "null" ]; then
    echo "Failed to sign key. Error: $$(echo $SIGN_RESULT | jq -r '.errors')"
    exit 1
fi

# Log certificate issuance
LOG_DIR="/var/log/ssh-certs"
LOG_FILE="$LOG_DIR/issuance.log"
TIMESTAMP=$$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP - Certificate issued: User=$VAULT_USER, Env=${environment}, Principals=${environment}-admin, TTL=$TTL, SourceIP=$$(hostname -I | awk '{print \$1}')" | sudo tee -a $LOG_FILE > /dev/null

# Save the signed key
CERT_FILE="$${SSH_PUB_KEY/.pub/-${environment}-cert.pub}"
echo "$SIGNED_KEY" > $CERT_FILE
chmod 644 $CERT_FILE

echo "Certificate saved to $CERT_FILE"
echo "Certificate is valid for $TTL"
echo "To use this certificate, make sure it's in your ~/.ssh directory"
echo "Your SSH client should automatically use it when connecting"
EOF

chmod +x /usr/local/bin/get-ssh-cert

# Create a readme file with instructions
cat > /home/ubuntu/README.md << EOF
# SSH Certificate Authentication

This jump box is configured to use SSH certificates for authentication. 
To access this server, you need to:

1. Generate an SSH key pair on your local machine (if you don't have one)
   \`\`\`
   ssh-keygen -t rsa -b 4096
   \`\`\`

2. Request a signed certificate from Vault:
   a. Connect to this jumpbox using a temporary method (e.g., AWS Systems Manager Session Manager)
   b. Run the helper script:
      \`\`\`
      get-ssh-cert ~/.ssh/id_rsa.pub your-username
      \`\`\`

3. Once you have a certificate, you can SSH directly:
   \`\`\`
   ssh ubuntu@<jumpbox-ip>
   \`\`\`

Your certificate will be valid for 24 hours. After that, you'll need to request a new one.

## Benefits of SSH certificates:

- No need to distribute or manage authorized_keys files
- Certificates automatically expire after a set time
- Role-based access control through Vault
- Centralized management and auditing
EOF

# Make sure readme is owned by ubuntu user
chown ubuntu:ubuntu /home/ubuntu/README.md
