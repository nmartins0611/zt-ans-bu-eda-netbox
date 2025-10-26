#!/bin/sh
echo "Starting module called module-05" >> /tmp/progress.log

tee /tmp/setup_netbox-playbooks.yml << EOF

---
- name: "5 - EDA: NetBox Playbooks"
  hosts: localhost
  become: false
  gather_facts: false

  collections:
    - ansible.controller

  vars:
    controller_host: "https://localhost"
#    SANDBOX_ID: "{{ lookup('env', '_SANDBOX_ID') | default('SANDBOX_ID_NOT_FOUND', true) }}"
    controller_username: admin
    controller_password: ansible123!
    inventory_name: netbox-inventory
    credentials_name: cat8000v-credential


  tasks:
    - name: (EXECUTION) Create NetBox Playbooks Project from git
      ansible.controller.project:
        name: "NetBox Playbooks"
        organization: Default
        state: present
        scm_type: git
        scm_url: https://github.com/leogallego/cisco-netbox-playbooks.git
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!

    - name: (EXECUTION) Create a Configure NTP Servers Job Template
      ansible.controller.job_template:
        name: "Configure NTP Servers"
        job_type: "run"
        organization: "Default"
        state: "present"
        inventory: "NetBox Dynamic Inventory"
        playbook: "configure_ntp.yml"
        project: "NetBox Playbooks"
        credentials:
          - "cat8000v-credential"
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!

    # - name: (EXECUTION) Create a Configure VLANS Job Template
    #   ansible.controller.job_template:
    #     name: "Configure VLANs"
    #     job_type: "run"
    #     organization: "Default"
    #     state: "present"
    #     inventory: "NetBox Dynamic Inventory"
    #     playbook: "configure_vlans.yml"
    #     project: "NetBox Playbooks"
    #     credentials:
    #       - "cat8000v-credential"
    #       - "NetBox API"
    #     validate_certs: false
    #     controller_username: admin
    #     controller_password: ansible123!

    - name: (EXECUTION) Create a Configure Login Banner Job Template
      ansible.controller.job_template:
        name: "Configure Login Banner"
        job_type: "run"
        organization: "Default"
        state: "present"
        inventory: "NetBox Dynamic Inventory"
        playbook: "configure_login_banner.yml"
        project: "NetBox Playbooks"
        credential: "cat8000v-credential"
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!


    - name: Create a workflow job template with nodes
      ansible.controller.workflow_job_template:
        name: "Provision New Device Workflow"
        description: "Workflow for NTP, VLAN and Banner"
        inventory: "NetBox Dynamic Inventory"
        workflow_nodes:
          - identifier: NTP
            unified_job_template:
              organization:
                name: Default
              name: "Configure NTP Servers"
              type: job_template
            related:
              success_nodes: []
              failure_nodes: []
              always_nodes:
                - identifier: Banner
              credentials: []
          - identifier: Banner
            all_parents_must_converge: false
            unified_job_template:
              organization:
                name: Default
              name: "Configure Login Banner"
              type: job_template
            related:
              success_nodes: []
              failure_nodes: []
              always_nodes: []
              credentials: []
        validate_certs: false
        controller_username: admin
        controller_password: ansible123!

EOF

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup_netbox-playbooks.yml
