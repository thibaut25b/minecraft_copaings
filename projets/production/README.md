# Production

Débit des items d'un réseau AE2 en /s, /min et /h sur un moniteur tactile : liste des objets suivis, détail, histogramme.

## Matériel

- Un ordinateur avancé et un moniteur avancé (72 x 26 cases au moins pour le gabarit riche ; sinon compact, ou
  l'écran de l'ordinateur à la souris).
- Un ME Bridge d'Advanced Peripherals relié au réseau AE2 (contre l'ordinateur, ou par modem filaire).

## Installation

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua production
```

Puis lance `/production/diag` : il liste les périphériques, l'état du pont, le contenu du
coffre modèle et les stocks suivis.
`/production/diag iron` cherche dans l'AE les items dont l'id ou le nom contient « iron » : c'est l'id à mettre en config.
Le détail est écrit dans `/production-diag.txt`.

## Réglages

Dans `/production.cfg`, décrits dans `projets/production/reglages.lua`.

Méthode simple, le coffre modèle : pose un coffre relié à l'ordinateur, mets `coffre = "left"` (le côté, ou le nom
réseau donné par clic droit sur le modem), puis dépose-y un exemplaire de chaque item à suivre. Le coffre est relu à
chaque mesure : ajouter ou retirer un item met l'écran à jour sans redémarrer. Ne relie pas ce coffre à l'AE, sinon
ses items comptent dans le stock.

Les objets de la config passent en premier, puis ceux du coffre, sans doublon :

```lua
{
  coffre = "left",
  unite = "min",
  objets = {
    { objet = "minecraft:iron_ingot", nom = "" },
  },
}
```

`nom = ""` : le nom lu dans l'AE. Redémarre l'ordinateur après un changement de `/production.cfg`.

## Utilisation

- Boutons `/s` `/min` `/h` : unité de tous les débits.
- Toucher un objet : son détail (débits 10 s, 1 min, 10 min, 1 h, variation depuis le départ) et son histogramme.
- `Reset` : repart de zéro pour cet objet. Un débit précédé de `~` est mesuré sur moins que sa fenêtre.
- L'historique reste en mémoire : il est perdu au redémarrage. `/production.log` : journal des erreurs.

Aperçu hors jeu : `npm run apercu -- production`, puis ouvre `apercu/production.html`.
