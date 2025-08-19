#!/bin/bash

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if terraform is installed
if ! command_exists terraform; then
    echo "Error: terraform is not installed"
    exit 1
}

# Get instance IP using terraform output
INSTANCE_IP=$(terraform output -raw instance_ip)
INSTANCE_LABEL=$(terraform output -raw instance_label)
SSH_COMMAND=$(terraform output -raw ssh_command)

# Example 1: Simple output usage
echo "Instance Details:"
echo "Label: $INSTANCE_LABEL"
echo "IP Address: $INSTANCE_IP"
echo "SSH Command: $SSH_COMMAND"

# Example 2: Using output in a ping test
echo -e "\nTesting connection to instance..."
ping -c 3 $INSTANCE_IP

# Example 3: Using output in an SSH command (with timeout)
echo -e "\nTesting SSH connection..."
timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$INSTANCE_IP "echo 'SSH connection successful'"

# Example 4: Getting all outputs in JSON format and parsing with jq
if command_exists jq; then
    echo -e "\nAll Terraform outputs (JSON):"
    terraform output -json | jq '.'
    
    # Example of filtering specific output
    echo -e "\nInstance IP from JSON:"
    terraform output -json | jq -r '.instance_ip.value'
fi

# Example 5: Using output in a conditional statement
if [[ $INSTANCE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "\nValid IP address detected: $INSTANCE_IP"
else
    echo -e "\nInvalid IP address format"
fi

# Example 6: Creating a hosts entry
echo -e "\nExample hosts entry:"
echo "$INSTANCE_IP    $INSTANCE_LABEL.local    $INSTANCE_LABEL"
