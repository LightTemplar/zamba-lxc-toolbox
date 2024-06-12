#!/bin/bash

# Authors:
# (C) 2021 Idea an concept by Christian Zengel <christian@sysops.de>
# (C) 2021 Script design and prototype by Markus Helmke <m.helmke@nettwarker.de>
# (C) 2021 Script rework and documentation by Thorsten Spille <thorsten@spille-edv.de>
# (C) 2024 Script enhancing by Light Templar

source /root/zamba.conf
source /root/constants-service.conf

# disabling IPv6
cat > /etc/sysctl.d/01-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
EOF

# Download the Docker installation script
curl -fsSL get.docker.com -o get-docker.sh

# Change permission to make it executable
chmod +x get-docker.sh

# Execute the downloaded script using exec
( exec ./get-docker.sh )

# Define the path to the docker.service file
SERVICE_FILE="/usr/lib/systemd/system/docker.service"

# Define the original and new ExecStart lines
ORIGINAL_EXEC="ExecStart=/usr/bin/dockerd"
NEW_EXEC="ExecStart=/usr/bin/dockerd --data-root /${LXC_SHAREFS_MOUNTPOINT}/docker"

# Use sed to replace the line
sed -i "s|${ORIGINAL_EXEC}|${NEW_EXEC}|g" $SERVICE_FILE

# Reload the systemd daemon to apply changes
systemctl daemon-reload

# Optionally restart the Docker service
systemctl restart docker.service


cd "/$LXC_SHAREFS_MOUNTPOINT"
echo "$LXC_GIT_REPO_URL"
git clone "$LXC_GIT_REPO_URL"

echo "'docker compose git' is ready to use!"
