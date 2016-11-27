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

* [Humble Little Ruby Book](http://www.humblelittlerubybook.com/)
* [The dRuby Book](https://pragprog.com/book/sidruby/the-druby-book)

## Index

### Instructions
#### {file:docs/Install.md}
#### {file:docs/Vagrant.md}
#### {file:docs/Grid5000.md}

### Documentation
#### {file:docs/Architecture.md}
#### {file:docs/FileSystem.md}

## Quickstart

Suivre les instructions d'installation de {file:docs/Install.md} pour installer Ruby et les dépendances nécessaires.

Une fois les dépendances installées, exécuter `bin/yard server` pour lire la documentation complète avec liens à
l'adresse http://localhost:8808.

Puis, configurer Vagrant puis exécuter une compilation, tel que décrit dans {file:docs/Vagrant.md}).

L'architecture générale du système est décrite dans {file:docs/Architecture.md}.

## Tests

Le groupe `test` du Gemfile doit être installé (option par défaut). Les tests peuvent être exécutés avec la commande :

```bash
bin/rake test
```
