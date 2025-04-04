#!/bin/bash
set -e

# Update system first
apt-get update
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Install Docker with robust error handling
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify Docker installation
if ! docker --version; then
  echo "Docker installation failed, attempting alternative method..."
  apt-get remove docker docker-engine docker.io containerd runc -y || true
  apt-get update
  apt-get install -y docker.io
  systemctl enable --now docker
  
  if ! docker --version; then
    echo "All Docker installation methods failed. Exiting."
    exit 1
  fi
fi

echo "Docker successfully installed: $(docker --version)"

# Install Docker Compose with robust error handling
echo "Installing Docker Compose..."
COMPOSE_VERSION="1.29.2"
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
if ! docker-compose --version; then
  echo "Docker Compose installation failed, attempting pip method..."
  apt-get install -y python3-pip
  pip3 install docker-compose
  
  if ! docker-compose --version; then
    echo "All Docker Compose installation methods failed. Exiting."
    exit 1
  fi
fi

echo "Docker Compose successfully installed: $(docker-compose --version)"

# Create directories for Loki and Grafana
mkdir -p /opt/loki/config
mkdir -p /opt/grafana/data
mkdir -p /opt/promtail/config

# Create docker-compose.yml file
cat > /opt/docker-compose.yml << EOF
version: '3'
services:
  loki:
    image: grafana/loki:2.8.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - /opt/loki/config:/etc/loki
      - /opt/loki/data:/loki
    command: -config.file=/etc/loki/loki-config.yaml
    restart: unless-stopped
    networks:
      - loki

  grafana:
    image: grafana/grafana:9.5.2
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/grafana/data:/var/lib/grafana
      - /opt/grafana/provisioning:/etc/grafana/provisioning
      - /opt/grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped
    networks:
      - loki
    depends_on:
      - loki

networks:
  loki:
EOF

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

# Configure Grafana dashboard provisioning
mkdir -p /opt/grafana/provisioning/datasources
mkdir -p /opt/grafana/provisioning/dashboards
mkdir -p /opt/grafana/dashboards

# Create datasource provisioning
cat > /opt/grafana/provisioning/datasources/loki.yaml << EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
EOF

# Create dashboard provisioning
cat > /opt/grafana/provisioning/dashboards/ssh-ca.yaml << EOF
apiVersion: 1

providers:
  - name: 'SSH CA Dashboards'
    orgId: 1
    folder: 'SSH CA'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
EOF

# Create SSH CA dashboard directory
mkdir -p /opt/grafana/dashboards/ssh-ca

# Create SSH CA Dashboard
cat > /opt/grafana/dashboards/ssh-ca-dashboard.json << EOF
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"ssh_certs\"}",
          "refId": "A"
        }
      ],
      "title": "SSH Certificate Issuance",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 4,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"ssh\"} |= \"Failed password\" or {job=\"ssh\"} |= \"authentication failure\"",
          "refId": "A"
        }
      ],
      "title": "Failed SSH Authentication",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "description": "",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "id": 6,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"ssh\"} |= \"Accepted publickey\"",
          "refId": "A"
        }
      ],
      "title": "Successful SSH Logins",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 8,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"vault_audit\"}",
          "refId": "A"
        }
      ],
      "title": "Vault Audit Logs",
      "type": "logs"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": [
    "ssh",
    "vault",
    "ca"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "SSH CA Monitoring",
  "uid": "ssh-ca-dashboard",
  "version": 1
}
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

# Install Promtail
PROMTAIL_VERSION="2.8.0"
wget -q -O /tmp/promtail.zip "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
unzip /tmp/promtail.zip -d /tmp
mv /tmp/promtail-linux-amd64/promtail /usr/local/bin/
chmod +x /usr/local/bin/promtail

# Start Promtail
promtail -config.file=/opt/promtail/config/promtail-config.yaml
