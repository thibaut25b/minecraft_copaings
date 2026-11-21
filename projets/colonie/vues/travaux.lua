-- Page Travaux : synthèse des ordres de construction, puis leur tableau paginé, ceux sans constructeur en premier.

local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("colonie.vues.base")

local R = theme.ROLES

local travaux = {}

local LISTE = "travaux"
local AUCUN = "Aucun chantier en cours"

local COLONNES = {
  { titre = "Bâtiment", min = 12 },
  { titre = "Type", largeur = 12, facultatif = true },
  { titre = "Niv", largeur = 3, alignement = "droite" },
  { titre = "Constructeur", min = 10, facultatif = true },
  { titre = "État", largeur = 10 },
}

--- Géométrie de la page dans `zone`.
function travaux.disposer(zone, etat, riche)
  local colonie = etat.colonie
  if not colonie or #colonie.travaux == 0 then return { zone = zone, zones = {} } end
  return base.disposer_synthese(zone, riche, 3, LISTE, #colonie.travaux, etat)
end

local function mesures(colonie, etat)
  local total, pris, occupes, vus = #colonie.travaux, 0, 0, {}
  for _, travail in ipairs(colonie.travaux) do
    if travail.pris then pris = pris + 1 end
    if travail.pris and travail.constructeur ~= "" and not vus[travail.constructeur] then
      vus[travail.constructeur] = true
      occupes = occupes + 1
    end
  end
  local huttes = math.max(type(etat.constructeurs) == "table" and #etat.constructeurs or 0, occupes)
  local attente = total - pris
  return {
    { "En cours", pris .. "/" .. total, "pris en charge", pris / total, R.accent },
    { "En attente", tostring(attente), "sans constructeur", attente / total, attente > 0 and R.moyen or R.bon },
    { "Bâtisseurs", occupes .. "/" .. huttes, "constructeurs occupés", huttes > 0 and occupes / huttes or 0, R.info },
  }
end

--- Dessine la page disposée.
function travaux.dessiner(cible, plan, etat, riche)
  local colonie = etat.colonie
  if not colonie then return base.message(cible, plan.zone, base.ILLISIBLE, R.alerte, R.fond) end
  if not plan.liste then return base.message(cible, plan.zone, AUCUN, R.discret, R.fond) end
  base.dessiner_synthese(cible, plan, mesures(colonie, etat), riche)
  if riche then
    local p = plan.panneau
    panneaux.panneau(cible, p.x, p.y, p.largeur, p.hauteur, "Ordres de construction", "en attente en premier")
  end
  local triees = base.trier_par_rang(colonie.travaux, function(travail) return travail.pris and 1 or 0 end)
  local rangees = {}
  for i, travail in ipairs(triees) do
    rangees[i] = {
      travail.batiment,
      travail.type,
      tostring(travail.niveau),
      travail.constructeur,
      travail.pris and { texte = "en cours", couleur = R.bon } or { texte = "en attente", couleur = R.moyen },
    }
  end
  base.dessiner_liste(cible, plan.liste, COLONNES, rangees, riche and R.surface or R.fond, riche and R.fond or R.surface)
end

return travaux
