# How to Deploy and Access Loki+Grafana Logging

This guide provides step-by-step instructions for deploying the Loki+Grafana logging infrastructure for your SSH CA Vault and accessing its features.

## Deployment Process

1. **Clone the repository (if you haven't already)**
   ```bash
   git clone https://github.com/your-org/ssh-ca-vault.git
   cd ssh-ca-vault
   ```

2. **Switch to the feature branch**
   ```bash
   git checkout feature/logging
   ```

3. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

4. **Plan the deployment to verify changes**
   ```bash
   terraform plan -out=tfplan
   ```

5. **Apply the Terraform configuration**
   ```bash
   terraform apply tfplan
   ```

6. **Wait for deployment to complete** (approximately 5-10 minutes)

7. **Get the logging server public IP**
   ```bash
   terraform output -json | grep logging_public_ip
   ```

## Accessing Grafana

8. **Wait for Grafana to initialize** (approximately 2-3 minutes after deployment completes)

9. **Open Grafana in your web browser**
   ```
   http://<logging_server_public_ip>:3000
   ```

10. **Log in with default credentials**
    - Username: `admin`
    - Password: `admin`

11. **Change the default password when prompted**

## Verifying the Logging Infrastructure

12. **Check that Loki is receiving logs**
    - In Grafana, navigate to **Explore** in the left sidebar
    - Select **Loki** as the data source
    - Run a simple query: `{job="vault_logs"}` or `{job="jumpbox_logs"}`

13. **Verify Promtail is running on servers**
    - SSH into the Vault server or any jumpbox
      ```bash
      ssh -i your-key.pem ubuntu@<vault_or_jumpbox_ip>
      ```
    - Check Promtail status
      ```bash
      sudo /usr/local/bin/check_promtail
      ```

## Setting Up Dashboards

14. **Create a basic SSH monitoring dashboard**
    - In Grafana, click **Dashboards** → **+ New Dashboard**
    - Click **+ Add visualization**
    - Select **Loki** as the data source
    - Create a panel with query: `{job="ssh"}`
    - Configure visualization as a logs panel
    - Save the dashboard

15. **Import the pre-configured SSH CA dashboard**
    - In Grafana, click **Dashboards** → **+ Import**
    - Click **Upload JSON file**
    - Navigate to `/home/sab/Desktop/ssh-ca-vault/terraform/modules/logging/dashboards/ssh-ca-dashboard.json`
    - Click **Import**

## Troubleshooting (if needed)

16. **If logs are not appearing in Grafana**
    - SSH into the logging server
      ```bash
      ssh -i your-key.pem ubuntu@<logging_server_ip>
      ```
    - Check Loki status
      ```bash
      docker ps
      docker logs loki
      ```
    - Verify Loki is accessible within the VPC
      ```bash
      curl http://localhost:3100/ready
      ```

17. **If Promtail is not sending logs**
    - SSH into a server (Vault or jumpbox)
    - Check Promtail logs
      ```bash
      sudo journalctl -u promtail
      ```
    - Verify connectivity to Loki
      ```bash
      curl http://<logging_server_ip>:3100/ready
      ```

## Testing Logging with SSH Certificate Operations

18. **Generate an SSH certificate on a jumpbox**
    - SSH into a jumpbox
      ```bash
      ssh -i your-key.pem ubuntu@<jumpbox_ip>
      ```
    - Request a certificate
      ```bash
      sudo /usr/local/bin/get-ssh-cert-userpass.sh
      ```

19. **View certificate issuance logs in Grafana**
    - In Grafana's Explore section
    - Run query: `{job="ssh_certs"}`
    - You should see the certificate issuance event

## Common Loki Queries

Here are some useful queries for monitoring your SSH CA infrastructure:

1. **All SSH authentication failures**
   ```
   {job="ssh"} |= "Failed password" or {job="ssh"} |= "authentication failure"
   ```

2. **Certificate issuance events**
   ```
   {job="ssh_certs"} |= "Requesting SSH certificate"
   ```

3. **Successful logins with certificates**
   ```
   {job="ssh"} |= "Accepted publickey"
   ```

4. **Vault audit events**
   ```
   {job="vault_audit"}
   ```

5. **Rate of authentication failures**
   ```
   rate({job="ssh"} |= "Failed password"[5m])
   ```

## Security Recommendations

1. **Change default Grafana password immediately** after first login
2. **Restrict access to the Grafana UI** by updating security groups to only allow trusted IPs
3. **Set up Grafana alerts** for suspicious activities like multiple authentication failures
4. **Regularly audit logs** for unexpected certificate issuance or authentication patterns
5. **Enable log rotation** to prevent disk space issues on servers

## Maintenance

1. **Backup Grafana dashboards** by exporting them periodically
2. **Monitor disk usage** on the logging server
   ```bash
   ssh -i your-key.pem ubuntu@<logging_server_ip>
   df -h
   ```
3. **Update components** when new versions are available
