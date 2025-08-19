#!/bin/bash

#This token is taken from environment or by argument
token=$1

#
github_accoutn=$2

# Create the folder
mkdir actions-runner && cd actions-runner 

# Download the latest runner package
curl -o actions-runner-linux-x64-2.327.1.tar.gz \
-L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz

# Validate the Hash
echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz

##################################################################################################################################
##################################################################################################################################
# This part mus be fixed.. 
# 1) To send the token, the github user, the proyect, and other parameters
# 2) The argument to responde all argument to create the runner in ubuntu machine
# 3) Only ond config option must be get.

# Create the runner and start the configuration experience
./config.sh \
--url https://github.com/$github_accoutn/$repository \
--token $token \
--name ubuntu-runner-001
--labels self-hosted,linux

./config.sh --url https://github.com/$github_accoutn/$repository --token $token



##################################################################################################################################
##################################################################################################################################

# run it!
./run.sh

status=$(echo $?)

echo "Final Status  $status"

