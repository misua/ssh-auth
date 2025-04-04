# Loki + Grafana Logging for SSH CA Infrastructure

This document explains how to use the Loki + Grafana logging solution for your SSH CA infrastructure.

## Overview

The logging infrastructure consists of:

1. **Loki**: A horizontally-scalable, highly-available log aggregation system
2. **Grafana**: A visualization and alerting platform
3. **Promtail**: Log collection agents installed on all servers

This system provides a comprehensive view of your SSH CA infrastructure, allowing you to:
- Track certificate issuance
- Monitor SSH login attempts
- Correlate certificate issuance with usage
- Set up alerts for suspicious activities

## Accessing Grafana

Once your infrastructure is deployed, you can access Grafana through the logging server:

```bash
# Get the IP address of the logging server
terraform output -module=logging public_ip

# Access Grafana in your browser
http://<logging-server-ip>:3000
```

**Default credentials**:
- Username: `admin`
- Password: `adminpassword`

## Available Dashboards

### 1. SSH CA Audit Dashboard

This dashboard provides a comprehensive view of your SSH CA infrastructure:

- **Certificate Issuance**: Shows all certificates issued by Vault
- **SSH Logins**: Displays successful SSH login attempts
- **Failed Authentication Attempts**: Shows failed SSH login attempts

## Querying Logs

Loki uses LogQL, a query language similar to Prometheus's PromQL. Here are some useful queries:

### Certificate Issuance

```
{job="vault_ssh_certs"} |~ "Certificate issued"
```

### Successful SSH Logins

```
{job="ssh_auth_logs"} |~ "Accepted publickey"
```

### Failed SSH Authentication

```
{job="ssh_auth_logs"} |~ "Failed"
```

### Correlating Certificate Issuance with Usage

```
{job="vault_ssh_certs"} |~ "User=admin" |~ "Env=prod"
```

## Setting Up Alerts

You can set up alerts in Grafana to notify you of suspicious activities:

1. In Grafana, go to **Alerting** → **Alert rules**
2. Click **New alert rule**
3. Configure a query like:
   ```
   {job="ssh_auth_logs"} |~ "Failed" | rate(5m) > 5
   ```
4. Set evaluation interval and notification channels
5. Save the alert

## Log Retention

By default, logs are retained for 7 days. To modify this:

1. Edit the Loki configuration at `/opt/loki/config/loki-config.yaml` on the logging server
2. Update the `retention_period` value
3. Restart Loki: `docker restart loki`

## Troubleshooting

### Logs Not Appearing in Grafana

1. Check if Promtail is running on the source server:
   ```bash
   systemctl status promtail
   ```

2. Verify Loki is receiving logs:
   ```bash
   curl -s http://localhost:3100/ready
   ```

3. Check Promtail configuration:
   ```bash
   cat /opt/promtail/config/promtail-config.yaml
   ```

### Grafana Can't Connect to Loki

1. Verify Loki is running:
   ```bash
   docker ps | grep loki
   ```

2. Check the Loki data source configuration in Grafana:
   - Go to **Configuration** → **Data sources**
   - Edit the Loki data source
   - Set URL to `http://loki:3100`
   - Click **Save & Test**

## Extending the Logging Infrastructure

### Adding New Log Sources

1. Edit the Promtail configuration on the relevant server:
   ```bash
   sudo nano /opt/promtail/config/promtail-config.yaml
   ```

2. Add a new scrape config:
   ```yaml
   - job_name: new_log_source
     static_configs:
       - targets:
           - localhost
         labels:
           job: new_log_source
           __path__: /path/to/logs/*.log
   ```

3. Restart Promtail:
   ```bash
   sudo systemctl restart promtail
   ```

### Creating Custom Dashboards

1. In Grafana, go to **Create** → **Dashboard**
2. Click **Add new panel**
3. Select Loki as the data source
4. Enter your LogQL query
5. Configure visualization options
6. Save the dashboard

## Comparison with CloudWatch

Loki+Grafana offers several advantages over CloudWatch:

1. **More powerful queries**: LogQL is more flexible than CloudWatch Logs Insights
2. **Better visualization**: Grafana provides more visualization options
3. **Cost-effective**: No per-GB ingestion costs
4. **Self-contained**: Runs entirely within your VPC
5. **Open-source**: Can be customized to your needs
