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
COMPOSE_VERSION="2.8.0"
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

# Create directories for Loki and Grafana with proper permissions
mkdir -p /opt/loki/config
mkdir -p /opt/loki/data/chunks
mkdir -p /opt/loki/data/index
mkdir -p /opt/grafana/data
mkdir -p /opt/grafana/provisioning/datasources
mkdir -p /opt/grafana/provisioning/dashboards
mkdir -p /opt/grafana/dashboards
mkdir -p /opt/promtail/config

# Set proper permissions for Grafana and Loki
# Grafana runs as user 472
chown -R 472:472 /opt/grafana/data
chmod -R 755 /opt/grafana/data

# Create temporary directories with proper permissions for Loki
mkdir -p /tmp/loki/index /tmp/loki/chunks
chmod -R 777 /tmp/loki

# Create docker-compose.yml file
cat > /opt/docker-compose.yml << EOF
version: '3'
services:
  loki:
    image: grafana/loki:${COMPOSE_VERSION}
    container_name: loki
    user: "10001"
    ports:
      - "3100:3100"
    volumes:
      - /opt/loki/config:/etc/loki
      - /tmp/loki:/tmp/loki
    command: -config.file=/etc/loki/loki-config.yaml
    restart: unless-stopped
    networks:
      - loki

  grafana:
    image: grafana/grafana:9.5.2
    container_name: grafana
    user: "472"
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

# Create Loki configuration with simplified setup
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
  chunk_idle_period: 1h
  max_chunk_age: 1h
  chunk_target_size: 1048576
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/index
    cache_location: /tmp/loki/chunks
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
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
  - name: 'SSH CA Dashboard'
    orgId: 1
    folder: 'SSH'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Copy the SSH CA dashboard JSON to Grafana
cp /opt/grafana/dashboards/ssh-ca-dashboard.json /opt/grafana/dashboards/

# Start the containers using docker-compose
cd /opt
docker-compose up -d

# Add a user to run the logging services
useradd -m -s /bin/bash logging

# Wait for services to initialize
echo "Waiting 30s for Grafana to initialize..."
sleep 30

# Enable and configure firewall
apt-get install -y ufw
ufw allow ssh
ufw allow 3000/tcp comment 'Grafana'
ufw allow 3100/tcp comment 'Loki'
ufw --force enable

# Create a simple script to check the status of the logging services
cat > /usr/local/bin/check-logging-status << EOF
#!/bin/bash
echo "=== Docker Container Status ==="
docker ps -a
echo ""
echo "=== Grafana Status ==="
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "Grafana is running" || echo "Grafana is not running"
echo ""
echo "=== Loki Status ==="
curl -s http://localhost:3100/ready | grep -q "ready" && echo "Loki is ready" || echo "Loki is not ready"
EOF

chmod +x /usr/local/bin/check-logging-status

echo "Logging setup complete!"

# Run status check
/usr/local/bin/check-logging-status
