-- Écrans de l'aperçu de l'usine : chaque gabarit, puis les états particuliers, sur le vrai `vues.dessiner` et les
-- données de `exemple`.

local theme = require("commun.theme")
local vues = require("usine.vues")
local exemple = require("outils.apercus.usine.exemple")

local ERREURS = {
  "Ligne Four à briques : relais redstone_relay_3 introuvable",
  "Config : ligne Presse 2 écartée : mini > maxi",
}

local function ecran(nom, titre, largeur, hauteur, options)
  return {
    nom = nom, titre = titre, largeur = largeur, hauteur = hauteur, images = 1,
    dessiner = function(cible)
      theme.appliquer(cible, "nuit")
      vues.dessiner(cible, exemple.etat(options))
    end,
  }
end

local CAS = {
  { "riche_100x38", "Riche (100x38)", 100, 38, {} },
  { "riche_72x26", "Riche, plus petit (72x26)", 72, 26, {} },
  { "riche_164x81", "Très grand moniteur (164x81)", 164, 81, {} },
  { "compact_51x19", "Compact, terminal (51x19)", 51, 19, {} },
  { "compact_39x19", "Compact (39x19)", 39, 19, {} },
  { "erreurs", "Erreurs en bandeau", 100, 38, { erreurs = ERREURS } },
  { "erreurs_compact", "Erreurs en bandeau, compact", 51, 19, { erreurs = ERREURS } },
  { "panne_ticker", "Stock Ticker en panne : stock inconnu", 100, 38, { panne_ticker = true,
    erreurs = { "Stock Ticker introuvable" } } },
  { "deux_reseaux", "Deux réseaux cinétiques", 100, 38, { deux_reseaux = true } },
  { "pagination", "Lignes paginées", 100, 38, { lignes_en_plus = 8 } },
  { "pagination_compact", "Lignes paginées, compact", 51, 19, { lignes_en_plus = 4, pagination = { lignes = 2 } } },
}

local ecrans = {}
for _, cas in ipairs(CAS) do ecrans[#ecrans + 1] = ecran(cas[1], cas[2], cas[3], cas[4], cas[5]) end
return ecrans
