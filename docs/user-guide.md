# SSH Certificate Authority with HashiCorp Vault - User Guide

This guide provides instructions on how to use the SSH Certificate Authority (CA) system built with HashiCorp Vault. It covers how to access the system, authenticate with Vault, obtain SSH certificates, and connect to target servers.

## Table of Contents

1. [System Overview](#system-overview)
2. [Accessing the Jumpbox](#accessing-the-jumpbox)
3. [Authenticating with Vault](#authenticating-with-vault)
4. [Obtaining SSH Certificates](#obtaining-ssh-certificates)
5. [Automation Scripts](#automation-scripts)
6. [Connecting to Target Servers](#connecting-to-target-servers)
7. [Monitoring and Audit Logging](#monitoring-and-audit-logging)
8. [Troubleshooting](#troubleshooting)

## System Overview

The SSH CA system uses HashiCorp Vault to issue short-lived SSH certificates instead of traditional SSH keys. This provides several advantages:

- Centralized access control
- Short-lived credentials (typically 24 hours)
- Detailed audit logging
- No need to distribute and manage SSH keys on target servers

The system consists of:
- **Vault Server**: Issues SSH certificates
- **Jumpbox**: Entry point to access internal resources
- **Logging Server**: Collects and visualizes audit logs

## Accessing the Jumpbox

### Prerequisites

- Your SSH public key must be registered with the system administrator
- You need the IP address of the jumpbox
- You need your assigned username

### SSH to Jumpbox

```bash
# Using your SSH key
ssh ubuntu@<jumpbox-ip>

# Example
ssh ubuntu@10.0.10.131
```

## Authenticating with Vault

Once connected to the jumpbox, you need to authenticate with Vault to obtain SSH certificates.

### Setting the Vault Address

```bash
# Set the Vault address environment variable
export VAULT_ADDR=http://127.0.0.1:8200
```

### Login with Token

If you have a Vault token:

```bash
# Login with your token
vault login
# Enter your token when prompted
```

### Login with Username/Password

If you're using username/password authentication:

```bash
# Login with username and password
vault login -method=userpass username=<your-username>
# Enter your password when prompted
```

### Verify Authentication

```bash
# Verify you're authenticated
vault token lookup
```

## Obtaining SSH Certificates

After authenticating with Vault, you can request an SSH certificate.

### Generate an SSH Key Pair (if needed)

If you don't already have an SSH key pair:

```bash
# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

### Request a Certificate for Your Public Key

```bash
# Request a certificate for your public key
vault write -field=signed_key ssh-client-signer/sign/dev-admin \
    public_key=@$HOME/.ssh/id_rsa.pub > ~/.ssh/id_rsa-cert.pub

# Verify the certificate
ssh-keygen -Lf ~/.ssh/id_rsa-cert.pub
```

## Automation Scripts

Several automation scripts are available to simplify the certificate request process:

#### Local Certificate Request (UserPass Authentication)

The `get-ssh-cert-userpass.sh` script automates certificate requests when you're already on the jumpbox:

```bash
# Request a certificate using username/password authentication
./scripts/get-ssh-cert-userpass.sh -u your-username -e prod

# With custom options
./scripts/get-ssh-cert-userpass.sh \
  -u your-username \
  -a http://10.0.10.88:8200 \
  -k ~/.ssh/custom_key \
  -e prod \
  -p "prod-admin" \
  -t 12h
```

#### Remote Certificate Request (Through Jumpbox)

The `get-cert-remote.sh` script allows you to request certificates without first logging into the jumpbox:

```bash
# Request a certificate remotely
./scripts/get-cert-remote.sh -j jumpbox-public-ip -b ~/.ssh/bastion-key.pem

# With custom options
./scripts/get-cert-remote.sh \
  -j jumpbox-public-ip \
  -b ~/.ssh/bastion-key.pem \
  -k ~/.ssh/custom_key \
  -e prod \
  -t 12h \
  -u your-username \
  -p your-password
```

#### SSO Implementation Scripts

For environments with SSO integration:

```bash
# Get certificate using AWS SSO
./sso-implementation/scripts/get-ssh-cert-aws.sh

# Get certificate using Azure SSO
./sso-implementation/scripts/get-ssh-cert-azure.sh
```

## Connecting to Target Servers

With your signed certificate, you can now connect to target servers.

### Direct Connection

```bash
# Connect to a target server
ssh -i ~/.ssh/id_rsa -i ~/.ssh/id_rsa-cert.pub ubuntu@<target-server-ip>

# Example
ssh -i ~/.ssh/id_rsa -i ~/.ssh/id_rsa-cert.pub ubuntu@10.0.11.10
```

### Using SSH Config

For convenience, you can set up an SSH config file:

```bash
# Create or edit your SSH config
cat >> ~/.ssh/config << EOF
Host vault
  HostName vault.internal
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes

Host logging
  HostName logging.internal
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
EOF

# Now you can connect using the alias
ssh vault
ssh logging
```

## Monitoring and Audit Logging

### Accessing the Logging Dashboard

The logging dashboard provides visibility into SSH access across your infrastructure.

1. SSH to the jumpbox
2. Access the Grafana dashboard:
   ```bash
   # SSH to the logging server
   ssh logging
   
   # Or access via web browser (if configured)
   # http://<logging-server-ip>:3000
   ```
3. Login with the default credentials:
   - Username: `admin`
   - Password: `admin`
   
4. Navigate to the SSH CA Dashboard

### Viewing Audit Logs

```bash
# On the logging server
docker logs loki

# View SSH logs
sudo journalctl -u sshd
```

## Troubleshooting

### Certificate Issues

If your certificate is rejected:

1. Verify the certificate is valid:
   ```bash
   ssh-keygen -Lf ~/.ssh/id_rsa-cert.pub
   ```

2. Check the certificate expiration date
3. Ensure you're using the correct key pair
4. Request a new certificate if needed

### Vault Connection Issues

If you can't connect to Vault:

1. Verify the Vault address:
   ```bash
   echo $VAULT_ADDR
   ```

2. Check if Vault is running:
   ```bash
   curl $VAULT_ADDR/v1/sys/health
   ```

3. Ensure Vault is unsealed:
   ```bash
   vault status
   ```

### SSH Connection Issues

If you can't SSH to target servers:

1. Verify your certificate is valid
2. Check that the target server is running
3. Ensure the target server is configured to trust the CA
4. Verify network connectivity:
   ```bash
   ping <target-server-ip>
   ```

### Getting Help

Contact your system administrator if you continue to experience issues.
