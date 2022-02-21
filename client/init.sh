apt update -y
wg-quick down lafayette
apt install -y wireguard dkms raspberrypi-kernel-headers wireguard-dkms wireguard-tools
ls /etc/wireguard/lafayette.conf || curl -H "Token: jUkqQsMYeFADK1s1O8gb3BMjF" http://164.132.48.50:8000/keys > /etc/wireguard/lafayette.conf
chmod 777 /etc/wireguard/lafayette.conf
wg-quick up lafayette


wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-armv7.tar.gz -O node_exporter.tar.gz
tar -xvzf node_exporter.tar.gz
cd node_exporter-1.3.1.linux-armv7/
cp ./node_exporter /usr/local/bin/node_exporter
chmod +x /usr/local/bin/node_exporter
useradd -m -s /bin/bash node_exporter
sudo mkdir /var/lib/node_exporter
chown -R node_exporter:node_exporter /var/lib/node_exporter

cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter

[Service]
# Provide a text file location for https://github.com/fahlke/raspberrypi_exporter data with the
# --collector.textfile.directory parameter.
ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory /var/lib/node_exporter/textfile_collector

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload 
sudo systemctl enable node_exporter.service
sudo systemctl start node_exporter.service