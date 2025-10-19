#!/bin/sh
echo "Starting module called module-02" >> /tmp/progress.log

sed -i 's|netbox_url: "{{ lookup('\''env'\'', '\''NETBOX_API'\'') }}"|netbox_url: "http://netbox:8000"|' /tmp/setup.yml
sed -i 's|netbox_token: "{{ lookup('\''env'\'', '\''NETBOX_TOKEN'\'') }}"|netbox_token: "0123456789abcdef0123456789abcdef01234567"|' /tmp/setup.yml


tee /tmp/setup_netbox.yml << EOF
- name: "Configure a basic NetBox with a Cisco device"
  connection: local
  hosts: localhost
  gather_facts: false
  vars:
    # netbox_url: "{{ lookup('env', 'NETBOX_API') }}"
    # netbox_token: "{{ lookup('env', 'NETBOX_TOKEN') }}"
    netbox_url: "http://netbox:8000"
    netbox_token: "0123456789abcdef0123456789abcdef01234567"
    site: cisco-live-emea
    manufacturer: cisco
    device_type: cisco-c8000v
    device_role: edge-router
    platform: cisco.ios.ios

  tasks:
    - name: Create site with required parameters
      netbox.netbox.netbox_site:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: cisco-live-emea
          slug: cisco-live-emea
        state: present

    - name: Create manufacturer within NetBox with only required information
      netbox.netbox.netbox_manufacturer:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: cisco
        state: present

    - name: Create device type within NetBox with only required information
      netbox.netbox.netbox_device_type:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          slug: cisco-c8000v
          model: cisco-c8000v
          manufacturer: cisco
        state: present

    - name: Create device role within NetBox with only required information
      netbox.netbox.netbox_device_role:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: edge-router
          color: FFFFFF
        state: present
    
    - name: Create a custom field on device and virtual machine
      netbox.netbox.netbox_custom_field:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          object_types:
            - dcim.device
          name: host
          type: text
    
    - name: Create a custom field on device and virtual machine
      netbox.netbox.netbox_custom_field:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          object_types:
            - dcim.device
          name: port
          type: text

    - name: Create platform within NetBox with only required information
      netbox.netbox.netbox_platform:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: cisco.ios.ios
          slug: cisco-ios-ios
          manufacturer: cisco
        state: present


    - name: Create device within NetBox with only required information
      netbox.netbox.netbox_device:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: cat1
          device_type: cisco-c8000v
          device_role: Edge Router
          site: cisco-live-emea
          platform: cisco.ios.ios
          custom_fields: { 'host': 'cisco', 'port': '22' }
        state: present

    - name: Create config context ntp and apply it to sites 
      netbox.netbox.netbox_config_context:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: "ntp_servers"
          description: "NTP Servers"
          data: "{ \"ntp_servers\": [ \"time-a-g.nist.gov\", \"time-b-g.nist.gov\" ] }"
          sites: "[cisco-live-emea]"

    - name: Create config context banner and apply it to sites 
      netbox.netbox.netbox_config_context:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: "login_banner"
          description: "Login Banner"
          data: "{ \"login_banner\": [ \"THIS IS A LOGIN BANNER SOURCED FROM NETBOX\" ] }"
          sites: "[cisco-live-emea]"

    # - name: Create a webhook
    #   netbox.netbox.netbox_webhook:
    #     netbox_url: "{{ netbox_url }}"
    #     netbox_token: "{{ netbox_token }}"
    #     data:
    #       object_types:
    #         - dcim.device
    #       name: "EDA Webhook"
    #       type_create: "true"
    #       http_method: "post"
    #       http_content_type: "application/json"
    #       payload_url: "http://control:5001/endpoint/"
    #       ssl_verification: "false"
    #       body_template: !unsafe >-
    #         {{ data }}

    - name: Create vlan with all information
      netbox.netbox.netbox_vlan:
        netbox_url: "{{ netbox_url }}"
        netbox_token: "{{ netbox_token }}"
        data:
          name: data_vlan
          vid: 100
          site: cisco-live-emea
          status: Deprecated
        state: present

EOF

ANSIBLE_COLLECTIONS_PATH=/tmp/ansible-automation-platform-containerized-setup-bundle-2.5-9-x86_64/collections/:/root/.ansible/collections/ansible_collections/ ansible-playbook -i /tmp/inventory /tmp/setup_netbox.yml

## Test API

curl -H "Authorization: Token 0123456789abcdef0123456789abcdef01234567"   "http://netbox:8000/api/dcim/devices/?site=cisco-live-emea"

