#!/bin/bash
# configure-jumpbox.sh - Script to configure a jumpbox with SSH CA and user restrictions

set -e

echo "=== Setting up SSH CA configuration on jumpbox ==="

# Create the shared ssh-developer account
if ! id ssh-developer &>/dev/null; then
    echo "Creating ssh-developer user..."
    useradd -m ssh-developer -s /bin/bash
    passwd -l ssh-developer # Lock password authentication
fi

# Set up SSH directories
mkdir -p /etc/ssh/auth_principals
mkdir -p /etc/ssh/trusted_user_ca_keys.d

# Download the CA public key from Vault (assuming this is run from a system with Vault access)
echo "Downloading CA public key from Vault..."
if [ -n "$VAULT_ADDR" ] && [ -n "$VAULT_TOKEN" ]; then
    # Use provided Vault credentials
    curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
        -X GET ${VAULT_ADDR}/v1/ssh-client-signer/public_key | jq -r '.data.public_key' \
        > /etc/ssh/trusted_user_ca_keys.d/vault-ssh-ca.pub
else
    echo "No Vault credentials found. Please manually copy the CA public key to:"
    echo "/etc/ssh/trusted_user_ca_keys.d/vault-ssh-ca.pub"
fi

# Configure SSH to trust the CA
cat > /etc/ssh/sshd_config.d/ca.conf << 'EOF'
# SSH Certificate Authority Configuration
TrustedUserCAKeys /etc/ssh/trusted_user_ca_keys.d/vault-ssh-ca.pub
EOF

# Create authorized principals file for ssh-developer user
echo "Setting up authorized principals..."
echo "developer-access" > /etc/ssh/auth_principals/ssh-developer

# Configure SSH to use authorized principals
cat > /etc/ssh/sshd_config.d/principals.conf << 'EOF'
# Authorized principals configuration
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
EOF

# Set up user restrictions
echo "Configuring user restrictions..."
cat > /etc/ssh/sshd_config.d/restrictions.conf << 'EOF'
# User restrictions for ssh-developer
Match User ssh-developer
    ForceCommand /usr/local/bin/ssh-audit-wrapper.sh
    PermitTTY yes
    X11Forwarding no
    AllowAgentForwarding no
    PermitTunnel no
    AllowStreamLocalForwarding no
EOF

# Create wrapper script for auditing
cat > /usr/local/bin/ssh-audit-wrapper.sh << 'EOF'
#!/bin/bash

# Extract certificate ID and other metadata from SSH_CERTIFICATES env var
CERT_ID="${SSH_CERTIFICATE_IDENTITY:-Unknown}"
CERT_PRINCIPALS="${SSH_CERTIFICATE_PRINCIPALS:-Unknown}"

# Log access with detailed information
logger -p auth.info "SSH ACCESS: User=${USER} Remote=${SSH_CLIENT%% *} CertID=${CERT_ID} Principals=${CERT_PRINCIPALS}"

# Display notice to user
cat << 'NOTICE'
=======================================================================
                          NOTICE TO USERS
This system is restricted to authorized users for business purposes only.
All actions are logged and monitored.
=======================================================================
NOTICE

# Execute user's default shell
exec bash --login
EOF

chmod +x /usr/local/bin/ssh-audit-wrapper.sh

# Set up enhanced logging
echo "Configuring enhanced SSH logging..."
cat > /etc/ssh/sshd_config.d/logging.conf << 'EOF'
# Enhanced logging configuration
LogLevel VERBOSE
SyslogFacility AUTH
EOF

# Set up log forwarding to a central log server (if provided)
if [ -n "$LOG_SERVER" ]; then
    echo "Configuring log forwarding to $LOG_SERVER..."
    cat > /etc/rsyslog.d/90-ssh-forward.conf << EOF
# Forward SSH logs to central server
auth.* @${LOG_SERVER}:514
EOF
    systemctl restart rsyslog
fi

# Set immutable attributes on key files to prevent modification
echo "Setting immutable attributes on key files..."
chattr +i /etc/ssh/sshd_config.d/*.conf
chattr +i /etc/ssh/auth_principals/ssh-developer
chattr +i /etc/ssh/trusted_user_ca_keys.d/vault-ssh-ca.pub
chattr +i /usr/local/bin/ssh-audit-wrapper.sh

# Restart SSH to apply changes
echo "Restarting SSH service..."
systemctl restart sshd

echo "=== Jumpbox configuration complete ==="
echo "Use the following principal when signing certificates:"
echo "developer-access"
