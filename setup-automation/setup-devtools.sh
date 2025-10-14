#!/bin/bash
curl -k  -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt
update-ca-trust
rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm

subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}
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
dnf install unzip nano git podman -y 

## Configure sudoers for rhel user
echo "%rhel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/rhel_sudoers
chmod 440 /etc/sudoers.d/rhel_sudoers

# Setup rhel user
cp -a /root/.ssh/* /home/rhel/.ssh/.
chown -R rhel:rhel /home/rhel/.ssh
mkdir -p /home/rhel/lab_exercises/1.Terraform_Basics
mkdir -p /home/rhel/lab_exercises/2.Terraform_Ansible
mkdir -p /home/rhel/lab_exercises/3.Terraform_Provider
mkdir -p /home/rhel/lab_exercises/4.Terraform_AAP_Provider
mkdir -p /home/rhel/terraform-ee
mkdir /tmp/terraform_lab/
mkdir /tmp/terraform-ansible
mkdir /tmp/terraform-aap-provider
mkdir -p /home/rhel/.terraform.d/plugin-cache
#
#
#chown rhel:rhel /home/rhel/.terraformrc
chown -R rhel:rhel /home/rhel/lab_exercises/
chown rhel:rhel /home/rhel/.terraform.d/plugin-cache
chmod -R 777 /home/rhel/lab_exercises/

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install
chown -R rhel:rhel /home/rhel/lab_exercises
chmod -R 777 /home/rhel/lab_exercises
#
yum install -y dnf
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
yum install terraform -y
#
#
tee /home/rhel/lab_exercises/4.Terraform_AAP_Provider/main.tf << EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
####### UNCOMMENT the lines BELOW #######
#    aap = {
#      source = "ansible/aap"
#    }
  }
}
#
provider "aws" {
  region = "us-east-1"
}
#
resource "aws_instance" "tf-instance-aap-provider" {
  ami           = "ami-0005e0cfe09cc9050"
  instance_type = "t2.micro"
  tags = {
    Name = "tf-instance-aap-provider"
  }
}
####### UNCOMMENT the lines BELOW #######
#provider "aap" {
#  host     = "https://control"
#  username = "admin"
#  password = "ansible123!"
#  insecure_skip_verify = true
#}
####### UNCOMMENT the lines BELOW #######
#resource "aap_host" "tf-instance-aap-provider" {
#  inventory_id = 2
#  name = "aws_instance_tf"
#  description = "An EC2 instance created by Terraform"
#  variables = jsonencode(aws_instance.tf-instance-aap-provider)
#}
#
EOF
#
chown rhel:rhel /home/rhel/lab_exercises/4.Terraform_AAP_Provider/main.tf
#
#


# Create directory if it doesn't exist
mkdir -p /home/rhel/.aws

# Create the credentials file
cat > /home/rhel/.aws/credentials << EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

# Set proper ownership and permissions
chown rhel:rhel /home/rhel/.aws/credentials
chmod 600 /home/rhel/aws/credentials

cat > /home/rhel/aws/config << EOF
[default]
region = $AWS_DEFAULT_REGION
EOF

# Set proper ownership and permissions
chown rhel:rhel /home/rhel/aws/config
chmod 600 /home/rhel/aws/config

#
#Create the DEFAULT AWS VPC
su - rhel -c "aws ec2 create-default-vpc --region $AWS_DEFAULT_REGION"
#
#
#Create the S3 bucket for the users of this AAP / Terraform lab
# Variables
BUCKET_PREFIX="aap-tf-bucket"  # Change this to your desired bucket prefix
RANDOM_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')  # Generate a random UUID and convert to lowercase
BUCKET_NAME="${BUCKET_PREFIX}-${RANDOM_ID}"
AWS_REGION="$AWS_DEFAULT_REGION"  # Change this to your desired AWS region
#
#
# Create the S3 STORAGE BUCKET NEEDED BY THE AAP 2.X CHALLENGE
echo "Creating S3 bucket: $BUCKET_NAME in region $AWS_DEFAULT_REGION"
su - rhel -c "aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_DEFAULT_REGION"
#
# ## ansible home
# mkdir /home/$USER/ansible
# ## ansible-files dir
# mkdir /home/$USER/ansible-files

# ## ansible.cfg
# echo "[defaults]" > /home/$USER/.ansible.cfg
# echo "inventory = /home/$USER/ansible-files/hosts" >> /home/$USER/.ansible.cfg
# echo "host_key_checking = False" >> /home/$USER/.ansible.cfg

# ## chown and chmod all files in rhel user home
# chown -R rhel:rhel /home/$USER/ansible
# chmod 777 /home/$USER/ansible
# chown -R rhel:rhel /home/$USER/ansible-files

########
## install python3 libraries needed for the Cloud Report
dnf install -y python3-pip python3-libsemanage

#########
sudo dnf install python3.9 -y
sudo dnf remove python3 -y
sudo dnf upgrade crun -y
python3 --version
pip3 install --upgrade ansible-builder
#
#
touch /home/rhel/terraform-ee/execution-environment.yml
touch /home/rhel/terraform-ee/requirements.yml
chown -R rhel:rhel /home/rhel/
chmod -R 777 /home/rhel/
#
#
#Enable linger for the user `rhel`
loginctl enable-linger rhel
#
#
RUNAS="sudo -u rhel"
cd /tmp || exit 1
#Runs bash with commands in the here-document as the `rhel` user
$RUNAS bash<<'EOF'
podman login --username $REG_USER --password $REG_PASS registry.redhat.io
podman pull registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel8:latest
loginctl enable-linger rhel
EOF
#
#
#
cat <<EOF > /home/rhel/lab_exercises/1.Terraform_Basics/main.tf
# Use AWS provider for Terraform
provider "aws" {
  region = "us-east-1"
}
#
resource "aws_instance" "basic_rhel" {
  ami           = "ami-0005e0cfe09cc9050"
  instance_type = "t2.micro" 
#
  }  
#
EOF
#
#
chown -R rhel:rhel /home/rhel/
chmod -R 777 /home/rhel/
#


#
wget https://raw.githubusercontent.com/ansible-tmm/terraform-aap/refs/heads/main/images/2main.tf -P /tmp/
mv /tmp/2main.tf /home/rhel/lab_exercises/2.Terraform_Ansible/main.tf
#
#
tee /home/rhel/lab_exercises/2.Terraform_Ansible/variables.tf << EOF
# variables.tf
variable "aws_security_group" {
  default = "terraform_ec2" # AWS Security Group name
}
variable "instance_name" {
  default = "Terraform_ec2" # AWS Name of instance
}
variable "instance_type" {
  default = "t2.micro" # AWS Instance type
}
variable "private_ip_address" {
  type    = string
  default = "10.20.20.120"
}
EOF
#
#
tee /home/rhel/lab_exercises/3.Terraform_Provider/main.tf << EOF
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
# Provider
provider "aws" {
  region     = "us-east-1"
}
# Add key for ssh connection
resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = "<< Your id_rsa.pub >>"
}
# Add security group for ssh
resource "aws_security_group" "ssh" {
  name = "ssh"
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Add security group for http
resource "aws_security_group" "http" {
  name = "http"
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create ec2 instance
resource "aws_instance" "my_ec2" {
  ami           = "ami-0005e0cfe09cc9050" ##a RHEL AMI
  instance_type = "t2.micro"
  tags = {
    Name = "Terraform Instance"
  }
  key_name        = aws_key_pair.my_key.key_name
  security_groups = [aws_security_group.ssh.name, aws_security_group.http.name, "default"]
}
## Ansible Host Resource: 
EOF
#
#
tee /home/rhel/lab_exercises/3.Terraform_Provider/nginx.yml << EOF
---
- name: Install nginx on remote host
  hosts: nginx
  become: true
  gather_facts: false
  tasks:
    - name: Wait
      ansible.builtin.wait_for_connection:

    - name: Setup
      ansible.builtin.setup:

    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Start nginx
      ansible.builtin.service:
        name: nginx
        state: started
EOF
#
#
tee /home/rhel/lab_exercises/3.Terraform_Provider/inventory.yml << EOF
---
plugin: cloud.terraform.terraform_provider
EOF
#
#
chown -R rhel:rhel /home/rhel/
chmod -R 777 /home/rhel/
chmod -R 600 /home/rhel/.ssh/*
#
#
cd /home/rhel/lab_exercises
#
