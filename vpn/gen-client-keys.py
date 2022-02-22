import os
import redis
import subprocess


from fastapi import FastAPI, Request, HTTPException, Header, Response
from pydantic import BaseModel
from fastapi.responses import JSONResponse
import logging
from prometheus_client import start_http_server, Gauge


app = FastAPI()
logger = logging.getLogger("app")


def run(cmd, noerr=False, stdin=False, wait=True):
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=subprocess.PIPE,
        preexec_fn=os.setsid,
    )
    stdout, stderr = b"", b""
    if stdin:
        stdout, stderr = p.communicate(input=bytes(stdin, "utf-8"))
    elif wait:
        stdout = p.stdout.read()
        stderr = p.stderr.read()

    stdout, stderr = stdout.decode("utf-8"), stderr.decode("utf-8")
    if stderr and not noerr:
        print(f"ERROR: {stderr}")
        return False
    if not wait:
        return p

    return stdout


r = redis.Redis(host="localhost", port=6379, db=0)

SRV_PRIV_KEY_PATH = "/opt/lafayette/private.key"
SRV_PUB_KEY_PATH = "/opt/lafayette/public.key"
SERV_PUBLIC_IP = "164.132.48.50"

with open("/opt/lafayette/client.psk") as f:
    PSK = f.read().strip()

with open("/opt/lafayette/admin.psk") as f:
    ADMIN_PSK = f.read().strip()


try:
    os.mkdir("/opt/lafayette")
except FileExistsError:
    pass

SERV_PRIVATE_KEY, SERV_PUBLIC_KEY = "", ""


def init_srv_keys():
    global SERV_PRIVATE_KEY, SERV_PUBLIC_KEY
    if not os.path.exists(SRV_PRIV_KEY_PATH) or not os.path.exists(SRV_PUB_KEY_PATH):
        print("Generating server keypair ...")
        private_key = run("wg genkey").strip()
        public_key = run("wg pubkey", stdin=private_key).strip()
        with open(SRV_PUB_KEY_PATH, "w") as f:
            f.write(public_key)
        with open(SRV_PRIV_KEY_PATH, "w") as f:
            f.write(private_key)

    with open(SRV_PUB_KEY_PATH) as f:
        SERV_PUBLIC_KEY = f.read().strip()
    with open(SRV_PRIV_KEY_PATH) as f:
        SERV_PRIVATE_KEY = f.read().strip()

    print(f"Server public key : {SERV_PUBLIC_KEY}")
    print(f"Server private key : {SERV_PRIVATE_KEY}")

    if not SERV_PRIVATE_KEY or not SERV_PUBLIC_KEY:
        os.unlink(SRV_PRIV_KEY_PATH)
        os.unlink(SRV_PUB_KEY_PATH)
        init_srv_keys()


init_srv_keys()

wg_config_tmpl = (
    """
[Interface]
Address = 10.0.0.1/16
ListenPort = 51194
"""
    f"PrivateKey = {SERV_PRIVATE_KEY}"
)

wg_config_peer_block = """
[Peer]
PublicKey = {}
AllowedIPs = {}/32,{}/32
"""

WG_CONFIG_FILE = wg_config_tmpl

print(wg_config_tmpl)

if r.hlen("wg-keys") == 0:
    last_byte = 1
    pen_byte = 0
    for i in range(1000):
        last_byte += 1
        private_key = run("wg genkey").strip()
        public_key = run("wg pubkey", stdin=private_key).strip()
        print(private_key, public_key)
        r.hset("wg-keys", public_key, private_key)
        ip = f"10.0.{pen_byte}.{last_byte}"
        r.hset("ips", public_key, ip)
        if last_byte == 253:
            pen_byte += 1
            last_byte = 0
        WG_CONFIG_FILE += wg_config_peer_block.format(public_key, ip, ip.replace("10.0.", "10.10."))
else:
    keys = r.hgetall("wg-keys")
    ips = r.hgetall("ips")
    for public_key, private_key in keys.items():
        ip = ips[public_key].decode("utf-8")
        #print(f"'{ip}:9100',", end="")
        WG_CONFIG_FILE += wg_config_peer_block.format(
            public_key.decode("utf-8"), ip, ip.replace("10.0.", "10.10.")
        )

with open("/opt/lafayette/server.conf", "w") as f:
    print(WG_CONFIG_FILE)
    f.write(WG_CONFIG_FILE)


WG_CLIENT_CONFIG_TMPL = (
    """
[Interface]
PrivateKey = {}
Address = {}/16
 
[Peer]
PersistentKeepalive = 25
"""
    f"PublicKey = {SERV_PUBLIC_KEY}"
    """
AllowedIPs = 10.0.0.1/32,10.10.0.0/16
"""
    f"Endpoint = {SERV_PUBLIC_IP}:51194"
)

WG_ADMIN_CONFIG_TMPL = (
    """
[Interface]
PrivateKey = {}
Address = {}/16
 
[Peer]
PersistentKeepalive = 25
"""
    f"PublicKey = {SERV_PUBLIC_KEY}"
    """
AllowedIPs = 10.0.0.0/16
"""
    f"Endpoint = {SERV_PUBLIC_IP}:51194"
)

__used_client_slots = Gauge('lafayette_used_client_slots', 'Number of client slots used', ['ip'])
__used_admin_slots = Gauge('lafayette_used_admin_slots', 'Number of client slots used', ['ip'])
for public_key in r.lrange("used-wg-pub-keys", 0, -1):
    ip = r.hget("ips", public_key).decode("utf-8")
    __used_client_slots.labels(ip=ip).set(1) #r.llen("used-wg-pub-keys"))

for public_key in r.lrange("used-admin-pub-keys", 0, -1):
    ip = r.hget("ips", public_key).decode("utf-8")
    __used_admin_slots.labels(ip=ip).set(1) #r.llen("used-admin-pub-keys"))
start_http_server(1337)



@app.get("/prom-targets")
async def prom_targets():
    ips = r.hgetall("ips").values()
    tgts = [f"{ip.decode('utf-8')}:9100" for ip in ips if ip.startswith(b"10.0.")]
    return [{"targets": tgts, "labels": {"type": "lafayette"}}]


@app.get("/api/admin-keys")
async def keys(token=Header(None)):
    if token != ADMIN_PSK:
        return JSONResponse(status_code=403)
    public_key, private_key = next(r.hscan_iter("wg-keys"))
    deletion = r.hdel("wg-keys", public_key)
    save = r.lpush("used-admin-pub-keys", public_key)
    # print(save)
    ip = r.hget("ips", public_key).decode("utf-8").replace("10.0.", "10.10.")
    r.hset("ips", public_key, ip)
    # print(deletion, k, ip)
    __used_admin_slots.labels(ip=ip).inc()
    return Response(
        content=WG_ADMIN_CONFIG_TMPL.format(
            private_key.decode("utf-8"), ip
        ),
        media_type="application/text",
    )
    
@app.get("/api/keys")
async def keys(token=Header(None)):
    if token != PSK:
        return JSONResponse(status_code=403)
    public_key, private_key = next(r.hscan_iter("wg-keys"))
    deletion = r.hdel("wg-keys", public_key)
    save = r.lpush("used-wg-pub-keys", public_key)
    # print(save)
    ip = r.hget("ips", public_key)
    __used_client_slots.labels(ip=ip).inc()
    # print(deletion, k, ip)
    return Response(
        content=WG_CLIENT_CONFIG_TMPL.format(
            private_key.decode("utf-8"), ip.decode("utf-8")
        ),
        media_type="application/text",
    )