# Casino (démo)

Machine à sous, roulette européenne et crash, au toucher, avec des jetons fictifs sans aucune valeur.

## Matériel

- Un ordinateur avancé.
- Un moniteur avancé collé à l'ordinateur : 51 x 19 cases au moins, idéalement 100 x 38 (8 x 6 blocs à l'échelle
  0.5). Sans moniteur, le casino se joue sur l'écran de l'ordinateur, à la souris.
- Facultatif : un haut-parleur (speaker) collé à l'ordinateur pour le son.

## Installation

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua casino
```

Q (sur l'ordinateur) ou Ctrl+T arrête le casino.

## Réglages et fichiers

- `/casino.cfg` : mises, jetons de départ, recharge, inactivité, thème, son. Sens de chaque réglage :
  `projets/casino/reglages.lua`.
- `/casino.jetons` : le solde. Un tour coupé par un arrêt est réglé au redémarrage comme si tu n'avais plus touché
  à rien (machine et roulette : résultat déjà tiré ; crash : perdu, sauf au plafond x100).
- `/casino.log` : journal.

Retour au joueur : machine 95,3 %, roulette 97,3 %, crash 97 %. Les règles de chaque jeu sont sous « Règles ».
Aperçu hors jeu : `npm run apercu -- casino`, puis ouvre `apercu/casino.html`.
