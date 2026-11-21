-- Page Habitants : emploi, logement et santé en synthèse, puis le tableau paginé, ceux à qui il manque quelque chose
-- en premier.

local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("colonie.vues.base")

local R = theme.ROLES

local habitants = {}

local LISTE = "habitants"
local AUCUN = "Aucun habitant"

local COLONNES = {
  { titre = "Nom", min = 12 },
  { titre = "Manque", largeur = 13 },
  { titre = "Santé", largeur = 5, alignement = "droite" },
  { titre = "Métier", min = 10, facultatif = true },
  { titre = "État", min = 10, facultatif = true },
}

local function manques(habitant)
  if not habitant.loge and not habitant.employe then return "logis, emploi" end
  if not habitant.loge then return "logis" end
  if not habitant.employe then return "emploi" end
  return ""
end

-- Une santé maximale à 0 signifie que la santé du colon est inconnue (entité non chargée).
local function blesse(habitant)
  return habitant.sante_max > 0 and habitant.sante < habitant.sante_max
end

local function texte_sante(habitant)
  if habitant.sante_max <= 0 then return "-" end
  return math.floor(habitant.sante + 0.5) .. "/" .. math.floor(habitant.sante_max + 0.5)
end

local function couleur_sante(habitant)
  if not blesse(habitant) then return R.texte end
  return habitant.sante * 2 < habitant.sante_max and R.mauvais or R.moyen
end

--- Géométrie de la page dans `zone`.
function habitants.disposer(zone, etat, riche)
  local colonie = etat.colonie
  if not colonie or #colonie.habitants == 0 then return { zone = zone, zones = {} } end
  return base.disposer_synthese(zone, riche, 3, LISTE, #colonie.habitants, etat)
end

local function mesures(liste)
  local total, employes, loges, blesses = #liste, 0, 0, 0
  for _, habitant in ipairs(liste) do
    if habitant.employe then employes = employes + 1 end
    if habitant.loge then loges = loges + 1 end
    if blesse(habitant) then blesses = blesses + 1 end
  end
  local valides = total - blesses
  return {
    { "Employés", employes .. "/" .. total, (total - employes) .. " sans emploi", employes / total,
      base.couleur_part(employes / total) },
    { "Logés", loges .. "/" .. total, (total - loges) .. " sans maison", loges / total, base.couleur_part(loges / total) },
    { "En forme", valides .. "/" .. total, blesses .. " blessés", valides / total, base.couleur_part(valides / total) },
  }
end

--- Dessine la page disposée.
function habitants.dessiner(cible, plan, etat, riche)
  local colonie = etat.colonie
  if not colonie then return base.message(cible, plan.zone, base.ILLISIBLE, R.alerte, R.fond) end
  if not plan.liste then return base.message(cible, plan.zone, AUCUN, R.discret, R.fond) end
  base.dessiner_synthese(cible, plan, mesures(colonie.habitants), riche)
  if riche then
    local p = plan.panneau
    panneaux.panneau(cible, p.x, p.y, p.largeur, p.hauteur, "Colons", "manques en premier")
  end
  local triees = base.trier_par_rang(colonie.habitants, function(habitant) return manques(habitant) == "" and 1 or 0 end)
  local rangees = {}
  for i, habitant in ipairs(triees) do
    rangees[i] = {
      habitant.nom,
      { texte = manques(habitant), couleur = R.alerte },
      { texte = texte_sante(habitant), couleur = couleur_sante(habitant) },
      habitant.metier,
      { texte = habitant.etat, couleur = R.discret },
    }
  end
  base.dessiner_liste(cible, plan.liste, COLONNES, rangees, riche and R.surface or R.fond, riche and R.fond or R.surface)
end

return habitants
