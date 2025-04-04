#!/bin/bash
# vault-ssh-helper.sh - Helper script for obtaining SSH certificates from Vault

set -e

# Default values
VAULT_ADDR=${VAULT_ADDR:-"https://vault.example.com:8200"}
TTL=${TTL:-"24h"}
ENVIRONMENT=${ENVIRONMENT:-"prod"}

function print_usage() {
  echo "Usage: $(basename $0) [options]"
  echo "Options:"
  echo "  -k, --key PATH       Path to your SSH public key (default: ~/.ssh/id_rsa.pub)"
  echo "  -u, --username USER  Your username (default: current user)"
  echo "  -e, --env ENV        Environment (dev, staging, prod) (default: prod)"
  echo "  -v, --vault URL      Vault server URL (default: https://vault.example.com:8200)"
  echo "  -t, --ttl TTL        Certificate validity period (default: 24h)"
  echo "  -h, --help           Show this help message"
  echo
  echo "Example:"
  echo "  $(basename $0) --key ~/.ssh/id_ed25519.pub --env dev --ttl 12h"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -k|--key)
      SSH_KEY_PATH="$2"
      shift 2
      ;;
    -u|--username)
      USERNAME="$2"
      shift 2
      ;;
    -e|--env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -v|--vault)
      VAULT_ADDR="$2"
      shift 2
      ;;
    -t|--ttl)
      TTL="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Set defaults if not provided
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/id_rsa.pub"}
USERNAME=${USERNAME:-"$(whoami)"}

# Check if key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Error: SSH public key not found at $SSH_KEY_PATH"
  echo "Generate an SSH key pair first with: ssh-keygen -t rsa -b 4096"
  exit 1
fi

# Check if Vault CLI is installed
if ! command -v vault &> /dev/null; then
  echo "Error: Vault CLI not found"
  echo "Please install Vault CLI: https://www.vaultproject.io/downloads"
  exit 1
fi

# Read the public key
SSH_PUB_KEY_CONTENT=$(cat "$SSH_KEY_PATH")

echo "Requesting SSH certificate from Vault ($VAULT_ADDR)"
echo "Environment: $ENVIRONMENT"
echo "Key: $SSH_KEY_PATH"
echo "Username: $USERNAME"
echo "TTL: $TTL"
echo

# Login to Vault
echo "Please authenticate to Vault..."
vault login -method=userpass

# Sign the public key
echo "Signing your SSH key..."
vault write -format=json ssh-client-signer/sign/${ENVIRONMENT} \
  public_key="$SSH_PUB_KEY_CONTENT" \
  valid_principals="${ENVIRONMENT}-admin" \
  ttl="$TTL" \
  key_id="$USERNAME@${ENVIRONMENT}" > /tmp/vault-ssh-cert.json

# Extract and save the signed certificate
SIGNED_KEY=$(cat /tmp/vault-ssh-cert.json | jq -r '.data.signed_key')
CERT_FILE="${SSH_KEY_PATH/.pub/-${ENVIRONMENT}-cert.pub}"
echo "$SIGNED_KEY" > "$CERT_FILE"
chmod 600 "$CERT_FILE"
rm /tmp/vault-ssh-cert.json

echo "Success! Certificate saved to $CERT_FILE"
echo "Certificate is valid for $TTL"
echo
echo "To use this certificate:"
echo "ssh -i ${SSH_KEY_PATH/.pub/} ubuntu@JUMPBOX_IP"
echo
echo "Your SSH client should automatically use the certificate during authentication"
