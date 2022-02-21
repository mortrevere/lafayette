wg-quick down lafayette
apt install -y wireguard
ls /etc/wireguard/lafayette.conf || curl -H "Token: jUkqQsMYeFADK1s1O8gb3BMjF" http://164.132.48.50:8000/keys > /etc/wireguard/lafayette.conf
chmod 777 /etc/wireguard/lafayette.conf
wg-quick up lafayette
