# Usine

Tableau de bord et régulation d'une usine Create 6 : stress et vitesse du réseau cinétique, stock du réseau
logistique, chaque ligne coupée ou relancée selon son stock, délestage quand le réseau approche la surcharge.

## Matériel

- Un ordinateur avancé et un moniteur avancé (72 x 26 cases au moins pour le gabarit riche ; sinon compact, ou
  l'écran de l'ordinateur à la souris).
- Un Stock Ticker de Create relié au réseau logistique.
- Un stressomètre par réseau cinétique, un speedomètre si tu veux la vitesse.
- Un relais redstone de CC: Tweaked (`computercraft:redstone_relay`) par groupe de lignes, chaque sortie vers
  l'embrayage (ou le changement de vitesse) d'une ligne. Pas le « Redstone Relay » de Create Additions.

## Câblage

Tout passe par des modems filaires sur un même réseau. Fais clic droit sur chaque modem : le chat donne le nom réseau
(`Create_Stressometer_0`, `redstone_relay_2`...). Ce sont ces noms qui vont dans la config.

## Installation

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua usine
```

Puis lance `/usine/diag` : il liste les périphériques, lit les jauges, un échantillon du stock et l'état des relais
configurés sans rien changer, et écrit `/usine-diag.txt`.

## Réglages

Dans `/usine.cfg`, décrits dans `projets/usine/reglages.lua`. Pour chaque ligne : `produit`, `mini`, `maxi`, `relais`,
`cote`, `signal_coupe` (true : sortie active = ligne arrêtée, cas d'un embrayage), `reseau`, `priorite` (1 = délestée
en dernier). Une entrée fautive est écartée et signalée à l'écran ; redémarre l'ordinateur après un changement.

## Utilisation

- Une ligne en `auto` s'arrête quand son stock atteint `maxi` et repart à `mini`.
- Stress / capacité à `seuil_delestage` ou plus : une ligne de plus coupée à chaque passe, la moins prioritaire
  d'abord ; à `seuil_reprise` ou moins, elles repartent une à une. Une ligne forcée n'est jamais délestée.
- Toucher une ligne : mode auto, puis marche forcée, puis arrêt forcé. Toucher la jauge : réseau suivant.
- `/usine.etat` garde modes, décisions et délestages au redémarrage ; `/usine.log` : journal des erreurs.

Aperçu hors jeu : `npm run apercu -- usine`, puis ouvre `apercu/usine.html`.
