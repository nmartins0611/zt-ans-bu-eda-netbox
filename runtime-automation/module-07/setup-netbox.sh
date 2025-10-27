#!/bin/sh
echo "Starting module called module-07" >> /tmp/progress.log

docker compose --project-directory=/tmp/netbox-docker stop
docker compose --project-directory=/tmp/netbox-docker up -d netbox netbox-worker
