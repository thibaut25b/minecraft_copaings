# Production

Production et consommation des items d'un réseau AE2 sur un moniteur tactile : liste classée, détail, courbe, alertes.

## Matériel

- Un ordinateur avancé et un moniteur avancé (72 x 26 cases au moins pour le gabarit riche ; sinon compact, ou
  l'écran de l'ordinateur à la souris).
- Un ME Bridge d'Advanced Peripherals relié au réseau AE2 (contre l'ordinateur, ou par modem filaire).

## Installation

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua production
```

`/production/diag` : périphériques, pont, coffre modèle et clés suivies. `/production/diag iron` : id, nbt, nom et
quantité des items dont l'id ou le nom contient « iron ». `/production/diag tout` : durée et mémoire d'un
`getItems()` complet. Détail dans `/production-diag.txt`.

## Deux façons de l'utiliser

- Tout le réseau (par défaut, `tout = true`) : un seul `getItems()` par mesure, onglet `Tout`.
- Une sélection : pose un coffre relié à l'ordinateur (pas à l'AE), mets `coffre = "left"` (côté ou nom réseau) et
  dépose un exemplaire de chaque item à suivre ; il est relu à chaque mesure. Onglet `Suivis`. Avec `tout = false`,
  seuls ces items sont lus.

## Réglages

Dans `/production.cfg`, décrits dans `projets/production/reglages.lua`. Nouveaux : `tout`, `consommation`,
`fenetre`, `sens`, `exclure`, `debit_mini`, `seuil_coupure`, `delai_aller_retour`, `delai_alerte`, `objets` avec
`nbt`. Redémarre l'ordinateur après un changement.

## Ce que mesure l'écran

- Des variations de stock entre deux mesures : un item produit puis consommé dans la même période est invisible.
- Une baisse inhabituelle suivie, dans `delai_aller_retour` secondes, d'une hausse inhabituelle de même taille
  (aller-retour) est ignorée.
- Une lecture où trop de types disparaissent d'un coup est ignorée (réseau incomplet, chunk déchargé) ; 6 de suite
  deviennent le nouvel état du réseau.
- `~` devant un débit : historique plus court que la fenêtre. L'historique est perdu au redémarrage.

Sur un très gros réseau, `getItems()` peut coûter au serveur : augmente `periode`. Journal : `/production.log`.

Aperçu hors jeu : `npm run apercu -- production`, puis ouvre `apercu/production.html`.
