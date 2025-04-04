# SSH CA Vault Audit Logging

This document describes the comprehensive audit logging capabilities implemented in the SSH CA Vault infrastructure.

## Overview

The audit logging system provides a complete trail of SSH certificate issuance and usage, allowing administrators to:

1. Track who requested SSH certificates
2. Monitor when and how certificates are used
3. Correlate certificate issuance with SSH login attempts
4. Generate reports for security and compliance purposes

## Logging Components

### 1. Vault Audit Logs

Vault's built-in audit device logs all operations performed against the Vault server, including:

- Authentication attempts (successful and failed)
- SSH certificate signing requests
- Policy changes
- Token creation and usage

**Location**: `/var/log/vault/audit.log` on the Vault server

**Format**: JSON format with detailed information about each request and response

### 2. SSH Certificate Issuance Logs

A dedicated log for SSH certificate issuance that records:

- Who requested the certificate
- When the certificate was issued
- Certificate details (environment, principals, TTL)
- Source IP of the request

**Location**: `/var/log/vault/ssh-certs.log` on the Vault server and `/var/log/ssh-certs/issuance.log` on jumpboxes

### 3. SSH Authentication Logs

Standard SSH authentication logs enhanced with verbose logging:

- Certificate-based authentication attempts
- Source IP of connection attempts
- Username used for authentication
- Authentication success/failure

**Location**: `/var/log/auth.log` on all servers

### 4. Client-Side Logs

Local logs on user machines that record:

- Certificate request attempts
- Certificate renewal activities
- Local errors during the certificate process

**Location**: `~/.ssh/cert_logs/` on user machines

## Centralized Logging with CloudWatch

All logs are forwarded to AWS CloudWatch for centralized storage and analysis:

- **Vault Audit Logs**: `vault-audit-logs` log group
- **SSH Authentication Logs**: `ssh-auth-logs` log group

This allows for:
- Long-term retention of logs
- Searching across multiple log sources
- Setting up alerts for suspicious activities
- Creating dashboards for monitoring

## Audit Tools

### Audit Script

The `audit-ssh-certs.sh` script helps analyze and correlate logs:

```bash
# Basic usage
./audit-ssh-certs.sh -d 7

# Filter by user
./audit-ssh-certs.sh -u admin -d 30

# Filter by environment
./audit-ssh-certs.sh -e prod -d 14
```

### CloudWatch Insights

You can use CloudWatch Insights to query logs with commands like:

```
fields @timestamp, @message
| filter @message like /Certificate issued/
| sort @timestamp desc
| limit 100
```

## Security Considerations

1. **Log Integrity**: Logs are stored in multiple locations to prevent tampering
2. **Access Control**: Only administrators have access to audit logs
3. **Retention**: Logs are retained for compliance purposes (default: 30 days)

## Best Practices

1. **Regular Review**: Set up a schedule for regular log review
2. **Alerting**: Configure alerts for suspicious activities
3. **Reporting**: Generate monthly reports for compliance
4. **Correlation**: Correlate certificate issuance with SSH usage

## Troubleshooting

If logs are not appearing:

1. Check that the Vault audit device is enabled:
   ```
   vault audit list
   ```

2. Verify CloudWatch agent is running:
   ```
   systemctl status amazon-cloudwatch-agent
   ```

3. Check log permissions:
   ```
   ls -la /var/log/vault/
   ls -la /var/log/ssh-certs/
   ```
