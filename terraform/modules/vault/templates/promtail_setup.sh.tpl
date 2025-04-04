#!/bin/bash
set -e

echo "Setting up Promtail for Vault server log shipping to Loki..."

# Create Promtail configuration directory
mkdir -p /opt/promtail/config

# Create Promtail configuration
cat > /opt/promtail/config/promtail-config.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${logging_server_ip}:3100/loki/api/v1/push

scrape_configs:
  - job_name: vault_system
    static_configs:
      - targets:
          - localhost
        labels:
          job: vault_logs
          host: vault
          __path__: /var/log/syslog
          
  - job_name: vault_audit
    static_configs:
      - targets:
          - localhost
        labels:
          job: vault_audit
          host: vault
          __path__: /var/log/vault_audit.log

  - job_name: ssh_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh
          host: vault
          __path__: /var/log/auth.log
EOF

# Download Promtail
echo "Downloading Promtail..."
PROMTAIL_VERSION="2.8.0"
wget -q -O /tmp/promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
apt-get update && apt-get install -y unzip
unzip -q /tmp/promtail.zip -d /tmp
mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Create Promtail service
cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/opt/promtail/config/promtail-config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Promtail service
systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

# Create helper script for monitoring Promtail status
cat > /usr/local/bin/check_promtail << EOF
#!/bin/bash
systemctl status promtail
echo ""
echo "Checking connection to Loki server at ${logging_server_ip}:3100..."
curl -s http://${logging_server_ip}:3100/ready || echo "Cannot connect to Loki server"
EOF

chmod +x /usr/local/bin/check_promtail

# Set up log rotation for Vault audit logs
cat > /etc/logrotate.d/vault << EOF
/var/log/vault_audit.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create
    postrotate
        systemctl restart promtail
    endscript
}
EOF

echo "Promtail setup completed successfully."
