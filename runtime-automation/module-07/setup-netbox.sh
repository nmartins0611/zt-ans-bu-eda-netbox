#!/bin/bash

docker compose --project-directory=/tmp/netbox-docker stop
docker compose --project-directory=/tmp/netbox-docker up -d netbox netbox-worker
