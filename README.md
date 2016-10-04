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
