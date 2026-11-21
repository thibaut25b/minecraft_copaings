-- Écrans de l'aperçu de la colonie : chaque page à chaque gabarit, puis les états particuliers, sur le vrai
-- `vues.dessiner` et les données de `exemple`.

local theme = require("commun.theme")
local vues = require("colonie.vues")
local exemple = require("outils.apercus.colonie.exemple")

local PAGES = { "resume", "requetes", "travaux", "chantiers", "habitants" }
local TAILLES = { { 100, 38, "riche" }, { 51, 19, "compact 51" }, { 39, 19, "compact 39" } }

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
for _, taille in ipairs(TAILLES) do
  for _, page in ipairs(PAGES) do
    local suffixe = taille[1] .. "x" .. taille[2]
    ecrans[#ecrans + 1] = ecran(page .. "_" .. suffixe, page .. ", " .. taille[3] .. " (" .. suffixe .. ")", taille[1],
      taille[2], { page = page })
  end
end

local PARTICULIERS = {
  { "resume_164x81", "Résumé, très grand moniteur", 164, 81, { page = "resume" } },
  { "resume_26x12", "Résumé, plus petit moniteur", 26, 12, { page = "resume" } },
  { "raid", "Raid en cours", 100, 38, { page = "resume", raid = true } },
  { "raid_compact", "Raid en cours, compact", 51, 19, { page = "resume", raid = true } },
  { "erreurs", "Erreurs en bandeau", 100, 38, { page = "requetes", erreurs = exemple.ERREURS } },
  { "erreurs_compact", "Erreurs en bandeau, compact", 39, 19, { page = "resume", erreurs = exemple.ERREURS } },
  { "illisible", "Colonie illisible", 100, 38, { page = "resume", sans_colonie = true,
    erreurs = { "Colonie : Intégrateur de colonie introuvable" } } },
  { "illisible_compact", "Colonie illisible, compact", 51, 19, { page = "habitants", sans_colonie = true } },
  { "aucune_requete", "Aucune requête", 100, 38, { page = "requetes", sans_requete = true } },
  { "aucune_requete_resume", "Aucune requête, résumé", 100, 38, { page = "resume", sans_requete = true } },
  { "sans_chantier", "Constructeur sans chantier", 100, 38, { page = "chantiers", sans_chantier = true,
    constructeur = "88,63,12" } },
  { "page2", "Liste paginée, page 2", 100, 38, { page = "habitants", nombre = 3, pagination = { habitants = 2 } } },
  { "page2_compact", "Liste paginée, page 2, compact", 39, 19, { page = "requetes", pagination = { requetes = 2 } } },
}
for _, cas in ipairs(PARTICULIERS) do ecrans[#ecrans + 1] = ecran(cas[1], cas[2], cas[3], cas[4], cas[5]) end

return ecrans
