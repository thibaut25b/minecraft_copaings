-- Écrans de l'aperçu de la production : chaque vue à chaque taille, puis les états particuliers, sur le vrai `vues.dessiner`.

local theme = require("commun.theme")
local vues = require("production.vues")
local exemple = require("outils.apercus.production.exemple")

local ERREURS = { "ME Bridge hors réseau (NOT_CONNECTED)", "Config : objet minecraft:iron_ingot écarté : déjà suivi" }

local TAILLES = { { 164, 81 }, { 100, 38 }, { 72, 26 }, { 51, 19 }, { 26, 12 } }

local VUES = {
  { "tout", "Tout", { selection = exemple.PIC } },
  { "suivis", "Suivis", { onglet = "suivis", sens = "bilan", selection = "productivebees:configurable_honeycomb|a3f1c9e2" } },
  { "alertes", "Alertes", { onglet = "alertes", unite = "h" } },
  { "production_seule", "Production seule", { consommation = false, unite = "s", fenetre = 3600 } },
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

local ecrans = {}
for _, vue in ipairs(VUES) do
  for _, taille in ipairs(TAILLES) do
    local l, h = taille[1], taille[2]
    ecrans[#ecrans + 1] = ecran(vue[1] .. "_" .. l .. "x" .. h, vue[2] .. " (" .. l .. "x" .. h .. ")", l, h, vue[3])
  end
end

local CAS = {
  { "bilan_100x38", "Bilan, trois colonnes", 100, 38, { sens = "bilan" } },
  { "erreurs", "Erreurs et coupure", 100, 38, { erreurs = { ERREURS[1], ERREURS[2], "Lecture ignorée : réseau AE incomplet" } } },
  { "pagination_compact", "Liste paginée, compact", 51, 19, { objets_en_plus = 12, pagination = { tout = 2 } } },
  { "attente", "Avant la première mesure", 100, 38, { phase = "attente" } },
  { "attente_26x12", "Avant la première mesure, petit", 26, 12, { phase = "attente" } },
  { "aucun_objet", "Aucun objet suivi", 72, 26, { vide = true } },
  { "historique_court", "Débits partiels (5 min d'historique)", 100, 38, { duree = 300 } },
}
for _, cas in ipairs(CAS) do ecrans[#ecrans + 1] = ecran(cas[1], cas[2], cas[3], cas[4], cas[5]) end

return ecrans
