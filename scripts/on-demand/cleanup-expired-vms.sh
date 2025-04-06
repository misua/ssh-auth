#!/bin/bash
# cleanup-expired-vms.sh - Automatically clean up expired VMs

set -e

INVENTORY_DIR=~/Desktop/ssh-ca-vault/inventory
CURRENT_DATE=$(date +%Y-%m-%d)
SCRIPT_DIR=$(dirname "$0")

if [ ! -f "$INVENTORY_DIR/vms.csv" ]; then
    echo "No VMs found in inventory"
    exit 0
fi

# Find expired VMs
echo "Checking for expired VMs on $CURRENT_DATE..."
EXPIRED=false

while IFS=, read -r workspace username instance_id private_ip purpose expiration_date; do
    if [[ "$expiration_date" < "$CURRENT_DATE" ]]; then
        echo "Found expired VM: $workspace ($instance_id) for $username, expired on $expiration_date"
        echo "Destroying VM..."
        $SCRIPT_DIR/destroy-vm.sh $workspace
        EXPIRED=true
    fi
done < $INVENTORY_DIR/vms.csv

if [ "$EXPIRED" = false ]; then
    echo "No expired VMs found"
fi
