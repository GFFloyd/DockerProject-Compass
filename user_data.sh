#!/bin/bash

# Configure and install docker engine and it's dependencies on an Ubuntu machine

# Set up docker's apt repo

# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
mkdir -p /etc/apt/keyrings /dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install docker's latest version and it's dependecies

apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
# apt-get install docker.io -y

# Change permission modifier for all users instead of only root being allowed to run docker commands  
usermod -aG docker ubuntu

# systemctl start docker
# systemctl enable docker

# Download, compile and install efs-utils to prepare for the efs mounting (this is needed on Ubuntu machines)

apt-get update
apt-get -y install git binutils rustc cargo pkg-config libssl-dev gettext
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb

# Make an EFS directory and mount the cloud's EFS into it

mkdir -p /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <fs-dns-address>:/ /efs

# Enter into the EFS directory and use docker compose to initialize the wordpress container based on the yaml manifest

cd /efs
docker compose up -d



