#!/bin/bash

# Check if username argument is provided
if [ -z "$1" ]; then
    echo "Error: Runner username not provided"
    exit 1
fi

developer_name=$1

# Check if password argument is provided
if [ -z "$2" ]; then
    echo "Error: Runner password not provided"
    exit 1
fi

developer_password=$2

# Update package list
apt-get update


# Create runner user with home directory
useradd -m -s /bin/bash $developer_name

# Set password for runner user using the provided password
echo "$developer_name:$developer_password" | chpasswd

# Add developer to sudo group
usermod -aG sudo $developer_name

# Create .ssh directory for runner user
mkdir -p /home/$developer_name/.ssh

# Copy root's authorized_keys to developer user
if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/$developer_name/.ssh/
fi

# Set proper ownership and permissions
chown -R $developer_name:$developer_name /home/$developer_name/.ssh
chmod 700 /home/$developer_name/.ssh
chmod 600 /home/$developer_name/.ssh/authorized_keys

# Create sudo rule for developer user
echo "$developer_name ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$developer_name

# Verify the sudoers file
visudo -c

