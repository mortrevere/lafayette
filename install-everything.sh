set -ex

echo "Installing packages ..."
sudo apt-get update
sudo apt-get install -y locales-all
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo apt-get install -y wireguard certbot sshpass

echo "done installing packages."

echo "Creating passwords ..."
mkdir /opt/lafayette
dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/grafana.pw
dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/admin.psk
dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/client.psk
echo "done creating passwords"

echo "Starting web server & monitoring services (grafana/prometheus) ..."
chmod +x *.sh
./run-prometheus.sh
./run-grafana.sh
./run-nginx.sh
echo "done starting external first services"


