# Architecture

## Ressources

### dRuby (distributed Ruby)

* [DRb module (Ruby stdlib documentation)](http://ruby-doc.org/stdlib-2.3.1/libdoc/drb/rdoc/DRb.html)

### Tuple space

* [Tuple Space (Wikipedia)](https://en.wikipedia.org/wiki/Tuple_space)
* [Ruby Rinda (Wikipedia)](https://en.wikipedia.org/wiki/Rinda_%28Ruby_programming_language%29)
* [Rinda module (Ruby stdlib documentation)](http://ruby-doc.org/stdlib-2.3.1/libdoc/rinda/rdoc/Rinda.html)

## Présentation générale

dRuby implémente un système objet distribué entre plusieurs instance de
processus Ruby, qui peuvent être exéuctés sur la même machine ou sur plusieurs
machines différentes. Les objets distants sont représentés par des proxys dRuby
(de type DRb::DRbObject) qui répondent aux méthodes de l'objet, en transferrant
les arguments et le valeurs de retour via la couche réseau.

dRuby a été utilisé pour implémenter une version Ruby du concept de *tuple
space*, qui représente un espace de tuples dans lequel des opérations atomiques
(bloquantes ou non) peuvent être exécutées.

Ces opérations sont :

* `write(tuple)` : Ajouter un tuple à l'espace. Les doubles sont autorisés.
* `take(pattern) => tuple` : Retire un tuple de l'espace correspondant au 
modèle fourni. Cette opération peut être bloquante (ne retourne que si un
tuple peut être retourné) ou non (`nil` retourné après le timeout défini.)
* `read(pattern) => tuple` : Lit un tuple dans l'espace. Suit les mêmes règles
que `take`, mais ne retire pas le tuple lu.
* `notify(...) => notifier` : Démarre l'écoute d'évènements se produisant dans
l'espace. Les évènements sont les différentes opérations portant sur les
tuples, `take`, `write` et `delete` (expiration d'un tuple).

Un `pattern` est un modèle de tuple devant être retourné. `[:task, nil, nil]`
correspond à n'importe quel 3-uplet dont le premier élément est le symbole
`:task`.

Les tuples peuvent avoir une durée de vie infinie (par défaut) ou une
expiration contrôlée par un délai (fixe), ou un objet distribué. Si l'objet
contrôlant le timeout est une référence à un objet distant, le tuple sera
supprimé dès que la machine distante ne sera plus en mesure de communiquer.

Ce système permet de détecter, pour toutes les machines ayant un tuple dans
l'espace en cours, les pannes franches et crash-recovery. Le délai détection
dépend de la fréquence d'exécution de la boucle de nettoyage des tuples
expirés.

## Tuple space et workers

La machine pilote (driver) met à disposition un tuple space, et un `RingServer`
responsable d'annoncer la présence d'un tuple space joignable sur un
sous-réseau donné. Les workers peuvent ensuite attendre les notifications du
`RingServer` pour rejoindre le tuple space indiqué. Si les machines peuvent
être effectivement rassemblées sur un même sous-réseau supportant le broadcast,
il n'est pas nécessaire de spécifier les noms/adresses IP des machines lors
d'une compilation.

Des machines peuvent être même ajoutées ou retirées dynamiquement lors de la
compilation, afin d'adapter la puissance de calcul. La détection des tâches
abandonnées est réalisée par le driver, à l'aide des systèmes de timeout sur
les tuples dans l'espace.

## Services

Un tuple space permet d'implémenter un ensemble de services accessibles par
leur nom. Les services sont représentés par des tuples
`[:service, name, object]` où :

* `:service` identifie ce tuple comme un tuple *service*
* `name` est le nom du service (un symbole Ruby)
* `object` est l'instance du service (objet distribué)

Les services actuellement implémentés sont :

* `:job`, type {DistributedMake::Services::JobService}, fournit des
informations sur la tâche de compilation en cours.
* `:log`, type {DistributedMake::Services::LogService}, fournit des
méthodes pour accéder à l'objet de journalisation du processus pilote.
* `:rule`, type {DistributedMake::Services::RuleService}, fournit des
informations (commandes à exécuter et dépendances) pour la compilation
des différentes cibles du Makefile.

Un `read([:service, :job, nil])` permet de récupérer l'objet service pour
exécuter des opérations. L'objet service peut être une référence (objet
distant) ou une valeur (copie de l'objet distant) selon le rôle du service.
L'accès à un service par copie est plus efficace, mais ne permet pas
d'interagir avec le fournisseur du service, par exemple pour reporter des
messages au fournisseur, sans passer par des tuples (utile pour le logging
centralisé par exemple).
