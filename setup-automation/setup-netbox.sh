#!/bin/bash

retry() {
    for i in {1..3}; do
        echo "Attempt $i: $2"
        if $1; then
            return 0
        fi
        [ $i -lt 3 ] && sleep 5
    done
    echo "Failed after 3 attempts: $2"
    exit 1
}

retry "curl -k -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt"
retry "update-ca-trust"
retry "rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm"
retry "subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}"
retry "dnf install -y dnf-utils git nano"
retry "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
retry "dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y"
setenforce 0

nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.addresses 192.168.1.11/24 ipv4.method manual connection.autoconnect yes
nmcli connection up eth1
echo "192.168.1.10 control.lab control" >> /etc/hosts
echo "192.168.1.11 netbox.lab netbox" >> /etc/hosts
echo "192.168.1.12 devtools.lab devtools" >> /etc/hosts


# Retry function
retry() {
    local max_attempts=3
    local delay=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: $@"
        if "$@"; then
            echo "Command succeeded"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Command failed. Retrying in ${delay}s..."
            sleep $delay
        fi
        
        ((attempt++))
    done
    
    echo "Command failed after $max_attempts attempts"
    return 1
}

# Clone repository
retry git clone --depth=1 -b release https://github.com/netbox-community/netbox-docker.git /tmp/netbox-docker

# Create docker-compose override file
cat <<EOF | tee /tmp/netbox-docker/docker-compose.override.yml
services:
  netbox:
    ports:
      - 8000:8080
    environment:
      ALLOWED_HOSTS: '*'
      POSTGRES_USER: "netbox"
      POSTGRES_PASSWORD: "netbox"
      POSTGRES_DB: "netbox"
      POSTGRES_HOST: "postgres"
      REDIS_HOST: "redis"
      SKIP_SUPERUSER: "false"
      SUPERUSER_EMAIL: "admin@example.com"
      SUPERUSER_PASSWORD: "netbox"
      SUPERUSER_NAME: "admin"
    healthcheck:
      start_period: 180s
EOF

# Start docker service
systemctl start docker
systemctl enable docker

# Wait for docker to be ready
sleep 5

# Pull images with retry
retry docker compose --project-directory=/tmp/netbox-docker pull

# Start containers with retry
retry docker compose --project-directory=/tmp/netbox-docker up -d netbox netbox-worker

echo "Setup complete!"
