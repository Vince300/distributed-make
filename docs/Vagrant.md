# Environnement de test Vagrant

Le dossier `vagrant/` contient :

* `Vagrantfile` : définition de machines virtuelles de test
* `root-provision.sh` : installation des outils nécessaires sur les machines virtuelles

Pour utiliser cet environnement de test :

* Installer [Vagrant](https://www.vagrantup.com/).
* Installer [VirtualBox](https://www.virtualbox.org/).
* Installer le plugin "vagrant-hostmanager" :

```bash
    vagrant plugin install vagrant-hostmanager
```

* Suivre les instructions de https://github.com/devopsgroup-io/vagrant-hostmanager#passwordless-sudo pour éviter la
    demande de mot de passe sudo à chaque démarrage des machines virtuelles.

Une fois que tout est installé, les commandes suivantes peuvent être utilisées :

```bash
# Démarrage des machines définies dans le Vagrantfile
# La première fois, les images vont être téléchargées et configurées. Cela prend du temps.
# Les fois suivantes les machines installées seront reprises dans leur état actuel.
bin/rake vagrant up

# Déploiement de la version courante du code sur les machines, dans ~vagrant/distributed-make/current
bin/cap vagrant deploy

# Mise en pause des machines
bin/rake vagrant suspend

# Arrêt des machines (shutdown)
bin/rake vagrant halt

# Destruction des machines (pour réinstallation propre)
bin/rake vagrant destroy
```

Si _vagrant-hostmanager_ est configuré correctement, les machines peuvent être contactées en utilisant les noms
`worker1.dmake`, `worker2.dmake` etc. plutôt que leurs adresses IP.

```bash
$ ping worker1.dmake
Envoi d’une requête 'ping' sur worker1.dmake [10.20.1.11] avec 32 octets de données :
Réponse de 10.20.1.11 : octets=32 temps<1ms TTL=64
Réponse de 10.20.1.11 : octets=32 temps<1ms TTL=64
Réponse de 10.20.1.11 : octets=32 temps<1ms TTL=64
Réponse de 10.20.1.11 : octets=32 temps<1ms TTL=64

Statistiques Ping pour 10.20.1.11:
    Paquets : envoyés = 4, reçus = 4, perdus = 0 (perte 0%),
Durée approximative des boucles en millisecondes :
    Minimum = 0ms, Maximum = 0ms, Moyenne = 0ms
```

Le réseau privé utilisé pour les machines Vagrant est 10.20.1.0/24.
