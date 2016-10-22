# Installation

Ce document décrit les étapes d'installation nécessaires à l'exécution du code
du projet. Ces étapes sont automatisées pour le déploiement sur les serveurs de
travail.

## Système

Les outils suivants doit être disponibles : 

* curl
* git

Le projet a été testé sur une distribution Debian 8 (Jessie) pour les workers.
Le pilote de make distribué peut être exécuté sur tout OS supporté.

## Code

### Ruby 2.3.1

Le projet a été testé avec cette version exacte de Ruby. L'exécution avec
d'autres versions n'est pas garantie.

Les étapes à suivre sont les suivantes :

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

### Bundler

Bundler est le système de gestion de dépendances pour les projets Ruby. Son
installation au niveau du système est nécessaire pour être exécuté ensuite
depuis le projet.

```bash
# Installation en utilisant la version de Ruby courante
gem install bundler

# Vérification de la version
bundle -v # doit afficher Bundler 1.13.2 ou plus
```
