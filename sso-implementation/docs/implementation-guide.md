# SSH CA Implementation Guide with SSO Integration

This guide provides step-by-step instructions for implementing the SSH Certificate Authority solution with SSO integration.

## Prerequisites

* AWS Account with administrator access
* Terraform installed
* HashiCorp Vault license (optional, free tier is sufficient for testing)
* Access to your Microsoft Entra ID (formerly Azure AD) tenant or AWS IAM configuration

## Step 1: Deploy Infrastructure

The Terraform configuration in the `terraform/` directory provisions:
- VPC with public and private subnets
- Vault server in a private subnet
- Jumpbox instances in public subnets
- Security groups and IAM roles

```bash
cd terraform
terraform init
terraform apply
```

## Step 2: Configure Vault

### 2.1 Initialize and Unseal Vault

Follow the output from Terraform to connect to the Vault server and initialize it:

```bash
export VAULT_ADDR="https://vault.example.com:8200"
vault operator init -key-shares=3 -key-threshold=2
```

Safely store the unseal keys and root token. Then unseal Vault:

```bash
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
```

### 2.2 Configure SSO Authentication

#### Option A: Microsoft Entra ID (Azure AD) Integration

```bash
# Login with root token
vault login <root-token>

# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC with Microsoft
vault write auth/oidc/config \
  oidc_discovery_url="https://login.microsoftonline.com/TENANT_ID/v2.0" \
  oidc_client_id="YOUR_CLIENT_ID" \
  oidc_client_secret="YOUR_CLIENT_SECRET" \
  default_role="default"

# Create a role mapping Azure AD groups to Vault policies
vault write auth/oidc/role/default \
  bound_audiences="YOUR_CLIENT_ID" \
  allowed_redirect_uris="https://vault.example.com:8250/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="email" \
  groups_claim="groups" \
  policies="default,ssh-developer"
```

#### Option B: AWS IAM Integration

```bash
# Login with root token
vault login <root-token>

# Enable AWS auth method
vault auth enable aws

# Configure AWS auth
vault write auth/aws/config/client \
  access_key=YOUR_AWS_ACCESS_KEY \
  secret_key=YOUR_AWS_SECRET_KEY

# Create a role mapping IAM roles to Vault policies
vault write auth/aws/role/developer \
  auth_type=iam \
  bound_iam_principal_arn="arn:aws:iam::ACCOUNT_ID:role/DeveloperRole" \
  policies="default,ssh-developer" \
  ttl=1h
```

### 2.3 Configure SSH CA

```bash
# Enable SSH secrets engine
vault secrets enable -path=ssh-client-signer ssh

# Generate CA key pair
vault write ssh-client-signer/config/ca \
  generate_signing_key=true \
  key_id_format="{{identity.entity.name}}@{{identity.entity.metadata.email}}@{{time.now.unix}}"

# Create role for signing certificates
vault write ssh-client-signer/roles/developer \
  allow_user_certificates=true \
  allowed_users="ssh-developer" \
  allowed_extensions="permit-pty" \
  default_extensions=@config/certificate-extensions.json \
  key_type="ca" \
  default_user="ssh-developer" \
  ttl="24h"
```

### 2.4 Create Policies

```bash
# Create policy for developers
vault policy write ssh-developer @config/ssh-developer-policy.hcl

# Create policy for admins
vault policy write ssh-admin @config/ssh-admin-policy.hcl
```

## Step 3: Configure Jumpboxes

Run the configuration script on each jumpbox:

```bash
ssh ec2-user@10.0.1.46 "sudo bash -s" < scripts/configure-jumpbox.sh
```

This script:
1. Creates the shared `ssh-developer` account
2. Configures SSH to use certificates
3. Sets up audit logging
4. Implements user jailing

## Step 4: Distribute Developer Tools

Share the developer tools from the `scripts/` directory with your developers:

```bash
# For Microsoft Entra ID integration
scripts/get-ssh-cert-azure.sh

# For AWS IAM integration
scripts/get-ssh-cert-aws.sh
```

## Step 5: Configure Audit Logging

Deploy the centralized logging configuration to collect and correlate logs from Vault and jumpboxes:

```bash
cd terraform
terraform apply -target=module.logging
```

## Step 6: Test the Solution

Verify the implementation:

1. **Test SSO Authentication**:
   ```bash
   scripts/get-ssh-cert-azure.sh
   # Or
   scripts/get-ssh-cert-aws.sh
   ```

2. **Test SSH Access**:
   ```bash
   ssh ssh-developer@10.0.1.46
   ```

3. **Verify Audit Trail**:
   Check logs in your centralized logging system to ensure certificate information is captured correctly.

## Maintenance Tasks

### Certificate Revocation

To revoke a certificate:

```bash
vault write ssh-client-signer/revoke serial_number=<serial>
```

### Entity Management

For more detailed identity information in logs, create and maintain entities in Vault:

```bash
vault write identity/entity name="john.doe" \
  metadata=email="john.doe@example.com" \
  metadata=department="Engineering"
```

### SSH CA Key Rotation

To rotate the CA key:

```bash
vault write -f ssh-client-signer/config/rotate
```

After rotation, update the CA public key on all jumpboxes using the `scripts/update-ca-key.sh` script.
