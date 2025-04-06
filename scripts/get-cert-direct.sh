#!/bin/bash
# get-cert-direct.sh - Get SSH certificate by directly signing with the Vault CA

set -e

# Default configuration
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
ENVIRONMENT="prod"
TTL="24h"

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -k, --key PATH          Path to your SSH key (default: $SSH_KEY_PATH)"
    echo "  -e, --environment ENV   Environment (prod, dev, staging) (default: $ENVIRONMENT)"
    echo "  -t, --ttl DURATION      Certificate TTL (default: $TTL)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Example:"
    echo "  $0 -e prod"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key)
            SSH_KEY_PATH="$2"
            SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--ttl)
            TTL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if SSH public key exists
if [ ! -f "$SSH_PUB_KEY" ]; then
    echo "SSH public key not found at $SSH_PUB_KEY"
    echo "Generating a new SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

# Get the public key content
SSH_PUB_KEY_CONTENT=$(cat $SSH_PUB_KEY)

echo "Signing your SSH key directly..."
echo "Environment: $ENVIRONMENT"
echo "TTL: $TTL"

# Create a temporary file for the certificate
TEMP_CERT=$(mktemp)

# Connect to the jumpbox and sign the key
echo "Connecting to jumpbox to sign your key..."
ssh -i ~/Desktop/bastion1.pem ubuntu@54.221.104.251 "
# Create a temporary file for the public key
echo '$SSH_PUB_KEY_CONTENT' > /tmp/user_key.pub

# Use the built-in helper script to sign the key
/usr/local/bin/get-ssh-cert -e $ENVIRONMENT -t $TTL -k /tmp/user_key.pub
cat /tmp/user_key-cert.pub
" > $TEMP_CERT

# Check if the certificate was created successfully
if [ ! -s "$TEMP_CERT" ]; then
    echo "Failed to sign SSH key!"
    rm $TEMP_CERT
    exit 1
fi

# Move the certificate to the correct location
SSH_CERT_PATH="${SSH_KEY_PATH}-cert.pub"
mv $TEMP_CERT $SSH_CERT_PATH
chmod 644 $SSH_CERT_PATH

echo "SSH certificate created successfully at $SSH_CERT_PATH"
echo "You can now SSH to servers in the $ENVIRONMENT environment using:"
echo "ssh -i $SSH_KEY_PATH ubuntu@<server-ip>"
