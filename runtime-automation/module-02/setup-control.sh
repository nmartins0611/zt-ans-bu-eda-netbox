#!/bin/sh
echo "Starting module called module-02" >> /tmp/progress.log

sed -i 's|netbox_url: "{{ lookup('\''env'\'', '\''NETBOX_API'\'') }}"|netbox_url: "http://netbox:8000"|' /tmp/setup.yml
sed -i 's|netbox_token: "{{ lookup('\''env'\'', '\''NETBOX_TOKEN'\'') }}"|netbox_token: "0123456789abcdef0123456789abcdef01234567"|' /tmp/setup.yml

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml
