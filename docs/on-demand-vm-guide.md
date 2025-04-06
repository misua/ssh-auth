# On-Demand VM Management Guide

This guide explains how to use the on-demand VM management system with the SSH CA Vault infrastructure. This system allows you to create, list, and destroy VMs on demand, with automatic expiration and cleanup.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Creating a VM](#creating-a-vm)
3. [Listing VMs](#listing-vms)
4. [Connecting to VMs](#connecting-to-vms)
5. [Destroying VMs](#destroying-vms)
6. [Automatic Cleanup](#automatic-cleanup)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

Before using the on-demand VM management system, ensure:

1. The SSH CA Vault infrastructure is deployed and running
2. You have access to the jumpbox
3. Vault is initialized and unsealed
4. You have a valid SSH certificate from Vault

## Creating a VM

To create a new on-demand VM:

```bash
# Navigate to the scripts directory
cd ~/Desktop/ssh-ca-vault/scripts/on-demand

# Create a VM with basic options
./create-vm.sh -u username -p "Purpose of the VM"

# Create a VM with all options
./create-vm.sh \
  -u username \
  -t t2.micro \
  -e prod \
  -d 7 \
  -p "Purpose of the VM"
```

### Parameters

- `-u, --username`: Username of the VM owner (required)
- `-t, --type`: EC2 instance type (default: t2.micro)
- `-e, --environment`: Environment name (default: prod)
- `-d, --days`: Number of days until VM expiration (default: 7)
- `-p, --purpose`: Purpose of the VM (required)

### What Happens

When you create a VM:

1. A new Terraform workspace is created
2. An EC2 instance is launched in the private subnet
3. The VM is configured to trust the Vault CA
4. The VM details are saved to the inventory

## Listing VMs

To list all on-demand VMs:

```bash
cd ~/Desktop/ssh-ca-vault/scripts/on-demand
./list-vms.sh
```

This will show:
- All active VMs with their details
- Any expired VMs that need cleanup

## Connecting to VMs

To connect to an on-demand VM:

1. First, ensure you have a valid SSH certificate from Vault:
   ```bash
   # From your local machine
   ./scripts/get-cert-remote.sh -j jumpbox-public-ip -b ~/path/to/bastion-key.pem
   ```

2. SSH to the jumpbox:
   ```bash
   ssh -i ~/.ssh/id_rsa -i ~/.ssh/id_rsa-cert.pub ubuntu@jumpbox-public-ip
   ```

3. From the jumpbox, SSH to the on-demand VM:
   ```bash
   ssh ubuntu@vm-private-ip
   ```

The private IP of the VM is shown when you create it and when you list VMs.

## Destroying VMs

To destroy an on-demand VM:

```bash
cd ~/Desktop/ssh-ca-vault/scripts/on-demand
./destroy-vm.sh workspace-name
```

The workspace name is shown when you create the VM and when you list VMs.

## Automatic Cleanup

VMs are automatically marked for cleanup when they reach their expiration date. You can manually run the cleanup script:

```bash
cd ~/Desktop/ssh-ca-vault/scripts/on-demand
./cleanup-expired-vms.sh
```

To set up automatic cleanup, add a cron job:

```bash
# Edit the crontab
crontab -e

# Add this line to run cleanup daily at midnight
0 0 * * * ~/Desktop/ssh-ca-vault/scripts/on-demand/cleanup-expired-vms.sh >> ~/Desktop/ssh-ca-vault/logs/cleanup.log 2>&1
```

## Troubleshooting

### VM Creation Fails

If VM creation fails:

1. Check the Terraform output for errors
2. Verify that the SSH CA Vault infrastructure is running
3. Ensure the Terraform state file exists and is accessible

### Cannot Connect to VM

If you cannot connect to a VM:

1. Verify the VM is running using the AWS console
2. Check that your SSH certificate is valid
3. Ensure the jumpbox can reach the VM's private IP
4. Verify the VM's security group allows SSH from the jumpbox

### Terraform Workspace Issues

If you encounter Terraform workspace issues:

```bash
# List all workspaces
cd ~/Desktop/ssh-ca-vault/terraform/on-demand-vms
terraform workspace list

# Select a specific workspace
terraform workspace select workspace-name

# Delete a workspace (after destroying resources)
terraform workspace delete workspace-name
```

## Example Workflow

Here's a complete example workflow:

```bash
# 1. Create a VM for user "john"
cd ~/Desktop/ssh-ca-vault/scripts/on-demand
./create-vm.sh -u john -p "Testing new application" -d 3

# 2. Note the private IP from the output (e.g., 10.0.10.25)

# 3. Get an SSH certificate
cd ~/Desktop/ssh-ca-vault/scripts
./get-cert-remote.sh -j jumpbox-public-ip -b ~/path/to/bastion-key.pem

# 4. Connect to the jumpbox
ssh -i ~/.ssh/id_rsa -i ~/.ssh/id_rsa-cert.pub ubuntu@jumpbox-public-ip

# 5. From the jumpbox, connect to the VM
ssh ubuntu@10.0.10.25

# 6. When done, destroy the VM
cd ~/Desktop/ssh-ca-vault/scripts/on-demand
./destroy-vm.sh vm-john-20250406180015
```

This on-demand VM system integrates seamlessly with your SSH CA Vault infrastructure, allowing you to create and manage VMs while maintaining the security benefits of certificate-based authentication.
