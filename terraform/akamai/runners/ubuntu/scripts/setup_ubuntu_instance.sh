#!/bin/bash

sleep 10

# Check if username argument is provided
if [ -z "$1" ]; then
    echo "Error: Username not provided"
    exit 1
fi

instance_username=$1

# Check if password argument is provided
if [ -z "$2" ]; then
    echo "Error: Password not provided"
    exit 1
fi

instance_password=$2

# Update package list
apt update -y

# Install required components
apt install -y jq maven

# Create instance user with home directory
useradd -m -s /bin/bash $instance_username

# Set password for instance user using the provided password
echo "$instance_username:$developer_password" | chpasswd

# Add instance user to sudo group
usermod -aG sudo $instance_username

# Create .ssh directory for instance user
mkdir -p /home/$instance_username/.ssh

# Copy root's authorized_keys to instance user
if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/$instance_username/.ssh/
fi

# Set proper ownership and permissions
chown -R developer:developer /home/developer/.ssh
chmod 700 /home/developer/.ssh
chmod 600 /home/developer/.ssh/authorized_keys

# Install Docker if not already installed
if ! [ -x "$(command -v docker)" ]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    # Just to verify if this step was executed
    touch /tmp/docker-instalation-step.txt
fi

# Create docker group if it doesn't exist
groupadd -f docker

# Add instance user to docker group
usermod -aG docker $instance_username

# Create sudo rule for instance user
echo "$instance_username ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$instance_username

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
