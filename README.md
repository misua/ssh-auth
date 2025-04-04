# SSH Certificate Authority with HashiCorp Vault

This Terraform project implements a centralized SSH Certificate Authority using HashiCorp Vault, providing a modern, secure alternative to distributing SSH keys via authorized_keys files.

## Architecture Overview

### Components

1. **VPC**: A dedicated network environment with public and private subnets
2. **Vault Server**: Deployed in a private subnet, acts as the SSH Certificate Authority (CA)
3. **Jumpbox Instances**: Deployed in public subnets, one per environment (dev, staging, prod)

### Workflow

1. **User generates SSH key pair locally**
   ```
   ssh-keygen -t rsa -b 4096
   ```

2. **User authenticates to Vault and gets their public key signed**
   ```
   # Using the helper script on a jumpbox
   get-ssh-cert ~/.ssh/id_rsa.pub your-username
   ```

3. **User connects using their signed certificate**
   ```
   ssh ubuntu@<jumpbox-ip>
   ```

## Benefits Over authorized_keys Distribution

- **Time-Limited Access**: Certificates expire automatically (default: 24 hours)
- **No Key Distribution**: Servers only need to trust the CA public key
- **Centralized Management**: Control access via Vault policies
- **Role-Based Access**: Principals define what roles a user can assume
- **Audit Trail**: Vault logs provide a record of certificate issuance
- **Simplified Revocation**: No need to update authorized_keys files on all servers

## How It Works

### Vault Server

- Generates and stores the SSH CA keypair
- Authenticates users via username/password (can be replaced with LDAP, OIDC, etc.)
- Signs user public keys, creating certificates with specific permissions

### Jumpbox Configuration

- Configured to trust the CA public key
- Uses `AuthorizedPrincipalsFile` to define what principals (roles) can access which accounts
- Only accepts connections with valid, non-expired certificates

## Deployment Instructions

1. **Set up AWS credentials**
   ```
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   ```

2. **Initialize Terraform**
   ```
   cd terraform
   terraform init
   ```

3. **Deploy the infrastructure**
   ```
   terraform apply -var="ssh_key_name=your-aws-key-name"
   ```

4. **Access Vault UI**
   You can access the Vault UI at http://[vault-public-ip]:8200
   
   Initial credentials:
   - Username: admin
   - Password: adminpassword
   
   **Important**: Change these credentials immediately in a production environment!

## User Access Guide

1. **Create SSH keypair**
   ```
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/example_key
   ```

2. **Connect to jumpbox via AWS SSM or temporary credentials**

3. **Request certificate from Vault**
   ```
   get-ssh-cert ~/.ssh/example_key.pub
   ```

4. **Connect using certificate**
   ```
   ssh -i ~/.ssh/example_key ubuntu@[jumpbox-ip]
   ```

## Security Considerations

- In production, enable TLS for Vault
- Integrate Vault with your enterprise identity provider (LDAP, OIDC, etc.)
- Restrict jumpbox SSH access to your corporate IP ranges
- Implement multi-factor authentication for Vault access

## Customization

You can customize various aspects of this deployment:

- Certificate TTL (time-to-live)
- User roles and permissions
- SSH options enforced by certificates
- Host principal mappings
