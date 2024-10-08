# Exit if any command fails
set -e

# Update package list and upgrade existing packages
echo "Updating package list and upgrading existing packages..."
apk update
apk upgrade

# Install Python 3
echo "Installing Python3..."
apk add python3

# Install Pip 3
echo "Installing Pip 3..."
wget https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --break-system-packages

# Install Ansible
echo "Installing Ansible..."
python3 -m pip install --user ansible --break-system-packages

# Install Git and Ansible
echo "Installing Git..."
apk add git 


# Clone playbook repository (modify this URL to your playbook repository)
PLAYBOOK_REPO_URL="https://github.com/LuisHN/RCIII.git"
PLAYBOOK_DIR="playbooks"

echo "Cloning playbook repository from $PLAYBOOK_REPO_URL..."
git clone "$PLAYBOOK_REPO_URL" "$PLAYBOOK_DIR"

echo "Setup complete."