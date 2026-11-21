# Programmes ComputerCraft

Programmes Lua pour CC: Tweaked 1.120 (Minecraft 1.21.1, NeoForge, pack ATM10 avec Advanced Peripherals 0.8.2a).
Un dépôt, plusieurs projets : chaque projet vit dans `projets/<nom>/`, le code partagé dans `commun/`.
Priorité : qualité et maintenabilité.

## Commandes

```
npm install            # une fois : Fengari, l'interpréteur Lua des tests
npm test               # compile tous les .lua puis joue tests/**/test_*.lua
npm test -- colonie    # seulement les fichiers de test dont le chemin contient « colonie »
```

Aucun test ne lance le jeu : la logique se teste contre les faux périphériques de `tests/faux/`.

## Arborescence

| Chemin | Rôle | Sur l'ordinateur en jeu |
| --- | --- | --- |
| `install.lua` | Installeur commun à tous les projets | lancé par `wget run` |
| `commun/` | Bibliothèques partagées (dessin, config, journal, périphériques) | `/commun/` |
| `projets/<nom>/` | Un projet ; `manifeste.lua` liste ce qui s'installe | `/<nom>/` |
| `tests/<nom>/`, `tests/commun/` | Tests ; `tests/faux/` : faux périphériques | jamais installé |
| `docs/peripheriques.md` | Formes exactes des API tirées des jars | jamais installé |

Modules : `require("commun.dessin")`, `require("colonie.requetes")`. Le point d'entrée d'un projet ajoute `/?.lua` à
`package.path` ; les tests ajoutent `./?.lua` et `./projets/?.lua`.

## Règles non négociables

1. **Français partout** : textes visibles, identifiants métier, commentaires, commits. Tutoiement, phrases courtes.
2. **Lua commun à CC et aux tests** : syntaxe Lua 5.1/5.2 seulement (ni `//`, ni opérateurs bit à bit, ni `<const>`),
   aucune dépendance externe. Pas de globale : tout module finit par `return` de sa table.
3. **Logique pure séparée du jeu** : décider (tables en entrée, tables en sortie, testable) d'un côté, agir sur les
   périphériques de l'autre. Seuls le point d'entrée et les modules d'action touchent `peripheral`, `term`, `os`, `fs`.
4. **Une connaissance = un seul endroit** : avant d'écrire un helper, chercher dans `commun/`. Un nom de champ d'API
   se lit dans `docs/peripheriques.md`, jamais deviné ; ce qui y est « non vérifié » se lit de façon défensive.
5. **Un périphérique peut disparaître à tout instant** (chunk déchargé, câble cassé) : tout appel passe par `pcall`
   à la frontière, l'erreur s'affiche et se journalise, la boucle continue. Jamais de `pcall` fourre-tout dans la
   logique pure : l'inattendu s'y propage.
6. **Jamais de boucle sans pause** : toute boucle longue rend la main (`sleep`, `os.pullEvent`), sinon CC tue le
   programme (« too long without yielding »).
7. **Zéro code mort**, zéro réglage en dur : ce qui dépend du monde (côtés, noms, périodes) est dans la config.
8. **Tout bug corrigé ajoute un test de non-régression.** Tout invariant métier a son test, dont le nom dit la
   décision verrouillée.
9. **Commentaires : des faits brefs sur le code actuel**, jamais d'historique. Un en-tête d'une ligne par fichier,
   une ligne `---` au-dessus de chaque fonction publique.
10. **Aucun tiret cadratin ni demi-cadratin** (U+2014, U+2013), nulle part.
11. **Documentation la plus courte possible** : ce qu'il faut faire, rien de plus.

## Sous-agents et git

- La session principale est l'architecte : elle découpe, rédige les ordres de mission, relit, intègre et committe.
  Les sous-agents ne committent pas. `model` toujours explicite : Sonnet d'abord, Opus pour le code délicat.
- Un ordre de mission donne : périmètre exact (fichiers touchés et exclus), règles applicables, résultat vérifiable,
  commande de test ciblée. Un lot = moins de 100 appels d'outils ; compte rendu en 10 lignes au plus.
- Un chantier = une branche ; fusion dans `main` une fois `npm test` vert. Rien hors du dépôt.
