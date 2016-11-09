###Présentation des différents VLANs

Il existe 3 types de VLANs :

- Local VLAN :
Complètement isolé du reste de Grid 5000. Pas d'IP routing. Accessible uniquement via SSH (le nom de l'hôte est kavlan-<ID>)
Pour accéder aux autres noeuds : <hostname-X>-kavlan-<ID> ou via la commande "kaconsole".
Attention, impossible de monter /home en NFS, sinon la machine risque de ne pas booter

- Routed VLAN :
Ces VLANs ne sont pas isolés au niveau de la 3ème couche : les paquets IP sont routés => pas besoin de SSH pour atteindre les noeuds du VLAN

- Global VLAN :
Ces VLANs s'étendent sur tous les sites de Grid5000 (ie on peut tout configurer à partir d'un VLAN global). Les noeuds dans une VLAN global utilisent le même domaine de broadcast.
Il y a un unique VLAN global par site. Ils sont à réserver par un utilisateur.
Pas besoin de routage entre deux noeuds d'un même VALN global. Pour atteindre ces noeuds, le routage est configuré sur le routeur du site où se trouve le VLAN global réservé.
Les noms des hôtes sont : <hostname-X>-kavlan-<ID>

###Réserver un VLAN

Les réservation sont à faire avec OAR.

Par exemple, pour réserver3 noeuds et un VLAN local, exécuter ceci :
```
oarsub -t deploy -l {"type='kavlan-local'"}/vlan=1+/nodes=3 -I
```

Ensuite, pour obtenir l'ID de ce VLAN, faire :
```
kavlan -V
```

Pour exécuter cette commande en dehors du shell ouvert par OAR, faire :
```
kavlan -V -j JOBID
```

Voir le tableau sur le site de [grid5000](https://www.grid5000.fr/mediawiki/index.php/KaVLAN) pour connaître les ID et les adresses IP des VLANs.

###Configuration des VLANs

```
kavlan --help
```

