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

Voir {file:docs/Install.md}

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

Il suffit ensuite d'afficher l'adresse indiquée dans le navigateur (généralement http://localhost:8808).

{file:docs/Architecture.md} présente l'architecture générale du système tel qu'implémenté.

## Environnement de test Vagrant

Voir {file:docs/Vagrant.md}
