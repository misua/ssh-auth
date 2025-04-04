# SSH Certificate Authority with SSO Integration

This implementation uses HashiCorp Vault as an SSH Certificate Authority with SSO integration to your existing identity providers (Microsoft Entra ID or AWS IAM). This addresses all requirements:

1. **User Jailing**: Developers use a shared `ssh-developer` account with restrictions preventing modification of authorized keys
2. **Audit Trail**: Every SSH session is logged with a unique identifier linked to the certificate issuer
3. **Centralized Management**: All access is controlled through Vault with policies
4. **SSO Authentication**: Users authenticate with existing Microsoft or AWS credentials

## Architecture Overview

![SSH CA Architecture](docs/architecture-diagram.png)

### Components:

1. **HashiCorp Vault Server**: Acts as SSH Certificate Authority
2. **Jumpbox Instances**: Secured bastion hosts with restricted user access
3. **SSO Integration**: Authentication via Microsoft Entra ID or AWS IAM
4. **Logging Infrastructure**: Centralized logging for audit trails
5. **Developer Client Tools**: Simplified access for developers

## Implementation Structure

```
sso-implementation/
├── terraform/           # Infrastructure as code
├── scripts/             # Helper scripts
├── config/              # Configuration files
└── docs/                # Documentation
```

## Key Features

- **Zero New Credentials**: Developers use existing SSO accounts
- **Audit Trail**: SSH session logs with identifiable certificate data
- **User Isolation**: Restricted shared user account
- **Centralized Management**: Access control via Vault policies
- **Automated Workflow**: Simplified certificate issuance

## Getting Started

See the implementation guide in [docs/implementation-guide.md](docs/implementation-guide.md).
