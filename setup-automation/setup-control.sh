#!/bin/bash

systemctl stop systemd-tmpfiles-setup.service
systemctl disable systemd-tmpfiles-setup.service

nmcli connection add type ethernet con-name enp2s0 ifname enp2s0 ipv4.addresses 192.168.1.10/24 ipv4.method manual connection.autoconnect yes
nmcli connection up enp2s0
echo "192.168.1.10 control.lab control" >> /etc/hosts
echo "192.168.1.11 netbox.lab netbox" >> /etc/hosts
echo "192.168.1.12 devtools.lab devtools" >> /etc/hosts

########
systemctl stop firewalld
systemctl disable firewalld

RHEL_SSH_DIR="/home/rhel/.ssh"
RHEL_PRIVATE_KEY="$RHEL_SSH_DIR/id_rsa"
RHEL_PUBLIC_KEY="$RHEL_SSH_DIR/id_rsa.pub"

if [ -f "$RHEL_PRIVATE_KEY" ]; then
    echo "SSH key already exists for rhel user: $RHEL_PRIVATE_KEY"
else
    echo "Creating SSH key for rhel user..."
    sudo -u rhel mkdir -p /home/rhel/.ssh
    sudo -u rhel chmod 700 /home/rhel/.ssh
    sudo -u rhel ssh-keygen -t rsa -b 4096 -C "rhel@$(hostname)" -f /home/rhel/.ssh/id_rsa -N "" -q
    sudo -u rhel chmod 600 /home/rhel/.ssh/id_rsa*
    
    if [ -f "$RHEL_PRIVATE_KEY" ]; then
        echo "SSH key created successfully for rhel user"
    else
        echo "Error: Failed to create SSH key for rhel user"
    fi
fi

# Install collection(s)
ansible-galaxy collection install ansible.eda
ansible-galaxy collection install community.general
ansible-galaxy collection install netbox.netbox


########
## install python3 libraries needed for the Cloud Report
dnf install -y python3-pip python3-libsemanage
pip install pynetbox --user

# Create a playbook for the user to execute
tee /tmp/setup.yml << EOF
### Automation Controller setup 
###
---
- name: Setup Controller
  hosts: localhost
  connection: local
  collections:
    - ansible.controller

  vars:
    controller_host: localhost
    GUID: "{{ lookup('ansible.builtin.env', 'GUID') }}"
    DOMAIN: "{{ lookup('ansible.builtin.env', 'DOMAIN') }}"
    SANDBOX_ID: "{{ GUID }}.{{ DOMAIN }}"
    controller_host: "https://localhost"
    controller_username: admin
    controller_password: ansible123!
    inventory_name: netbox-inventory
    credentials_name: cat8000v-credential
    NETBOX_API_VAR: "{{ '{{' }} NETBOX_API {{ '}}' }}"
    NETBOX_TOKEN_VAR: "{{ '{{' }} NETBOX_TOKEN {{ '}}' }}"

  tasks:
    - name: Add network machine credential
      ansible.controller.credential:
        name: "cat8000v-credential"
        organization: "Default"
        credential_type: Machine
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        inputs:
          username: "admin"
          password: "ansible123!"

    - name: (EXECUTION) Create credential type for NetBox
      ansible.controller.credential_type:
        name: netbox-setup-api
        description: Credentials type for NetBox
        kind: cloud
        inputs: 
          fields:
            - id: NETBOX_API
              type: string
              label: NetBox Host URL
            - id: NETBOX_TOKEN
              type: string
              label: NetBox API Token
              secret: true
          required:
            - NETBOX_API
            - NETBOX_TOKEN
        injectors:
          env:
            NETBOX_API: "{{ NETBOX_API_VAR }}"
            NETBOX_TOKEN: "{{ NETBOX_TOKEN_VAR }}"
        state: present
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        
    - name: (EXECUTION) Create credentials for the netbox-setup
      ansible.controller.credential:
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!
        name: netbox-setup-creds
        credential_type: netbox-setup-api
        organization: Default
        inputs:
          NETBOX_API: "http://netbox:8000"
          NETBOX_TOKEN: "0123456789abcdef0123456789abcdef01234567"

    - name: (EXECUTION) Create new execution environment
      ansible.controller.execution_environment:
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!
        name: network-ee
        image: ghcr.io/ansible-network/autocon-ee:latest
        pull: missing
        
    - name: (EXECUTION) Create new execution environment
      ansible.controller.execution_environment:
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!
        name: netbox-ee
        image:  quay.io/acme_corp/network-netbox-eda-ee:latest
        pull: missing

    - name: (EXECUTION) Create new Project from git
      ansible.controller.project:
        name: "netbox-setup-project"
        organization: Default
        state: present
        scm_type: git
        scm_url: https://github.com/leogallego/ansible-netbox-setup.git
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!

    - name: (EXECUTION) Create an inventory in automation controller
      ansible.controller.inventory:
        name: netbox-setup-inventory
        organization: Default
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!

    - name: (EXECUTION) Create a new Job Template
      ansible.controller.job_template:
        name: "netbox-config-playbook"
        job_type: "run"
        organization: "Default"
        state: "present"
        inventory: "netbox-setup-inventory"
        become_enabled: True
        playbook: "netbox_setup.yml"
        project: "netbox-setup-project"
        credential: "netbox-setup-creds"
        execution_environment: "netbox-ee"
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!        
    
    - name: (DECISIONS) Create an AAP Credential
      ansible.eda.credential:
        name: "AAP"
        description: "To execute jobs from EDA"
        inputs:
          host: "https://control.ansible.workshop/api/controller/"
          username: "admin"
          password: "ansible123!"
        credential_type_name: "Red Hat Ansible Automation Platform"
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        organization_name: Default
    
    - name: (DECISIONS) Create a new DE
      ansible.eda.decision_environment:
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        organization_name: Default
        name: "NetOps Decision Environment"
        description: "Decision Environment for NetOps workshop"
        image_url: "ghcr.io/ansible-network/autocon-de:latest"

      
EOF
export ANSIBLE_LOCALHOST_WARNING=False
export ANSIBLE_INVENTORY_UNPARSED_WARNING=False

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml

# curl -fsSL https://code-server.dev/install.sh | sh
# sudo systemctl enable --now code-server@$USER



# sed -i 's|netbox_url: "{{ lookup('\''env'\'', '\''NETBOX_API'\'') }}"|netbox_url: "http://netbox:8000"|' /tmp/setup.yml
# sed -i 's|netbox_token: "{{ lookup('\''env'\'', '\''NETBOX_TOKEN'\'') }}"|netbox_token: "0123456789abcdef0123456789abcdef01234567"|' /tmp/setup.yml


# tee /tmp/setup_netbox.yml << EOF
# - name: "Configure a basic NetBox with a Cisco device"
#   connection: local
#   hosts: localhost
#   gather_facts: false
#   vars:
#     # netbox_url: "{{ lookup('env', 'NETBOX_API') }}"
#     # netbox_token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
#     netbox_url: "http://netbox:8000"
#     netbox_token: "0123456789abcdef0123456789abcdef01234567"
#     site: cisco-live-emea
#     manufacturer: cisco
#     device_type: cisco-c8000v
#     device_role: edge-router
#     platform: cisco.ios.ios

#   tasks:
#     - name: Create site with required parameters
#       netbox.netbox.netbox_site:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: cisco-live-emea
#           slug: cisco-live-emea
#         state: present

#     - name: Create manufacturer within NetBox with only required information
#       netbox.netbox.netbox_manufacturer:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: cisco
#         state: present

#     - name: Create device type within NetBox with only required information
#       netbox.netbox.netbox_device_type:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           slug: cisco-c8000v
#           model: cisco-c8000v
#           manufacturer: cisco
#         state: present

#     - name: Create device role within NetBox with only required information
#       netbox.netbox.netbox_device_role:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: edge-router
#           color: FFFFFF
#         state: present
    
#     - name: Create a custom field on device and virtual machine
#       netbox.netbox.netbox_custom_field:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           object_types:
#             - dcim.device
#           name: host
#           type: text
    
#     - name: Create a custom field on device and virtual machine
#       netbox.netbox.netbox_custom_field:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           object_types:
#             - dcim.device
#           name: port
#           type: text

#     - name: Create platform within NetBox with only required information
#       netbox.netbox.netbox_platform:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: cisco.ios.ios
#           slug: cisco-ios-ios
#           manufacturer: cisco
#         state: present


#     - name: Create device within NetBox with only required information
#       netbox.netbox.netbox_device:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: cat1
#           device_type: cisco-c8000v
#           device_role: Edge Router
#           site: cisco-live-emea
#           platform: cisco.ios.ios
#           custom_fields: { 'host': 'cisco', 'port': '22' }
#         state: present

#     - name: Create config context ntp and apply it to sites 
#       netbox.netbox.netbox_config_context:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: "ntp_servers"
#           description: "NTP Servers"
#           data: "{ \"ntp_servers\": [ \"time-a-g.nist.gov\", \"time-b-g.nist.gov\" ] }"
#           sites: "[cisco-live-emea]"

#     - name: Create config context banner and apply it to sites 
#       netbox.netbox.netbox_config_context:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: "login_banner"
#           description: "Login Banner"
#           data: "{ \"login_banner\": [ \"THIS IS A LOGIN BANNER SOURCED FROM NETBOX\" ] }"
#           sites: "[cisco-live-emea]"

#     # - name: Create a webhook
#     #   netbox.netbox.netbox_webhook:
#     #     netbox_url: "{{ netbox_url }}"
#     #     netbox_token: "{{ netbox_token }}"
#     #     data:
#     #       object_types:
#     #         - dcim.device
#     #       name: "EDA Webhook"
#     #       type_create: "true"
#     #       http_method: "post"
#     #       http_content_type: "application/json"
#     #       payload_url: "http://control:5001/endpoint/"
#     #       ssl_verification: "false"
#     #       body_template: !unsafe >-
#     #         {{ data }}

#     - name: Create vlan with all information
#       netbox.netbox.netbox_vlan:
#         netbox_url: "{{ netbox_url }}"
#         netbox_token: "{{ netbox_token }}"
#         data:
#           name: data_vlan
#           vid: 100
#           site: cisco-live-emea
#           status: Deprecated
#         state: present

# EOF

# ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup_netbox.yml

# ## Test API

# curl -H "Authorization: Token 0123456789abcdef0123456789abcdef01234567"   "http://netbox:8000/api/dcim/devices/?site=cisco-live-emea"

