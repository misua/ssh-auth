#!/bin/bash
set -e

# Start logging all output for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting logging setup: $(date)"

# Function to check for errors and log them
check_error() {
  if [ $? -ne 0 ]; then
    echo "ERROR: $1 failed"
    return 1
  else
    echo "SUCCESS: $1 completed"
    return 0
  fi
}

# Update system first
apt-get update
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
check_error "System update" || echo "Continuing despite system update issues"

# Mount EBS volume for docker data
echo "Setting up dedicated EBS volume for container data..."
# Check for NVMe device naming (AWS instances)
if [ -b /dev/nvme1n1 ]; then
  DEVICE="/dev/nvme1n1"
elif [ -b /dev/xvdh ]; then
  DEVICE="/dev/xvdh"
else
  # Try to find the device by checking all potential device names
  for dev in /dev/sd[a-z] /dev/xvd[a-z] /dev/nvme*n1; do
    if [ -b "$dev" ] && [ "$dev" != "/dev/sda" ] && [ "$dev" != "/dev/xvda" ] && [ "$dev" != "/dev/nvme0n1" ]; then
      DEVICE="$dev"
      break
    fi
  done
fi

if [ -b "$DEVICE" ]; then
  echo "Found device: $DEVICE"
  # Format if not already formatted
  if ! file -s $DEVICE | grep -q filesystem; then
    echo "Formatting $DEVICE..."
    mkfs -t ext4 $DEVICE
    check_error "Format EBS volume"
  fi
  
  # Create mount point and add to fstab
  mkdir -p /docker-data
  mount $DEVICE /docker-data
  check_error "Mount EBS volume"
  echo "$DEVICE /docker-data ext4 defaults,nofail 0 2" >> /etc/fstab
  
  # Use this for Docker data
  mkdir -p /docker-data/loki/chunks
  mkdir -p /docker-data/loki/index
  mkdir -p /docker-data/loki/config
  mkdir -p /docker-data/grafana/data
  mkdir -p /docker-data/grafana/provisioning/datasources
  mkdir -p /docker-data/grafana/provisioning/dashboards
  mkdir -p /docker-data/grafana/dashboards
  
  # Set permissions
  chmod -R 777 /docker-data/loki
  chown -R 472:472 /docker-data/grafana
  chmod -R 755 /docker-data/grafana
  
  echo "EBS volume mounted and directories created with proper permissions"
else
  echo "WARNING: EBS volume not found, using instance storage"
  # Create directories for Loki and Grafana with proper permissions on instance storage
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
  
  # Loki needs permissive permissions for its temp directories
  chmod -R 777 /opt/loki
fi

# Determine the data directory based on EBS availability
if [ -d "/docker-data" ]; then
  DATA_DIR="/docker-data"
else
  DATA_DIR="/opt"
fi

# Create dashboard directory if it doesn't exist
mkdir -p $DATA_DIR/grafana/dashboards
chmod -R 755 $DATA_DIR/grafana/dashboards

# Create dashboard JSON file directly
cat > $DATA_DIR/grafana/dashboards/ssh-ca-dashboard.json << 'DASHBOARD_EOF'
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
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
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
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
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
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
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
      "title": "Successful SSH Authentication",
      "type": "logs"
    }
  ],
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
  "timepicker": {},
  "timezone": "",
  "title": "SSH CA Dashboard",
  "uid": "ssh-ca",
  "version": 1
}
DASHBOARD_EOF

# Verify dashboard file was created
if [ -f "$DATA_DIR/grafana/dashboards/ssh-ca-dashboard.json" ]; then
  echo "Dashboard file created successfully"
  # Set proper permissions for Grafana to read the dashboard
  chown -R 472:472 $DATA_DIR/grafana/dashboards
else
  echo "ERROR: Failed to create dashboard file"
fi

# Install Docker with robust error handling
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
check_error "Docker installation" || echo "Trying alternative Docker installation"

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
COMPOSE_VERSION="${COMPOSE_VERSION}"
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_error "Docker Compose installation" || echo "Trying alternative Docker Compose installation"

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

# Create datasource provisioning file
mkdir -p $DATA_DIR/grafana/provisioning/datasources
cat > $DATA_DIR/grafana/provisioning/datasources/loki.yaml << EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
EOF

# Create dashboard provisioning file
mkdir -p $DATA_DIR/grafana/provisioning/dashboards
cat > $DATA_DIR/grafana/provisioning/dashboards/ssh-ca.yaml << EOF
apiVersion: 1

providers:
  - name: 'SSH CA Dashboards'
    orgId: 1
    folder: 'SSH'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
EOF

# Create Loki configuration with simplified setup
cat > $DATA_DIR/loki/config/loki-config.yaml << EOF
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
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF

# Create docker-compose.yml file with improved configuration
cat > $DATA_DIR/docker-compose.yml << EOF
version: '3'
services:
  loki:
    image: grafana/loki:${PROMTAIL_VERSION}
    container_name: loki
    # Running as root (0) is safer than custom user for permissions
    user: "0"
    ports:
      - "3100:3100"
    volumes:
      - $DATA_DIR/loki/config:/etc/loki
      - $DATA_DIR/loki/chunks:/loki/chunks
      - $DATA_DIR/loki/index:/loki/index
    command: -config.file=/etc/loki/loki-config.yaml
    restart: unless-stopped
    networks:
      - loki
    # Add healthcheck to ensure container stays running
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

  grafana:
    image: grafana/grafana:9.5.2
    container_name: grafana
    user: "472"
    ports:
      - "3000:3000"
    volumes:
      - $DATA_DIR/grafana/data:/var/lib/grafana
      - $DATA_DIR/grafana/provisioning:/etc/grafana/provisioning
      - $DATA_DIR/grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    restart: unless-stopped
    networks:
      - loki
    depends_on:
      - loki
    # Add healthcheck to ensure container stays running
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

networks:
  loki:
EOF

# Start the containers
cd $DATA_DIR
echo "Starting Docker containers..."
docker-compose up -d
check_error "Starting Docker containers"

# Verify containers are running
echo "Verifying containers are running..."
sleep 10
if docker ps | grep -q "grafana"; then
  echo "Grafana container is running"
else
  echo "ERROR: Grafana container failed to start"
  docker logs grafana
fi

if docker ps | grep -q "loki"; then
  echo "Loki container is running"
else
  echo "ERROR: Loki container failed to start"
  docker logs loki
fi

echo "Logging setup completed at $(date)"

# Configure SSH to allow connections from jumpbox
echo "Configuring SSH for jumpbox connections..."
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
touch /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Ensure SSH server is properly configured
cat > /etc/ssh/sshd_config.d/custom.conf << EOF
# Allow password authentication from internal network
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitRootLogin no
AllowUsers ubuntu

# Enhanced logging
LogLevel VERBOSE
EOF

# Restart SSH service to apply changes
systemctl restart sshd

echo "SSH configuration completed at $(date)"
