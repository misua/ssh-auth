#!/bin/bash
# Setup Promtail for log shipping to Loki

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
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          host: jumpbox-${index}
          __path__: /var/log/syslog

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: jumpbox-${index}
          __path__: /var/log/auth.log

  - job_name: ssh_certs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh_certs
          host: jumpbox-${index}
          __path__: /var/log/ssh-certs/*.log
EOF

# Download Promtail binary
curl -s -L -o /usr/local/bin/promtail https://github.com/grafana/loki/releases/download/v2.4.0/promtail-linux-amd64
chmod +x /usr/local/bin/promtail

# Create systemd service for Promtail
cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail Log Agent
After=network.target

[Service]
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
