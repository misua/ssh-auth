#!/bin/bash
# list-vms.sh - List all on-demand VMs

INVENTORY_DIR=~/Desktop/ssh-ca-vault/inventory

if [ ! -f "$INVENTORY_DIR/vms.csv" ]; then
    echo "No VMs found in inventory"
    exit 0
fi

echo "Current On-Demand VMs:"
echo "----------------------"
echo "Workspace | Username | Instance ID | Private IP | Purpose | Expiration Date"
echo "---------+----------+-------------+-----------+---------+----------------"
cat $INVENTORY_DIR/vms.csv | sed 's/,/ | /g'
echo

# Check for expired VMs
CURRENT_DATE=$(date +%Y-%m-%d)
echo "Expired VMs (to be cleaned up):"
echo "-------------------------------"
EXPIRED=false
while IFS=, read -r workspace username instance_id private_ip purpose expiration_date; do
    if [[ "$expiration_date" < "$CURRENT_DATE" ]]; then
        echo "$workspace | $username | $instance_id | $private_ip | $purpose | $expiration_date"
        EXPIRED=true
    fi
done < $INVENTORY_DIR/vms.csv

if [ "$EXPIRED" = false ]; then
    echo "No expired VMs found"
fi
