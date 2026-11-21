# Boutique

Vend la production d'une usine Create avec la monnaie de Lightman's Currency. Les Item Traders (« comptoirs »)
vendent et encaissent eux-mêmes ; l'ordinateur les réapprovisionne depuis le réseau logistique de Create, règle les
prix, compte les ventes et affiche un tableau de bord.

## Matériel

- Un ordinateur avancé, des modems filaires et du câble.
- Un ou plusieurs Item Traders, un coffre « tampon ».
- Facultatif : un Stock Ticker du réseau logistique de l'usine et un Frogport ou un Packager qui déballe les colis
  dans le tampon. Sans eux, la boutique vend ce que tu mets à la main dans le tampon.
- Facultatif : un moniteur avancé (sinon, l'écran de l'ordinateur).

## Montage pas à pas

1. Pose l'Item Trader et crée tes offres de vente à la main dans son interface.
2. Relie l'ordinateur, chaque Item Trader, le tampon, le Stock Ticker et le moniteur au **même** réseau de modems
   filaires ; clic droit sur chaque modem pour l'activer. Note le nom réseau du tampon (par exemple
   `minecraft:chest_0`).
3. Donne au Frogport ou au Packager du tampon l'adresse `Boutique` (réglage `adresse`).
4. Dans chaque Item Trader, active l'autorisation externe et passe `computercraft#<id>` (l'id s'affiche avec `id`
   sur l'ordinateur) en allié avec les permissions `openStorage` et `editTrades`.
5. Installe, mets le nom du tampon dans `/boutique.cfg` (`tampon = "minecraft:chest_0"`), puis lance
   `/boutique/diag` : il lit tout sans rien bouger et écrit `/boutique-diag.txt`. Redémarre l'ordinateur.

## Installation

```
wget run https://raw.githubusercontent.com/thibaut25b/minecraft_copaings/main/install.lua boutique
```

## Réglages et fichiers

- `/boutique.cfg` : réglages, décrits dans `projets/boutique/reglages.lua`. Les articles se lisent dans les offres ;
  `articles` sert seulement à changer la réserve, le prix (en crédits de `piece_de_compte`) ou le libellé d'un objet.
- `/boutique.ventes` : comptes des ventes. `/boutique.log` : journal des ventes, réassorts, commandes et prix.

Aperçu hors jeu : `npm run apercu -- boutique`, puis ouvre `apercu/boutique.html`.
