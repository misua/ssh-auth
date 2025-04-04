# Loki + Grafana Logging for SSH CA Infrastructure

This document explains how to use the centralized logging solution implemented for the SSH CA Vault infrastructure using Loki and Grafana.

## Overview

The logging infrastructure consists of:

1. **Loki**: A horizontally-scalable, highly-available log aggregation system
2. **Grafana**: A visualization and analytics platform for metrics and logs
3. **Promtail**: A log shipping agent that delivers logs to Loki

These components provide comprehensive logging and monitoring for the entire SSH Certificate Authority infrastructure.

## Accessing Grafana

Once the infrastructure is deployed, you can access Grafana through:

```
http://<logging_server_public_ip>:3000
```

Default credentials:
- Username: `admin`
- Password: `admin`

You will be prompted to change the password on first login.

## Available Log Sources

The following log sources are available in Grafana:

### Vault Server Logs
- System logs (`/var/log/syslog`)
- Vault audit logs (`/var/log/vault_audit.log`)
- SSH authentication logs (`/var/log/auth.log`)

### Jumpbox Logs
- System logs (`/var/log/syslog`)
- SSH authentication logs (`/var/log/auth.log`)
- SSH certificate issuance logs (`/var/log/ssh-cert-*.log`)

## Example Queries

Here are some useful LogQL queries for common monitoring tasks:

### Monitor All SSH Certificate Issuance

```
{job="ssh_certs"} |= "Requesting SSH certificate"
```

### Monitor Failed Authentication Attempts

```
{job="ssh"} |= "Failed password" or {job="ssh"} |= "authentication failure"
```

### Track Vault Audit Events

```
{job="vault_audit"}
```

## Monitoring the Logging Infrastructure

Each server has a utility script to check Promtail status:

```bash
# Run on any server (jumpbox or vault)
sudo /usr/local/bin/check_promtail
```

To check Loki and Grafana status on the logging server:

```bash
# Run on the logging server
docker ps
docker logs loki
docker logs grafana
```

## Troubleshooting

### Promtail Not Sending Logs

If logs aren't appearing in Grafana:

1. Verify Promtail is running:
   ```
   systemctl status promtail
   ```

2. Check connectivity to Loki server:
   ```
   curl http://<logging_server_ip>:3100/ready
   ```

3. Inspect Promtail logs:
   ```
   journalctl -u promtail
   ```

### Loki Not Receiving Logs

If Loki isn't receiving logs properly:

1. Check Loki container status:
   ```
   docker logs loki
   ```

2. Verify network connectivity between instances:
   ```
   # From jumpbox or vault server
   telnet <logging_server_ip> 3100
   ```

3. Review security group settings to ensure port 3100 is open.

## Log Retention

By default, logs are retained for 7 days. This can be modified by updating the Loki configuration and restarting the service.

## Supported Query Types

Loki supports numerous query functions for analyzing logs. Some examples include:

- **rate()**: Calculate the rate of log lines
- **count_over_time()**: Count occurrences over a time period
- **sum()**: Sum values
- **avg()**: Calculate average values
- **max()**: Find maximum values
- **min()**: Find minimum values

For more details, refer to the [Loki LogQL documentation](https://grafana.com/docs/loki/latest/logql/).

## Security Considerations

- All logs are transmitted within the VPC, minimizing exposure
- Access to Grafana requires authentication
- Sensitive information in logs is minimized
