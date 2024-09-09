#!/usr/bin/env bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo."
   exit 1
fi

echo "Updating existing package list..."
apt update

echo "Installing prerequisite packages to allow apt to use Docker's repository..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg-agent

echo "Adding Docker’s official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo "Setting up the stable Docker repository..."
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

echo "Updating package list to include Docker packages from the new repository..."
apt update

echo "Installing Docker Engine..."
apt install -y docker-ce docker-ce-cli containerd.io

echo "Verifying Docker installation..."
docker --version

echo "Installing Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

echo "Applying executable permissions to the Docker Compose binary..."
chmod +x /usr/local/bin/docker-compose

echo "Verifying Docker Compose installation..."
docker-compose --version

echo "Adding current user to the Docker group to run Docker commands without sudo..."
usermod -aG docker $SUDO_USER

echo "Installation complete. You may need to reboot to apply group changes for Docker."