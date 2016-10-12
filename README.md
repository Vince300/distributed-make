# Make distribué (2016-2017)

## Equipe

* ASSOULINE Daniel (assoulid)
* GIROUX Baptiste (girouxb)
* SIBILLE Gaspard (sibilleg)
* TAVERNIER Vincent (taverniv)

## Ressources

### Sujet

* [ISI Systèmes Distribués et Cloud avancé](https://ensiwiki.ensimag.fr/index.php/ISI_Syst%C3%A8mes_Distribu%C3%A9s_et_Cloud_avanc%C3%A9)

### Tutoriels

* [Ruby in Twenty Minutes](https://www.ruby-lang.org/en/documentation/quickstart/)
* [Why's (Poignant) Guide to Ruby](http://poignant.guide/book/chapter-1.html)
* [Lancez-vous dans la programmation avec Ruby](https://openclassrooms.com/courses/lancez-vous-dans-la-programmation-avec-ruby)

### Livres

* [Humble Little Ruby Book](https://www.dropbox.com/s/b8n41fqogjhpvxq/Humble%20Little%20Ruby%20Book.pdf?dl=0)
* [The dRuby Book](https://www.dropbox.com/s/ju9xa9n4du0z2cj/The%20dRuby%20Book.pdf?dl=0)

## Prérequis

* Ruby 2.3.1

```bash
# Installation de RVM (https://rvm.io)
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable

# Redémarrer le shell ou
source ~/.bashrc

# Installation de Ruby (option 1, peut nécessiter sudo)
rvm install 2.3.1
rvm use 2.3.1

# Installation de JRuby (option 2, ne nécessite pas sudo)
rvm install jruby
rvm use jruby

# Vérification de la version
ruby -v # doit afficher 2.3.1
```

* Bundler

```bash
# Installation en utilisant la version de Ruby courante
gem install bundler

# Vérification de la version
bundle -v # doit afficher Bundler 1.13.2 ou plus
```

## Installation des dépendances

Installation automatisée des dépendances pour le développement :

```bash
bundle install --binstubs
```

## Tests

Le groupe `test` du Gemfile doit être installé (option par défaut). Les tests peuvent être exécutés avec la commande :

```bash
bin/rake test
```

## Documentation

La documentation peut être affichée grâce au serveur `yard`.

```bash
bin/yard server
```

Il suffit ensuite d'afficher l'adresse indiquée dans le navigateur.

## Environnement de test Vagrant

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
