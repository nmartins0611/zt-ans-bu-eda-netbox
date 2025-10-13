#!/bin/bash
curl -k  -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}

sudo dnf install -y dnf-utils
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

git clone --depth=1 -b release https://github.com/netbox-community/netbox-docker.git /tmp/netbox-docker
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
#      CSRF_TRUSTED_ORIGINS: "http://netbox:8000"
#      DEBUG: "true"
    healthcheck:
      start_period: 180s
EOF


NETBOX_FQDN=netbox-8000-${_SANDBOX_ID}.env.play.intruqt.com

#https://netbox-8000-ef393avfgkx8.env.play.instruqt.com

### new docker-compose-plugin
docker compose --project-directory=/tmp/netbox-docker pull 
## daemon mode
docker compose --project-directory=/tmp/netbox-docker up -d netbox netbox-worker
