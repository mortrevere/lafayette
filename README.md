# Lafayette

Ou comment contrôler une flotte de Raspberry Pi via Internet, en condition difficiles.

## Pré-requis

Ce guide ne traitera pas de comment obtenir les éléments suivants, qui sont nécéssaires à la mise en place de Lafayette :

- Un serveur (nommé `S` dans ce guide) accessible publiquement sur Internet (IP public), comme un VPS Elite OVH, avec un accès SSH. Configuration minimale recommandée : OS Debian 11, 8 CPU, 8Go de RAM
- Un ordinateur (nommé `A` dans ce guide) sous Linux (ou Mac, ou Windows si vraiment mais ce guide considère que l'administrateur est sous Linux)
- Connaître les bases d'un terminal sous Linux (ligne de commande)
- Au moins 1 Raspberry Pi (nommé `R` dans ce guide)

## Usage de la documentation

### Identification des machines
Les extraits de code correspondant à des commandes commencent par une lettre suivie du caractère `>`. La lettre indique la machine sur laquelle éxecuter la commande.
Par exemple : 

```
A> echo "cette commande est à éxecuter sur l'ordinateur de l'administrateur (votre ordinateur)"
S> echo "cette commande est à éxécuter sur le serveur, via SSH"
R> echo "cette commande est à éxécuter sur le raspberry pi, en SSH ou via un clavier et une souris"
```

Si vous copier/coller les commandes, la partie `(A/S/R)> ` est à ignorer.

### Adresse IP publique du serveur

Le serveur pour faire fonctionner Lafayette doit avoir une IP publique. Dans ce guide, elle est représentée par `X.X.X.X`
Cette IP vous est normalement transmise par le fournisseur du VPS après son installation.



## Installation du serveur

1. Se connecter au serveur : 

```
ssh debian@X.X.X.X
```

`X.X.X.X` étant l'IP publique du serveur. Un nom d'utilisateur (ici, `debian`) et un mot de passe ont dû vous être communiqué par le fournisseur du VPS (par mail par exemple).

Vous devez avoir l'accès root sans mot de passe (`sudo su` ne doit pas demander de mot de passe), ou l'accès root en direct (`ssh root@X.X.X.X`) pour la suite du guide.

2. Ajouter un alias vers le serveur 

Ajouter le contenu suivant au fichier `/etc/ssh/ssh_config` (en faisant `A> sudo nano /etc/ssh/ssh_config`)

```
Host lafayette
    HostName X.X.X.X
    User debian
    Port 22
```

Vérifiez que la connexion fonctionne en faisant : `A> ssh lafayette`. Vous devez vous retrouver connecté au serveur après avoir entré le mot de passe.



3. Copier le code de Lafayette sur le serveur : 

Pour installer le serveur Lafayette, copiez tout le code sur le VPS, dans le home de l'utilisateur root :

```
S> sudo bash -c "apt update && apt install -y git && cd ~/ && git clone https://github.com/mortrevere/lafayette.git"
```

Si vous avez une copie du code sur votre ordinateur, vous pouvez aussi l'envoyer sur le serveur :

```
A> scp ~/lafayette.tar.gz lafayette:/tmp/lafayette.tar.gz && ssh lafayette "sudo tar -xzvf /tmp/lafayette.tar.gz -C ~/lafayette"
```

4. Installer le serveur Lafayette

Lancez le script d'installation : 

```
S> sudo su
S> cd ~/lafayette && bash ./install-everything.sh
```

L'installation doit se finir par le message `Lafayette is up and running !` suivi d'une liste de mot de passe.
Par exemple : 

```
Lafayette is up and running !
Here are the passwords :

Client password (for Raspberry Pi) : id98ofnpqjJ4kPRe5nlpXJPir2cxMVrSZY4Xx/Kycnk

Admin password (for you) : wAbtgAQNTTwMkkIMVuMMVieEZMkYmYl6fuUVnszUbjY

Grafana password : x71qXVY4Kt94r+5MlexZQWcvktjNyVTIvNo7tagnurg
```

**IMPORTANT :** ***Gardez ces mots de passe en lieu sûr, ce sont les clés d'accès à votre réseau.***

5. Accéder à Grafana

Allez sur `http://X.X.X.X/grafana`, et connectez vous avec le nom d'utilisateur `lafayette` et le mot de passe grafana récupéré à l'étape précédente.

6. Créer un accès administrateur

Éxécutez la commande : 

```
A> curl -H "Token: XXXXXXXXXXXX" http://X.X.X.X/api/admin-keys | tee lafayette.conf
```

en remplaçant `XXXXXXXXXXXX` par le mot de passe admin récupéré à l'étape 5.

Le fichier `lafayette.conf` contient maintenant votre configuration admin pour wireguard. Référez-vous à [la documentation Wireguard](https://www.wireguard.com/install/) pour l'installation sur votre machine à partir de ce fichier de configuration.

Pour savoir si votre accès fonctionne, testez les commandes `A> wg` et `A> ping -c 1 10.0.0.1`. Vous devriez avoir un résultat semblable à : 

```
root@A:~# wg
interface: lafayette
  public key: y+HSq9PyOqXsFwUnzH1rmJUcrBn2ldM2rQjR9kerzVw=
  private key: (hidden)
  listening port: 38138

peer: biZR7qeXGoUuIv8JpH2QNSuJBRg6YE4t3XNl3b4Bjl4=
  endpoint: 51.75.142.13:51194
  allowed ips: 10.0.0.0/16
  latest handshake: 10 seconds ago
  transfer: 348 B received, 436 B sent
  persistent keepalive: every 25 seconds

root@A:~# ping -c 1 10.0.0.1
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
64 octets de 10.0.0.1 : icmp_seq=1 ttl=64 temps=14.3 ms

--- statistiques ping 10.0.0.1 ---
1 paquets transmis, 1 reçus, 0 % paquets perdus, temps 0 ms
rtt min/avg/max/mdev = 14.328/14.328/14.328/0.000 ms
```

L'avant dernière ligne indique que tout fonctionne : `1 paquets transmis, 1 reçus, 0 % paquets perdus, temps 0 ms`

## Installation des Raspberry Pi 

Sur chaque Raspberry Pi , éxécutez le script situé dans `client/init.sh` (en tant que root)

La seule ligne à modifier pour votre besoin est la suivante (ligne 11) : 

```
ls /etc/wireguard/lafayette.conf || curl -H "Token: XXXXXXXXX" https://X.X.X.X/api/keys > /etc/wireguard/lafayette.conf
```

où le token et l'adresse IP du serveur doivent être renseignés.

Ce script est idempotent, il peut être éxécuté à chaque démarrage du Raspberry Pi. Sinon, il est de votre responsabilité de faire correctement démarrer le client wireguard au moment du boot.

Une fois le premier Raspberry Pi configuré et connecté, il apparaitra dans Grafana.