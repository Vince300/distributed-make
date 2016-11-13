# Environnement de test Vagrant

Le dossier `machines/` contient :

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
RAKE_ENV=vagrant bin/rake deploy

# Mise en pause des machines
bin/rake vagrant suspend

# Arrêt des machines (shutdown)
bin/rake vagrant halt

# Destruction des machines (pour réinstallation propre)
bin/rake vagrant destroy
```

Si _vagrant-hostmanager_ est configuré correctement, les machines peuvent être contactées en utilisant les noms
`worker1.dmake`, `worker2.dmake` etc. plutôt que leurs adresses IP.

```
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

Le réseau privé utilisé pour les machines Vagrant est 10.20.1.0/24. Par défaut l'adresse de la machine hôte est
10.20.1.1.

## Test en utilisant l'environnement Vagrant

Une fois les machines démarrées et le code déployé, les daemon de travail doivent être démarrés, avec la commande
suivante :

```bash
RAKE_ENV=vagrant bin/rake daemon:start
```

Depuis le dossier de développement, il est possible d'exécuter une compilation en utilisant la commande suivante :

```
bundle exec distributed-make \
    -f spec/fixtures/premier/Makefile \   # Makefile à exécuter
    --host 10.20.1.1                      # IP appartenant au subnet 10.20.1.0/24 pour communiquer avec les workers
```

L'état des services worker peut être vérifié en affichant les logs des machines Vagrant :

```
user@host $ bin/rake vagrant ssh worker1                  # Connexion SSH au worker 1
vagrant@worker1.dmake $ cd ~/distributed-make/shared/logs # Accès au dossier de log
vagrant@worker1.dmake $ tail -f worker.log                # Affichage du log (un worker/machine Vagrant)
```
