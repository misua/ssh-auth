#!/bin/bash
# get-ssh-cert-aws.sh - Get SSH certificate using AWS IAM authentication

set -e

# Configuration
VAULT_ADDR=${VAULT_ADDR:-"https://vault.example.com:8200"}
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/id_rsa"}
SSH_CERT_PATH="${SSH_KEY_PATH}-cert.pub"
ROLE=${ROLE:-"developer"}

# Check if SSH key exists
if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    echo "SSH key not found at ${SSH_KEY_PATH}.pub"
    read -p "Would you like to generate a new SSH key? (y/n): " generate_key
    if [[ "$generate_key" == "y" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
        echo "SSH key generated at $SSH_KEY_PATH"
    else
        echo "Please create an SSH key and try again"
        exit 1
    fi
fi

# Check for AWS CLI and credentials
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it first."
    exit 1
fi

# Verify AWS credentials are available
aws sts get-caller-identity &>/dev/null
if [ $? -ne 0 ]; then
    echo "AWS credentials not found or invalid."
    echo "Please configure your AWS credentials using:"
    echo "aws configure"
    exit 1
fi

# Get AWS account info for display
aws_identity=$(aws sts get-caller-identity)
aws_account=$(echo "$aws_identity" | jq -r '.Account')
aws_user=$(echo "$aws_identity" | jq -r '.Arn' | sed 's/.*\///')

echo "Using AWS identity: $aws_user in account $aws_account"

# Authenticate to Vault using AWS IAM
echo "Authenticating to Vault using AWS IAM..."
iam_response=$(vault login -method=aws -format=json role="$ROLE")

if [ $? -ne 0 ]; then
    echo "Authentication failed."
    exit 1
fi

# Extract token
VAULT_TOKEN=$(echo "$iam_response" | jq -r '.auth.client_token')
export VAULT_TOKEN

# Extract identity information
display_name=$(echo "$iam_response" | jq -r '.auth.metadata.canonical_arn' | sed 's/.*\///')

echo "Authenticated as: $display_name"

# Read public key
SSH_PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Sign public key
echo "Requesting SSH certificate from Vault..."
sign_response=$(vault write -format=json "ssh-client-signer/sign/${ROLE}" \
    public_key="$SSH_PUB_KEY" \
    valid_principals="developer-access")

if [ $? -ne 0 ]; then
    echo "Failed to sign SSH key."
    exit 1
fi

# Save the certificate
signed_key=$(echo "$sign_response" | jq -r '.data.signed_key')
echo "$signed_key" > "$SSH_CERT_PATH"
chmod 600 "$SSH_CERT_PATH"

# Extract and display certificate details
serial=$(echo "$sign_response" | jq -r '.data.serial_number')
key_id=$(echo "$sign_response" | jq -r '.data.key_id')
valid_until=$(ssh-keygen -L -f "$SSH_CERT_PATH" | grep "Valid:" | awk -F': ' '{print $2}' | awk -F' to ' '{print $2}')

echo
echo "==== SSH Certificate Details ===="
echo "Certificate ID: $key_id"
echo "Serial Number: $serial"
echo "Valid Until: $valid_until"
echo "Saved to: $SSH_CERT_PATH"
echo
echo "You can now connect using: ssh ssh-developer@jumpbox-hostname"
echo "Your access will be logged with your identity: $aws_user"

# Clean up token
vault token revoke -self >/dev/null 2>&1
