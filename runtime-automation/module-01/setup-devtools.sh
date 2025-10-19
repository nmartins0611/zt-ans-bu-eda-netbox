#!/bin/sh
su - rhel -s /bin/bash <<'EOF'
git clone http://gitea:3000/student/netbox.git
EOF
