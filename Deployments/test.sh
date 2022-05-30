echo "Updating" > /tmp/output.txt
sudo apt-get update
echo "Installing requriements" >> /tmp/output.txt
sudo apt-get install -y wget apt-transport-https software-properties-common
echo "Adding package" >> /tmp/output.txt
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
echo "Installing powershell" >> /tmp/output.txt
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
wget https://aka.ms/downloadazcopy-v10-linux

echo "Downloading AZCopy" >> /tmp/output.txt
tar -xvf downloadazcopy-v10-linux

pwsh 'install-module Az'
