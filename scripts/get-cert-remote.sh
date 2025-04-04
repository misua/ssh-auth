#!/bin/bash
# get-cert-remote.sh - Get SSH certificate by connecting through a jumpbox

set -e

# Default configuration
JUMPBOX_IP=""
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
JUMPBOX_KEY_PATH=""
ENVIRONMENT="prod"
TTL="24h"
VAULT_USER="admin"
VAULT_PASS="adminpassword"  # Default password, can be changed with -p option

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -j, --jumpbox IP        Jumpbox public IP address (required)"
    echo "  -k, --key PATH          Path to your SSH key (default: $SSH_KEY_PATH)"
    echo "  -b, --bastion PATH      Path to your jumpbox/bastion SSH key (required)"
    echo "  -e, --environment ENV   Environment (prod, dev, staging) (default: $ENVIRONMENT)"
    echo "  -t, --ttl DURATION      Certificate TTL (default: $TTL)"
    echo "  -u, --username USER     Vault username (default: admin)"
    echo "  -p, --password PASS     Vault password (default: adminpassword)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Example:"
    echo "  $0 -j 54.12.34.56 -b ~/.ssh/bastion1.pem"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--jumpbox)
            JUMPBOX_IP="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY_PATH="$2"
            SSH_PUB_KEY="${SSH_KEY_PATH}.pub"
            shift 2
            ;;
        -b|--bastion)
            JUMPBOX_KEY_PATH="$2"
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
        -u|--username)
            VAULT_USER="$2"
            shift 2
            ;;
        -p|--password)
            VAULT_PASS="$2"
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

# Check required parameters
if [ -z "$JUMPBOX_IP" ]; then
    echo "Error: Jumpbox IP is required"
    show_help
fi

if [ -z "$JUMPBOX_KEY_PATH" ]; then
    echo "Error: Jumpbox SSH key path is required"
    show_help
fi

# Check if SSH key exists
if [ ! -f "$SSH_PUB_KEY" ]; then
    echo "SSH public key not found at $SSH_PUB_KEY"
    read -p "Would you like to generate a new SSH key? (y/n): " generate_key
    if [[ "$generate_key" == "y" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
        echo "SSH key generated at $SSH_KEY_PATH"
    else
        echo "Please create an SSH key and try again"
        exit 1
    fi
fi

# Create a temporary script to run on the jumpbox
TEMP_SCRIPT=$(mktemp)
cat > $TEMP_SCRIPT << EOF
#!/bin/bash
# Temporary script to get SSH certificate on jumpbox

# Save the public key
cat > /tmp/user_key.pub << 'PUBKEY'
$(cat $SSH_PUB_KEY)
PUBKEY

# Set Vault address
export VAULT_ADDR="http://10.0.10.88:8200"

# Login to Vault
echo "Authenticating to Vault..."
VAULT_TOKEN=\$(vault login -method=userpass username="$VAULT_USER" password="$VAULT_PASS" -format=json | jq -r '.auth.client_token')

if [ -z "\$VAULT_TOKEN" ] || [ "\$VAULT_TOKEN" = "null" ]; then
    echo "Authentication failed!"
    exit 1
fi

echo "Authentication successful!"

# Sign the key
echo "Signing your SSH key for environment: $ENVIRONMENT"
export VAULT_TOKEN="\$VAULT_TOKEN"

SIGN_RESULT=\$(vault write -format=json ssh-client-signer/sign/$ENVIRONMENT \
    public_key=@/tmp/user_key.pub \
    valid_principals="$ENVIRONMENT-admin" \
    ttl="$TTL")

# Extract the signed key
SIGNED_KEY=\$(echo "\$SIGN_RESULT" | jq -r '.data.signed_key')

if [ -z "\$SIGNED_KEY" ] || [ "\$SIGNED_KEY" = "null" ]; then
    echo "Failed to sign key. Error: \$(echo "\$SIGN_RESULT" | jq -r '.errors // "Unknown error"')"
    exit 1
fi

# Log certificate issuance
if command -v log-ssh-cert &> /dev/null; then
    # If the log-ssh-cert script is available (on Vault server), use it
    log-ssh-cert "$VAULT_USER" "$ENVIRONMENT" "$ENVIRONMENT-admin" "$TTL"
else
    # Otherwise log locally
    LOG_DIR="\$HOME/.ssh/cert_logs"
    mkdir -p "\$LOG_DIR"
    LOG_FILE="\$LOG_DIR/ssh_cert_issuance.log"
    TIMESTAMP=\$(date +"%Y-%m-%d %H:%M:%S")
    echo "\$TIMESTAMP - Certificate issued: User=$VAULT_USER, Env=$ENVIRONMENT, Principals=$ENVIRONMENT-admin, TTL=$TTL, SourceIP=\$(hostname -I | awk '{print \$1}'), RequestedFrom=$(hostname -I | awk '{print $1}')" >> "\$LOG_FILE"
fi

# Save the signed key
echo "\$SIGNED_KEY" > /tmp/signed_cert.pub
echo "Certificate generated successfully!"

# Display certificate information
echo "Certificate details:"
ssh-keygen -L -f /tmp/signed_cert.pub
EOF

chmod +x $TEMP_SCRIPT

# Log locally that we're requesting a certificate
LOG_DIR="$HOME/.ssh/cert_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ssh_cert_requests.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP - Certificate requested: User=$VAULT_USER, Env=$ENVIRONMENT, TTL=$TTL, JumpboxIP=$JUMPBOX_IP, LocalIP=$(hostname -I | awk '{print $1}')" >> "$LOG_FILE"

echo "Connecting to jumpbox and signing your SSH key..."
echo "This may take a moment..."

# Copy the script to the jumpbox
scp -i "$JUMPBOX_KEY_PATH" -o StrictHostKeyChecking=no $TEMP_SCRIPT ubuntu@$JUMPBOX_IP:/tmp/sign_key.sh

# Run the script on the jumpbox
ssh -i "$JUMPBOX_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$JUMPBOX_IP "bash /tmp/sign_key.sh"

# Download the signed certificate
CERT_FILE="${SSH_KEY_PATH}-${ENVIRONMENT}-cert.pub"
scp -i "$JUMPBOX_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$JUMPBOX_IP:/tmp/signed_cert.pub "$CERT_FILE"

# Clean up
ssh -i "$JUMPBOX_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$JUMPBOX_IP "rm -f /tmp/sign_key.sh /tmp/user_key.pub /tmp/signed_cert.pub"
rm -f $TEMP_SCRIPT

echo "Certificate saved to $CERT_FILE"
echo "To use this certificate, make sure it's in your ~/.ssh directory"
echo "Your SSH client should automatically use it when connecting"
echo ""
echo "You can now SSH to servers that trust the Vault CA using:"
echo "ssh -i $SSH_KEY_PATH ubuntu@<server-ip>"
