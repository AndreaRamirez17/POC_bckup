#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Token not provided"
    exit 1
fi
token=$1

if [ -z "$2" ]; then
    echo "Error: GitHub Account not provided"
    exit 1
fi
github_account=$2

if [ -z "$3" ]; then
    echo "Error: Repository not provided"
    exit 1
fi
repository=$3

sudo apt update -y

# Create the folder
mkdir ~/actions-runner && cd  ~/actions-runner 

# Download the latest runner package
curl -o actions-runner-linux-x64-2.327.1.tar.gz \
-L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz

# Validate the Hash
echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz

##################################################################################################################################
##################################################################################################################################
# Create the runner 

./config.sh \
--unattended \
--url https://github.com/$github_account/$repository \
--token $token \
--labels linode-ubuntu-runner-001

##################################################################################################################################
##################################################################################################################################

# run it!
./run.sh &

echo "Ending script"

