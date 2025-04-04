#!/bin/bash
set -e

echo "Setting up Promtail for Jumpbox (${environment}) log shipping to Loki..."

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
  - job_name: jumpbox_system
    static_configs:
      - targets:
          - localhost
        labels:
          job: jumpbox_logs
          host: jumpbox_${environment}
          environment: ${environment}
          index: ${index}
          __path__: /var/log/syslog
          
  - job_name: ssh_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh
          host: jumpbox_${environment}
          environment: ${environment}
          index: ${index}
          __path__: /var/log/auth.log

  - job_name: ssh_certificates
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh_certs
          host: jumpbox_${environment}
          environment: ${environment}
          index: ${index}
          __path__: /var/log/ssh-cert-*.log
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

# Set up logging for SSH certificate operations
cat > /usr/local/bin/log-ssh-cert << EOF
#!/bin/bash
echo "\$(date '+%Y-%m-%d %H:%M:%S') [\$USER] \$1" >> /var/log/ssh-cert-operations.log
EOF

chmod +x /usr/local/bin/log-ssh-cert

# Modify the SSH certificate scripts to log operations
if [ -f /usr/local/bin/get-ssh-cert-userpass.sh ]; then
  sed -i '/vault write -field=signed_key/i /usr/local/bin/log-ssh-cert "Requesting SSH certificate with user/pass auth"' /usr/local/bin/get-ssh-cert-userpass.sh
fi

# Set up log rotation for SSH certificate logs
cat > /etc/logrotate.d/ssh-certs << EOF
/var/log/ssh-cert-*.log {
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

echo "Promtail setup completed successfully for ${environment} jumpbox."
