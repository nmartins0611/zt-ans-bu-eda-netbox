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
retry "dnf install -y dnf-utils"

nmcli connection add type ethernet con-name eth1 ifname eth1 ipv4.addresses 192.168.1.12/24 ipv4.method manual connection.autoconnect yes
nmcli connection up eth1
echo "192.168.1.10 control.lab control" >> /etc/hosts
echo "192.168.1.11 netbox.lab netbox" >> /etc/hosts
echo "192.168.1.12 devtools.lab devtools" >> /etc/hosts



setenforce 0
echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
chmod 440 /etc/sudoers.d/rhel_sudoers
sudo -u rhel mkdir -p /home/rhel/.ssh
sudo -u rhel chmod 700 /home/rhel/.ssh
sudo -u rhel ssh-keygen -t rsa -b 4096 -C "rhel@$(hostname)" -f /home/rhel/.ssh/id_rsa -N ""
sudo -u rhel chmod 600 /home/rhel/.ssh/id_rsa*

systemctl stop firewalld
systemctl stop code-server
mv /home/rhel/.config/code-server/config.yaml /home/rhel/.config/code-server/config.bk.yaml

tee /home/rhel/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF

systemctl start code-server

# Set up error handling and DNS resolution
set -euxo pipefail
sudo dnf -y install jq nano yum-utils wget git 
sudo dnf -y update crun


# Temporary SELinux enforcement setting
setenforce 0

# Define variables
USER="rhel"



# Environment variables for rhel user
echo 'export PATH=$HOME/.local/bin:$PATH' >> /home/$USER/.profile
chown $USER:$USER /home/$USER/.profile


# Set SELinux booleans and start Nginx
setsebool -P httpd_can_network_connect on
systemctl start nginx

# # Prepare workspace directories
# WORKSHOP_DIR="/home/rhel/autocon2_aap_workshop"
# mkdir -p $WORKSHOP_DIR/{.vscode,source-of-truth,playbooks,rulebooks}
# mkdir -p /home/$USER/playbook-artifacts-autocon2
# chown -R $USER:$USER $WORKSHOP_DIR /home/$USER/playbook-artifacts-autocon2

# # Ansible Navigator configuration
# cat <<EOF > $WORKSHOP_DIR/ansible-navigator.yml
# ---
# ansible-navigator:
#   ansible:
#     inventory:
#       entries:
#       - $WORKSHOP_DIR/hosts
#   execution-environment:
#     container-engine: podman
#     enabled: true
#     image: autocon-ee:latest
#     pull:
#       policy: never
#   logging:
#     level: debug
#     file: $WORKSHOP_DIR/ansible-navigator.log
#   playbook-artifact:
#     save-as: /home/rhel/playbook-artifacts-autocon2/{playbook_name}-artifact-{time_stamp}.json
# EOF
# chown $USER:$USER $WORKSHOP_DIR/ansible-navigator.yml

# # Ansible Configuration
# cat <<EOF > $WORKSHOP_DIR/ansible.cfg
# [defaults]
# stdout_callback = yaml
# connection = smart
# timeout = 60
# deprecation_warnings = False
# devel_warning = False
# action_warnings = False
# system_warnings = False
# host_key_checking = False
# collections_on_ansible_version_mismatch = ignore
# retry_files_enabled = False
# interpreter_python = auto_silent

# [persistent_connection]
# connect_timeout = 200
# command_timeout = 200
# EOF
# chown $USER:$USER $WORKSHOP_DIR/ansible.cfg

# # VSCode settings for Ansible
# cat <<EOF > $WORKSHOP_DIR/.vscode/settings.json
# {
#     "ansible.python.interpreterPath": "/usr/bin/python",
#     "yaml.schemas": {
#         "https://raw.githubusercontent.com/ansible/ansible-rulebook/main/ansible_rulebook/schema/ruleset_schema.json": [
#             "rulebooks/*.yaml",
#             "rulebooks/*.yml"
#         ]
#     },
#     "files.associations": {
#         "rulebooks/*.yaml": "yaml",
#         "rulebooks/*.yml": "yaml"
#     }
# }
# EOF
# chown -R $USER:$USER $WORKSHOP_DIR/.vscode

# Enable linger for the rhel user
loginctl enable-linger $USER
# Pull the latest autocon-ee image
su - $USER -c 'podman pull ghcr.io/ansible-network/autocon-ee'

su - rhel -s /bin/bash <<EOF

# # Define the content of the git-credentials file
# GIT_CREDENTIALS_CONTENT="http://student:learn_ansible@gitea:3000"

# Create or overwrite the .git-credentials file
echo "http://student:learn_ansible@gitea:3000" > /home/rhel/.git-credentials

# Secure the file
chmod 600 /home/rhel/.git-credentials

git config --global credential.helper store
git config --global user.name 'student'
git config --global user.email 'student@localhost'

# Update code-server settings for Python
# mkdir -p ~/.config/Code/User
# cat > ~/.config/Code/User/settings.json <<EOL
# {
#     "python.defaultInterpreterPath": "/usr/bin/python3.11",
#     "python.pythonPath": "/usr/bin/python3.11"
#     "ansible.python.interpreterPath": "/usr/bin/python3.11"
# }
# EOL
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.11 2
sudo update-alternatives --set python /usr/bin/python3.11

ansible-galaxy collection install ansible.eda
ansible-galaxy collection install community.general
sudo ansible-galaxy collection install ansible.eda
sudo ansible-galaxy collection install community.general


sudo python3.11 -m pip install --force-reinstall --target=/usr/lib/python3.11/site-packages aiokafka --upgrade

