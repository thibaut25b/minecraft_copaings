-- Écrans de l'aperçu de la boutique : tableau de bord à chaque gabarit sur un jeu de données réaliste, par le vrai
-- `vues.dessiner`.

local theme = require("commun.theme")
local vues = require("boutique.vues")

-- 8 articles : le fer en rupture, le cuivre en route.
local ARTICLES = {
  { objet = "create:andesite_alloy", nom = "Alliage d'andésite", texte = "8c", comptoir = 52, reserve = 64,
    usine = 1280, en_route = 0 },
  { objet = "create:brass_ingot", nom = "Lingot de laiton", texte = "3i", comptoir = 30, reserve = 32, usine = 214,
    en_route = 0 },
  { objet = "create:copper_sheet", nom = "Plaque de cuivre", texte = "1i5c", comptoir = 6, reserve = 64, usine = 96,
    en_route = 58 },
  { objet = "create:cogwheel", nom = "Engrenage", texte = "6c", comptoir = 64, reserve = 64, usine = 512,
    en_route = 0 },
  { objet = "create:electron_tube", nom = "Tube électronique", texte = "2i", comptoir = 12, reserve = 16, usine = 40,
    en_route = 0 },
  { objet = "minecraft:iron_ingot", nom = "Lingot de fer", texte = "1i2c", comptoir = 0, reserve = 128, usine = 0,
    en_route = 0 },
  { objet = "create:precision_mechanism", nom = "Mécanisme de précision", texte = "1g", comptoir = 3, reserve = 8,
    usine = 5, en_route = 0 },
  { objet = "create:shaft", nom = "Axe", texte = "2c", comptoir = 61, reserve = 64, usine = 2048, en_route = 0 },
}

local function vente(heure, joueur, objet, quantite, montant, texte)
  return { heure = heure, joueur = joueur, objet = objet, quantite = quantite, montant = montant, texte = texte }
end

local function etat(erreurs)
  return {
    heure = "14:32", comptoirs = 2, articles = ARTICLES, erreurs = erreurs or {}, pagination = {},
    ventes = {
      recette = 1874,
      articles = {
        ["create:andesite_alloy"] = { ventes = 14, vendus = 224, recette = 448 },
        ["create:brass_ingot"] = { ventes = 5, vendus = 40, recette = 150 },
        ["create:copper_sheet"] = { ventes = 9, vendus = 116, recette = 174 },
        ["create:cogwheel"] = { ventes = 3, vendus = 48, recette = 72 },
        ["create:electron_tube"] = { ventes = 4, vendus = 8, recette = 160 },
        ["minecraft:iron_ingot"] = { ventes = 21, vendus = 336, recette = 504 },
        ["create:precision_mechanism"] = { ventes = 3, vendus = 3, recette = 300 },
        ["create:shaft"] = { ventes = 2, vendus = 32, recette = 66 },
      },
      dernieres = {
        vente("14:31", "Alice", "minecraft:iron_ingot", 16, 24, "2i4c"),
        vente("14:28", "Bob_le_Mineur", "create:precision_mechanism", 1, 100, "1g"),
        vente("14:20", "Alice", "create:copper_sheet", 16, 24, "2i4c"),
        vente("14:12", "Zoé", "create:andesite_alloy", 16, 32, "3i2c"),
        vente("13:58", "Marcel", "create:electron_tube", 2, 40, "4i"),
        vente("13:41", "Bob_le_Mineur", "create:cogwheel", 16, 24, "2i4c"),
      },
    },
  }
end

local ERREURS = {
  "donne la permission editTrades à computercraft#7 sur lc_trader_item_1",
  "Commande de minecraft:iron_ingot : réponse illisible du Stock Ticker",
}

local function ecran(nom, titre, largeur, hauteur, erreurs)
  return {
    nom = nom, titre = titre, largeur = largeur, hauteur = hauteur, images = 1,
    dessiner = function(cible)
      theme.appliquer(cible, "nuit")
      vues.dessiner(cible, etat(erreurs))
    end,
  }
end

return {
  ecran("riche_100x38", "Tableau de bord, riche (100x38)", 100, 38),
  ecran("riche_72x24", "Tableau de bord, plus petit riche (72x24)", 72, 24),
  ecran("terminal_51x19", "Terminal de l'ordinateur (51x19)", 51, 19),
  ecran("erreurs_100x38", "Erreurs en bandeau (100x38)", 100, 38, ERREURS),
  ecran("erreurs_51x19", "Erreurs en bandeau, compact (51x19)", 51, 19, ERREURS),
}
