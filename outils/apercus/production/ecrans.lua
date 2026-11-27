-- Écrans de l'aperçu de la production : chaque gabarit, puis les états particuliers, sur le vrai `vues.dessiner`.

local theme = require("commun.theme")
local vues = require("production.vues")
local exemple = require("outils.apercus.production.exemple")

local ERREURS = { "ME Bridge hors réseau (NOT_CONNECTED)", "Config : objet minecraft:iron_ingot écarté : déjà suivi" }

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
  { "riche_72x26", "Riche, plus petit (72x26)", 72, 26, { unite = "h", selection = "minecraft:copper_ingot" } },
  { "riche_164x81", "Très grand moniteur (164x81)", 164, 81, { unite = "s" } },
  { "compact_51x19", "Compact, terminal (51x19)", 51, 19, {} },
  { "compact_26x12", "Compact, petit (26x12)", 26, 12, {} },
  { "erreurs", "Erreurs en bandeau", 100, 38, { erreurs = ERREURS } },
  { "pagination", "Objets paginés", 100, 38, { objets_en_plus = 30 } },
  { "pagination_compact", "Objets paginés, compact", 51, 19, { objets_en_plus = 6, pagination = { objets = 2 } } },
  { "aucun_objet", "Aucun objet suivi", 100, 38, { vide = true } },
}

local ecrans = {}
for _, cas in ipairs(CAS) do ecrans[#ecrans + 1] = ecran(cas[1], cas[2], cas[3], cas[4], cas[5]) end
return ecrans
