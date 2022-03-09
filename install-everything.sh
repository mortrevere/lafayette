if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script MUST be run as root ! Type 'sudo su' and try again ?"
    exit
fi


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
sudo apt-get install -y wireguard certbot sshpass netcat

echo "done installing packages."

echo "Creating passwords ..."
ls /opt/lafayette || mkdir /opt/lafayette

ls /opt/lafayette/grafana.pw || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/grafana.pw)
ls /opt/lafayette/admin.psk || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/admin.psk)
ls /opt/lafayette/client.psk || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/client.psk)
ls /opt/lafayette/redis.pw || (dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64 -w 0 | rev | cut -b 2- | rev > /opt/lafayette/redis.pw)
echo "done creating passwords"

echo "Getting my own public IP address ..."
curl ipinfo.io/ip > /opt/lafayette/myip
echo -n "my ip is : "
cat /opt/lafayette/myip
echo

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
set +e 
docker stop lafayette-api
docker rm lafayette-api
set -e
./run-api-docker.sh

until [ -f /opt/lafayette/server.conf ]
do
    echo "Waiting for API to start ..."
    sleep 5
done
echo "API started"

ls /etc/wireguard/lafayette.conf || ln -s /opt/lafayette/server.conf /etc/wireguard/lafayette.conf
echo "done running Lafayette API"

docker ps
docker logs lafayette-api

echo "Starting up wireguard ..."
set +e
wg-quick down lafayette
set -e
wg-quick up lafayette
wg
echo "wireguard should be up."

echo "Setting up firewall & routing ..."
iptables -A FORWARD -i lafayette -o lafayette -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
echo "done"

set +x
echo "Running final checks ..."
docker ps -q | wc -l | grep -q 5
echo "5 docker containers are running"
ping -c 2 10.0.0.1
echo "wireguard seems up"
curl --fail localhost:3000
echo "grafana seems up"
curl --fail localhost:9090
echo "prometheus seems up"
nc -vz localhost 6379
echo "redis seems up"
curl --fail localhost:80/api/screens
echo "Lafayette API seems up"
curl --fail http://localhost/prometheus/api/v1/query?query=up%7Bjob%3D%22lafayette-master%22%7D%3D%3D1 | grep -q localhost:1337
echo "nginx is working well and prometheus is scraping the Lafayette API"


echo "Lafayette is up and running !"


echo "Here are the passwords :"
echo
echo -n "Client password (for Raspberry Pi) : "
cat /opt/lafayette/client.psk
echo 
echo -n "Admin password (for you) : "
cat /opt/lafayette/admin.psk
echo 
echo -n "Grafana password : "
cat /opt/lafayette/grafana.pw

