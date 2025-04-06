#!/bin/bash
# create-vm.sh - Create an on-demand VM

set -e

# Default values
INSTANCE_TYPE="t2.micro"
ENVIRONMENT="prod"
EXPIRATION_DAYS=7
PURPOSE=""

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -u, --username USER     Username (required)"
    echo "  -t, --type TYPE         Instance type (default: $INSTANCE_TYPE)"
    echo "  -e, --environment ENV   Environment (default: $ENVIRONMENT)"
    echo "  -d, --days DAYS         Expiration in days (default: $EXPIRATION_DAYS)"
    echo "  -p, --purpose PURPOSE   Purpose of the VM (required)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Example:"
    echo "  $0 -u john -p 'Testing new application'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -t|--type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--days)
            EXPIRATION_DAYS="$2"
            shift 2
            ;;
        -p|--purpose)
            PURPOSE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check required parameters
if [ -z "$USERNAME" ]; then
    echo "Error: Username is required"
    show_help
    exit 1
fi

if [ -z "$PURPOSE" ]; then
    echo "Error: Purpose is required"
    show_help
    exit 1
fi

# Calculate expiration date
EXPIRATION_DATE=$(date -d "+$EXPIRATION_DAYS days" +%Y-%m-%d)

# Create a workspace for this VM
WORKSPACE="vm-${USERNAME}-$(date +%Y%m%d%H%M%S)"
cd ~/Desktop/ssh-ca-vault/terraform/on-demand-vms

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Create a new workspace
terraform workspace new $WORKSPACE

# Create variables file
cat > terraform.tfvars << EOF
username = "$USERNAME"
instance_type = "$INSTANCE_TYPE"
environment = "$ENVIRONMENT"
purpose = "$PURPOSE"
expiration_date = "$EXPIRATION_DATE"
EOF

# Apply the configuration
terraform apply -auto-approve

# Get the VM details
INSTANCE_ID=$(terraform output -raw instance_id)
PRIVATE_IP=$(terraform output -raw private_ip)

echo "VM created successfully!"
echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
echo "Expiration Date: $EXPIRATION_DATE"
echo
echo "To connect to this VM:"
echo "1. SSH to the jumpbox"
echo "2. From the jumpbox, run: ssh ubuntu@$PRIVATE_IP"
echo
echo "To destroy this VM, run:"
echo "./destroy-vm.sh $WORKSPACE"

# Save VM details to inventory
INVENTORY_DIR=~/Desktop/ssh-ca-vault/inventory
mkdir -p $INVENTORY_DIR
cat >> $INVENTORY_DIR/vms.csv << EOF
$WORKSPACE,$USERNAME,$INSTANCE_ID,$PRIVATE_IP,$PURPOSE,$EXPIRATION_DATE
EOF
