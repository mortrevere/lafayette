set -ex

echo "Installing packages ..."
sudo apt-get update
sudo apt-get install -y locales-all
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
ls /usr/share/keyrings/docker-archive-keyring.gpg || (curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo apt-get install -y wireguard certbot sshpass

echo "done installing packages."

echo "Creating passwords ..."
ls /opt/lafayette || mkdir /opt/lafayette

ls /opt/lafayette/grafana.pw || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/grafana.pw)
ls /opt/lafayette/admin.psk || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/admin.psk)
ls /opt/lafayette/client.psk || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/client.psk)
ls /opt/lafayette/redis.pw || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/redis.pw)
echo "done creating passwords"


echo "Starting web server & monitoring services (grafana/prometheus) ..."
chmod +x run-*.sh
set +e 
docker stop prometheus
docker rm prometheus
docker stop grafana
docker rm grafana
docker stop nginx
docker rm nginx
set -e
./run-prometheus.sh
./run-grafana.sh
./run-nginx.sh
echo "done starting external first services"

docker ps

echo "Starting Redis ..."
cd vpn
chmod +x *.sh
cp ./redis.conf /opt/lafayette/redis.conf
echo >> /opt/lafayette/redis.conf
echo -n "requirepass " >> /opt/lafayette/redis.conf
cat /opt/lafayette/redis.pw | tee -a /opt/lafayette/redis.conf
set +e 
docker stop redis
docker rm redis
set -e
./run-redis.sh
echo "done with redis"

docker ps

echo "Building Lafayette API ..."
docker build . -f dockerfile-api -t lafayette-api
./run-api-docker.sh
ls /etc/wireguard/lafayette.conf || ln -s /opt/lafayette/server.conf /etc/wireguard/lafayette.conf
echo "done running Lafayette API"

docker ps
docker logs lafayette-api

echo "Starting up wireguard ..."
wg-quick up lafayette
wg
echo "wireguard up."

