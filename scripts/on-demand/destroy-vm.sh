#!/bin/bash
# destroy-vm.sh - Destroy an on-demand VM

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <workspace-name>"
    echo
    echo "Available workspaces:"
    cd ~/Desktop/ssh-ca-vault/terraform/on-demand-vms
    terraform workspace list
    exit 1
fi

WORKSPACE=$1

# Switch to the workspace and destroy resources
cd ~/Desktop/ssh-ca-vault/terraform/on-demand-vms
terraform workspace select $WORKSPACE
terraform destroy -auto-approve

# Remove from inventory
INVENTORY_DIR=~/Desktop/ssh-ca-vault/inventory
if [ -f "$INVENTORY_DIR/vms.csv" ]; then
    grep -v "^$WORKSPACE," $INVENTORY_DIR/vms.csv > $INVENTORY_DIR/vms.csv.tmp
    mv $INVENTORY_DIR/vms.csv.tmp $INVENTORY_DIR/vms.csv
fi

echo "VM in workspace $WORKSPACE has been destroyed"
