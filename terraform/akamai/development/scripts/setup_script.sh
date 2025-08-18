#!/bin/bash

# Check if username argument is provided
if [ -z "$1" ]; then
    echo "Error: Developer username not provided"
    exit 1
fi

developer_name=$1

# Check if password argument is provided
if [ -z "$2" ]; then
    echo "Error: Developer password not provided"
    exit 1
fi

developer_password=$2

# Update package list
apt-get update

# Install jq
apt-get install -y jq

# Create developer user with home directory
useradd -m -s /bin/bash developer

# Set password for developer user using the provided password
echo "$developer_name:$developer_password" | chpasswd

# Add developer to sudo group
usermod -aG sudo developer

# Create .ssh directory for developer user
mkdir -p /home/developer/.ssh

# Copy root's authorized_keys to developer user
if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/developer/.ssh/
fi

# Set proper ownership and permissions
chown -R developer:developer /home/developer/.ssh
chmod 700 /home/developer/.ssh
chmod 600 /home/developer/.ssh/authorized_keys

# Install Docker if not already installed
if ! [ -x "$(command -v docker)" ]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
fi

# Create docker group if it doesn't exist
groupadd -f docker

# Add developer user to docker group
usermod -aG docker developer

# Create sudo rule for developer user
echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Verify the sudoers file
visudo -c

# Print confirmation
echo "Setup completed:"
echo "- jq installed: $(jq --version)"
echo "- Developer user created and added to sudo group"
echo "- Developer user added to docker group"
echo "- Docker installed and configured"

# Print important notice
echo -e "\nIMPORTANT:"
echo "1. Please change the developer password after first login"
echo "2. The developer user has been granted passwordless sudo access"
echo "3. The developer user has been added to the docker group"
