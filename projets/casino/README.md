# Casino

Machine à sous, roulette européenne, crash et blackjack, au toucher. Deux modes (réglage `mode`) : `demo`, avec des
jetons fictifs sans valeur, et `monnaie`, avec les vraies pièces de Lightman's Currency.

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

## Mode monnaie, pas à pas

1. Pose trois coffres : le **dépôt** et la **sortie**, accessibles aux joueurs, et la **réserve**, fermée aux joueurs
   (zone protégée, coffre hors de portée).
2. Relie l'ordinateur et les trois coffres au **même** réseau de modems filaires ; fais clic droit sur chaque modem
   pour l'activer : le chat affiche le nom du coffre (par exemple `minecraft:chest_0`). Utilise ces noms réseau,
   jamais un côté (`left`) : la réserve envoie vers la sortie par ce nom, ce que le casino ne peut pas tester sans
   déplacer de pièce.
3. Dans `/casino.cfg`, mets `mode = "monnaie"` et les trois noms dans `depot`, `sortie` et `reserve`.
4. Garnis la réserve de pièces, petites comprises : elle paie les gains. Sans petites pièces, un solde ne se rend
   pas exactement (« Pas la monnaie exacte »). La mise maximale de chaque jeu suit ce qu'elle contient.
5. Lance `/casino/diag` : il liste les périphériques, lit les valeurs des pièces et le contenu des coffres sans rien
   déplacer, et écrit `/casino-diag.txt`. Puis redémarre l'ordinateur.

Le joueur dépose ses pièces dans le dépôt (1 crédit = la plus petite pièce), joue, puis touche « Encaisser » au
hall : les pièces arrivent dans la sortie. Le solde appartient à la machine, pas à un joueur : qui part sans
encaisser le laisse au suivant. S'il manque un coffre ou le mod, le casino reste fermé et dit quoi faire.

## Réglages et fichiers

- `/casino.cfg` : réglages, décrits dans `projets/casino/reglages.lua`.
- `/casino.jetons` (démo) et `/casino.credits` (monnaie) : le solde. Un tour coupé par un arrêt est réglé au
  redémarrage comme si tu n'avais plus touché à rien.
- `/casino.log` : journal ; en mode monnaie, chaque dépôt, mise, gain et encaissement, pour rembourser à la main.

Retour au joueur : machine 95,3 %, roulette 97,3 %, crash 97 %, blackjack environ 99 % en jouant bien.
Aperçu hors jeu : `npm run apercu -- casino`, puis ouvre `apercu/casino.html`.
