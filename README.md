# Programmes ComputerCraft

Programmes Lua pour CC: Tweaked 1.120 (Minecraft 1.21.1, NeoForge, Advanced Peripherals).
Un dépôt, plusieurs projets : `projets/<nom>/` pour chaque projet, `commun/` pour le code partagé.

## Installer un projet en jeu

Sur un ordinateur, tape :

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua colonie
```

Relancer la même commande met à jour. La config du projet (`/<nom>.cfg`) n'est jamais écrasée.
Le dépôt doit être public pour que `wget` atteigne les fichiers bruts, et `http` doit être activé sur le serveur
(`http.enabled` dans `computercraft-server.toml`).

## Projets

- `colonie` : fourniture automatique des requêtes de la colonie MineColonies depuis un réseau AE2, avec affichage.
- `galerie` : écrans de démonstration animés (usine, colonie, trains, vitrine des briques) ; toucher le moniteur
  passe au suivant, Q quitte.
- `casino` : casino de démonstration (machine à sous, roulette, crash, blackjack) au toucher, avec des jetons fictifs.

## Jouer dans le navigateur

`npm run jouer -- galerie` écrit `apercu/jouer-galerie.html` : ouvre-la, le vrai programme tourne sur un moniteur
tactile émulé (clic = toucher, clavier transmis). Les fichiers écrits restent dans le navigateur (« Réinitialiser »).

## Tests

Les tests tournent hors du jeu (Node et Fengari) :

```
npm install
npm test               # tout
npm test -- colonie    # fichiers de test dont le chemin contient « colonie »
```

Les règles de code sont dans `CLAUDE.md`.
