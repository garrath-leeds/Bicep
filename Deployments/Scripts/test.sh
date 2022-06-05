echo "Updating" > /tmp/output.txt
sudo apt-get update
echo "Installing requriements" >> /tmp/output.txt
sudo apt-get install -y wget apt-transport-https software-properties-common htop
echo "Adding package" >> /tmp/output.txt
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
echo "Installing powershell" >> /tmp/output.txt
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
wget https://aka.ms/downloadazcopy-v10-linux

echo "Downloading AZCopy" >> /tmp/output.txt
mkdir -p /tmp/azcopy
tar -xvf downloadazcopy-v10-linux -C /tmp/azcopy
sudo chmod +x /tmp/azcopy/azcopy_linux_amd64*/azcopy

pwsh -Command 'install-module Az -Force'

