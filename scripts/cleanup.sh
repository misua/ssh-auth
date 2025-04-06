#!/bin/bash

# Set the AWS region
export AWS_REGION="us-east-1"

echo "Terminating EC2 instances..."
# Get all instance IDs with Name tag containing 'logging', 'jumpbox', or 'vault'
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*logging*,*jumpbox*,*vault*" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Found instances to terminate: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  echo "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
else
  echo "No matching instances found"
fi

# Remove terraform state
echo "Cleaning Terraform state..."
cd ../terraform
terraform state rm module.logging.aws_instance.logging 2>/dev/null || true
terraform state rm module.vault.aws_instance.vault 2>/dev/null || true
terraform state rm module.jumpbox.aws_instance.jumpbox 2>/dev/null || true

echo "Cleanup complete. You can now run terraform apply to recreate resources."
