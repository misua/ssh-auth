#!/bin/bash
# get-ssh-cert-userpass.sh - Get SSH certificate using Vault userpass authentication

set -e

# Get the actual Vault address from environment if it exists
CURRENT_VAULT_ADDR=$(env | grep VAULT_ADDR | cut -d= -f2)

# Default configuration
VAULT_ADDR=${CURRENT_VAULT_ADDR:-"http://10.0.10.88:8200"}
SSH_KEY_PATH=${SSH_KEY_PATH:-"$HOME/.ssh/id_rsa"}
SSH_CERT_PATH="${SSH_KEY_PATH}-cert.pub"
ENVIRONMENT=${ENVIRONMENT:-"prod"}
VALID_PRINCIPALS=${VALID_PRINCIPALS:-"${ENVIRONMENT}-admin"}
TTL=${TTL:-"24h"}

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -a, --vault-addr ADDR     Vault server address (default: $VAULT_ADDR)"
    echo "  -k, --key-path PATH       Path to SSH key (default: $SSH_KEY_PATH)"
    echo "  -e, --environment ENV     Environment (prod, dev, staging) (default: $ENVIRONMENT)"
    echo "  -p, --principals PRINC    Valid principals (default: $VALID_PRINCIPALS)"
    echo "  -t, --ttl DURATION        Certificate TTL (default: $TTL)"
    echo "  -u, --username USER       Vault username (required)"
    echo "  -h, --help                Show this help message"
    echo
    echo "Example:"
    echo "  $0 -u admin -e prod"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--vault-addr)
            VAULT_ADDR="$2"
            shift 2
            ;;
        -k|--key-path)
            SSH_KEY_PATH="$2"
            SSH_CERT_PATH="${SSH_KEY_PATH}-${ENVIRONMENT}-cert.pub"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            VALID_PRINCIPALS="${ENVIRONMENT}-admin"
            shift 2
            ;;
        -p|--principals)
            VALID_PRINCIPALS="$2"
            shift 2
            ;;
        -t|--ttl)
            TTL="$2"
            shift 2
            ;;
        -u|--username)
            VAULT_USER="$2"
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

# Check if username is provided
if [ -z "$VAULT_USER" ]; then
    echo "Error: Vault username is required"
    show_help
fi

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

# Check for vault command
if ! command -v vault &> /dev/null; then
    echo "Vault CLI not found. Please install it first."
    exit 1
fi

# Read the public key
SSH_PUB_KEY_CONTENT=$(cat "${SSH_KEY_PATH}.pub")

# Authenticate to Vault
echo "Authenticating to Vault at $VAULT_ADDR as $VAULT_USER..."
echo "Please enter your password: "
read -s VAULT_PASS

# Get token from Vault
export VAULT_ADDR
TOKEN=$(vault login -method=userpass \
    username="$VAULT_USER" \
    password="$VAULT_PASS" -format=json | jq -r '.auth.client_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Authentication failed!"
    exit 1
fi

echo "Authentication successful!"

# Sign the public key
echo "Signing your SSH key for environment: $ENVIRONMENT"
echo "Using principals: $VALID_PRINCIPALS"
echo "Certificate TTL: $TTL"

# Set the token for vault command
export VAULT_TOKEN="$TOKEN"

# Sign the key
SIGN_RESULT=$(vault write -format=json ssh-client-signer/sign/${ENVIRONMENT} \
    public_key="$SSH_PUB_KEY_CONTENT" \
    valid_principals="$VALID_PRINCIPALS" \
    ttl="$TTL" \
    key_id="$USER@${ENVIRONMENT}")

# Extract the signed key
SIGNED_KEY=$(echo "$SIGN_RESULT" | jq -r '.data.signed_key')

if [ -z "$SIGNED_KEY" ] || [ "$SIGNED_KEY" = "null" ]; then
    echo "Failed to sign key. Error: $(echo "$SIGN_RESULT" | jq -r '.errors // "Unknown error"')"
    exit 1
fi

# Log certificate issuance
if command -v log-ssh-cert &> /dev/null; then
    # If the log-ssh-cert script is available (on Vault server), use it
    log-ssh-cert "$VAULT_USER" "$ENVIRONMENT" "$VALID_PRINCIPALS" "$TTL"
else
    # Otherwise log locally
    LOG_DIR="$HOME/.ssh/cert_logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/ssh_cert_issuance.log"
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP - Certificate issued: User=$VAULT_USER, Env=$ENVIRONMENT, Principals=$VALID_PRINCIPALS, TTL=$TTL, SourceIP=$(hostname -I | awk '{print $1}')" >> "$LOG_FILE"
fi

# Save the signed key
echo "$SIGNED_KEY" > "$SSH_CERT_PATH"
chmod 644 "$SSH_CERT_PATH"

echo "Certificate saved to $SSH_CERT_PATH"
echo "Certificate is valid for $TTL"
echo "To use this certificate, make sure it's in your ~/.ssh directory"
echo "Your SSH client should automatically use it when connecting"

# Display certificate information
echo "Certificate details:"
ssh-keygen -L -f "$SSH_CERT_PATH"
