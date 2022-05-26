# wait for internet ...
while ! ping -c 1 -W 1 8.8.8.8; do
    echo "En attente d'une connexion internet ..."
    sleep 1
done

# install/restart wireguard
apt update -y
wg-quick down lafayette
apt install -y wireguard dkms raspberrypi-kernel-headers wireguard-dkms wireguard-tools
ls /etc/wireguard/lafayette.conf || curl -H "Token: XXXXXXXXX" https://X.X.X.X/api/keys > /etc/wireguard/lafayette.conf
chmod 777 /etc/wireguard/lafayette.conf
wg-quick up lafayette


# install a modified raspberrypi_exporter
curl -fsSL "https://raw.githubusercontent.com/fahlke/raspberrypi_exporter/master/installer.sh" | sudo bash
wget https://raw.githubusercontent.com/mortrevere/lafayette/master/client/raspberrypi_exporter -O /usr/local/sbin/raspberrypi_exporter
rm /var/lib/node_exporter/textfile_collector/raspberrypi-metrics.prom && systemctl restart raspberrypi_exporter.timer

# install node_exporter
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

# turn on SSH
ssh-keygen -A
update-rc.d ssh enable
invoke-rc.d ssh start

# turn on VNC
apt-get install realvnc-vnc-server
systemctl enable vncserver-x11-serviced.service
systemctl start vncserver-x11-serviced.service