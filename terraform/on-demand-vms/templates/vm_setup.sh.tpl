#!/bin/bash
set -e

# Install necessary packages
apt-get update
apt-get install -y curl jq unzip

# Configure SSH to trust the CA
echo "${vault_ca_pub_key}" > /etc/ssh/trusted-user-ca-key.pub
chmod 644 /etc/ssh/trusted-user-ca-key.pub

# Configure SSH to use the CA for verification
cat > /etc/ssh/sshd_config.d/ca.conf << EOC
# SSH CA Configuration
TrustedUserCAKeys /etc/ssh/trusted-user-ca-key.pub
EOC

# Create the authorized principals directory
mkdir -p /etc/ssh/auth_principals

# Create role-based authorized principals files
echo "${environment}-admin" > /etc/ssh/auth_principals/ubuntu
echo "${environment}-admin" > /etc/ssh/auth_principals/root

# Create user-specific principal if provided
if [ "${username}" != "" ]; then
  echo "${username}" > /etc/ssh/auth_principals/ubuntu
fi

# Update sshd_config to use authorized principals
cat > /etc/ssh/sshd_config.d/principals.conf << EOC
# Authorized principals configuration
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
EOC

# Configure enhanced SSH logging
cat > /etc/ssh/sshd_config.d/logging.conf << EOC
# Enhanced SSH logging configuration
LogLevel VERBOSE
SyslogFacility AUTH
PrintLastLog yes
EOC

# Restart SSH to apply changes
systemctl restart sshd

# Create a welcome message
cat > /etc/motd << EOC
=======================================================
  On-demand VM created for: ${username}
  Environment: ${environment}
  Created on: $(date)
=======================================================
EOC
