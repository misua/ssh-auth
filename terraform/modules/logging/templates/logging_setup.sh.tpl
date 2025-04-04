#!/bin/bash
set -e

# Install Docker and Docker Compose
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create directories for Loki and Grafana
mkdir -p /opt/loki/config
mkdir -p /opt/grafana/data
mkdir -p /opt/promtail/config

# Create Loki configuration
cat > /opt/loki/config/loki-config.yaml << EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /tmp/loki/index
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

# Create Promtail configuration (log collector)
cat > /opt/promtail/config/promtail-config.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: vault_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: vault_logs
          __path__: /var/log/vault/*.log
  
  - job_name: ssh_auth_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh_auth_logs
          __path__: /var/log/auth.log
  
  - job_name: ssh_cert_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh_cert_logs
          __path__: /var/log/ssh-certs/*.log
EOF

# Create Docker Compose file
cat > /opt/docker-compose.yml << EOF
version: '3'
services:
  loki:
    image: grafana/loki:2.4.0
    ports:
      - "3100:3100"
    volumes:
      - /opt/loki/config:/etc/loki
    command: -config.file=/etc/loki/loki-config.yaml
    restart: always

  grafana:
    image: grafana/grafana:8.3.0
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=adminpassword
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - /opt/grafana/data:/var/lib/grafana
    restart: always
    depends_on:
      - loki

  promtail:
    image: grafana/promtail:2.4.0
    volumes:
      - /var/log:/var/log
      - /opt/promtail/config:/etc/promtail
    command: -config.file=/etc/promtail/promtail-config.yaml
    restart: always
    depends_on:
      - loki
EOF

# Start the services
cd /opt
docker-compose up -d

# Create a script to configure Grafana with dashboards
cat > /opt/setup-grafana.sh << 'EOF'
#!/bin/bash

# Wait for Grafana to be ready
echo "Waiting for Grafana to start..."
until $(curl --output /dev/null --silent --head --fail http://localhost:3000); do
    printf '.'
    sleep 5
done

# Add Loki as a data source
echo "Configuring Loki data source..."
curl -X POST -H "Content-Type: application/json" -d '{
    "name":"Loki",
    "type":"loki",
    "url":"http://loki:3100",
    "access":"proxy",
    "basicAuth":false
}' http://admin:adminpassword@localhost:3000/api/datasources

# Create SSH CA dashboard
echo "Creating SSH CA dashboard..."
curl -X POST -H "Content-Type: application/json" -d '{
    "dashboard": {
        "id": null,
        "title": "SSH CA Audit Dashboard",
        "tags": ["ssh", "vault", "audit"],
        "timezone": "browser",
        "panels": [
            {
                "id": 1,
                "title": "Certificate Issuance",
                "type": "table",
                "datasource": "Loki",
                "targets": [
                    {
                        "expr": "{job=\"ssh_cert_logs\"} |~ \"Certificate issued\"",
                        "refId": "A"
                    }
                ],
                "gridPos": {
                    "h": 8,
                    "w": 24,
                    "x": 0,
                    "y": 0
                }
            },
            {
                "id": 2,
                "title": "SSH Logins",
                "type": "table",
                "datasource": "Loki",
                "targets": [
                    {
                        "expr": "{job=\"ssh_auth_logs\"} |~ \"Accepted publickey\"",
                        "refId": "A"
                    }
                ],
                "gridPos": {
                    "h": 8,
                    "w": 24,
                    "x": 0,
                    "y": 8
                }
            },
            {
                "id": 3,
                "title": "Failed Authentication Attempts",
                "type": "table",
                "datasource": "Loki",
                "targets": [
                    {
                        "expr": "{job=\"ssh_auth_logs\"} |~ \"Failed\"",
                        "refId": "A"
                    }
                ],
                "gridPos": {
                    "h": 8,
                    "w": 24,
                    "x": 0,
                    "y": 16
                }
            }
        ],
        "schemaVersion": 16,
        "version": 0
    },
    "folderId": 0,
    "overwrite": false
}' http://admin:adminpassword@localhost:3000/api/dashboards/db
EOF

chmod +x /opt/setup-grafana.sh
/opt/setup-grafana.sh &

# Create a README file
cat > /home/ubuntu/README.md << EOF
# Loki + Grafana Logging for SSH CA

This server hosts Loki and Grafana for centralized logging of the SSH CA infrastructure.

## Accessing Grafana

- URL: http://$(hostname -I | awk '{print $1}'):3000
- Username: admin
- Password: adminpassword

## Dashboards

- SSH CA Audit Dashboard: Shows certificate issuance and SSH login events

## Log Sources

- Vault Audit Logs
- SSH Authentication Logs
- SSH Certificate Issuance Logs

## Adding More Log Sources

To add more log sources, modify the Promtail configuration at:
/opt/promtail/config/promtail-config.yaml
EOF

# Make sure README is owned by ubuntu user
chown ubuntu:ubuntu /home/ubuntu/README.md
