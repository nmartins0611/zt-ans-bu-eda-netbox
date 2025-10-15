#!/bin/bash

systemctl stop systemd-tmpfiles-setup.service
systemctl disable systemd-tmpfiles-setup.service

nmcli connection add type ethernet con-name enp2s0 ifname enp2s0 ipv4.addresses 192.168.1.10/24 ipv4.method manual connection.autoconnect yes
nmcli connection up enp2s0
echo "192.168.1.10 control.lab control" >> /etc/hosts

########


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






########
## install python3 libraries needed for the Cloud Report
dnf install -y python3-pip python3-libsemanage

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

  tasks: cat8000v-credential
    - name: Add network machine credential
      ansible.controller.credential:
        name: "cat8000v-credential"
        organization: "Default"
        credential_type: Machine
        controller_host: "https://localhost"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: fals
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
        scm_url: https://github.com/ansible-tmm/ansible-netbox-setup.git
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

    # - name: Debug SANDBOX_ID
    #   ansible.builtin.debug:
    #     msg: "https://control.{{ SANDBOX_ID }}/api/controller/"
    #   vars:
    #     SANDBOX_ID: "{{ lookup('env', '_SANDBOX_ID') | default('SANDBOX_ID_NOT_FOUND', true) }}"
    
    - name: (DECISIONS) Create an AAP Credential
      ansible.eda.credential:
        name: "AAP"
        description: "To execute jobs from EDA"
        inputs:
   #       host: "https://control.{{ SANDBOX_ID }}.instruqt.io/api/controller/"
           host: "https://control.ansible.workshop/api/controller/"
          username: "admin"
          password: "ansible123!"
        credential_type_name: "Red Hat Ansible Automation Platform"
   #     controller_host: "https://control.{{ SANDBOX_ID }}.instruqt.io"
        controller_host: "https://control.ansible.workshop/api/controller/"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        organization_name: Default
      # vars:
      #   SANDBOX_ID: "{{ lookup('env', '_SANDBOX_ID') | default('SANDBOX_ID_NOT_FOUND', true) }}"
    
    - name: (DECISIONS) Create a new DE
      ansible.eda.decision_environment:
   #     controller_host: "https://control.{{ SANDBOX_ID }}.instruqt.io"
        controller_host: "https://control.ansible.workshop/api/controller/"
        controller_username: admin
        controller_password: ansible123!
        validate_certs: false
        organization_name: Default
        name: "NetOps Decision Environment"
        description: "Decision Environment for NetOps workshop"
        image_url: "ghcr.io/ansible-network/autocon-de:latest"
      # vars:
      #   SANDBOX_ID: "{{ lookup('env', '_SANDBOX_ID') | default('SANDBOX_ID_NOT_FOUND', true) }}"
      
EOF
export ANSIBLE_LOCALHOST_WARNING=False
export ANSIBLE_INVENTORY_UNPARSED_WARNING=False

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup.yml

# curl -fsSL https://code-server.dev/install.sh | sh
# sudo systemctl enable --now code-server@$USER
