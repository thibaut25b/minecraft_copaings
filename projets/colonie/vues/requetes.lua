-- Page Requêtes : totaux par statut, puis les lignes de passe en tableau paginé, celles qui demandent d'agir en premier.

local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local statuts = require("colonie.statuts")
local base = require("colonie.vues.base")

local R = theme.ROLES

local requetes = {}

local LISTE = "requetes"
local AUCUNE = "Aucune requête en cours"

local COLONNES = {
  { titre = "Statut", largeur = 11 },
  { titre = "Requête", min = 12 },
  { titre = "Livré", largeur = 7, alignement = "droite" },
  { titre = "Demandeur", min = 10, facultatif = true },
  { titre = "Message", min = 24, facultatif = true },
}

local function entete(lignes)
  local entrees = { { #lignes .. (#lignes > 1 and " requêtes" or " requête") } }
  for _, entree in ipairs(base.legende_statuts(lignes)) do entrees[#entrees + 1] = entree end
  return entrees
end

--- Géométrie de la page dans `zone` : en-tête, liste paginée et zones touchables.
function requetes.disposer(zone, etat, riche)
  local lignes = etat.lignes
  if #lignes == 0 then return { zone = zone, zones = {} } end
  local plan = { zone = zone, entete = entete(lignes) }
  local corps
  if riche then
    local x, largeur = zone.x + 1, zone.largeur - 2
    local rangees = base.rangees_legende(largeur - 4, plan.entete)
    plan.panneau_entete = { x = x, y = zone.y, largeur = largeur, hauteur = rangees + 4 }
    local y = zone.y + plan.panneau_entete.hauteur + 1
    plan.panneau_liste = { x = x, y = y, largeur = largeur, hauteur = zone.y + zone.hauteur - y }
    local p = plan.panneau_liste
    corps = panneaux.interieur(p.x, p.y, p.largeur, p.hauteur)
  else
    local rangees = base.rangees_legende(zone.largeur, plan.entete)
    corps = { x = zone.x, y = zone.y + rangees, largeur = zone.largeur, hauteur = zone.hauteur - rangees }
  end
  plan.liste = base.disposer_liste(corps, LISTE, #lignes, etat)
  plan.zones = plan.liste.zones
  return plan
end

local function rangees(lignes)
  local triees = base.trier_par_rang(lignes, function(ligne) return statuts.de(ligne.statut).action and 0 or 1 end)
  local resultat = {}
  for i, ligne in ipairs(triees) do
    resultat[i] = {
      base.pastille(ligne.statut),
      ligne.requete.libelle,
      ligne.livre .. "/" .. ligne.requete.quantite,
      ligne.requete.demandeur,
      { texte = ligne.message, couleur = R.discret },
    }
  end
  return resultat
end

--- Dessine la page disposée.
function requetes.dessiner(cible, plan, etat, riche)
  local zone = plan.zone
  if not plan.liste then
    if riche and zone.hauteur >= 4 then
      local interieur = panneaux.panneau(cible, zone.x + 1, zone.y, zone.largeur - 2, zone.hauteur, "Requêtes")
      return base.message(cible, interieur, AUCUNE, R.bon, R.surface, true)
    end
    return base.message(cible, zone, AUCUNE, R.discret, R.fond)
  end
  local fond = R.fond
  if riche then
    fond = R.surface
    local p = plan.panneau_entete
    local interieur = panneaux.panneau(cible, p.x, p.y, p.largeur, p.hauteur, "Requêtes par statut",
      "problèmes en premier")
    base.legende(cible, interieur, 1, plan.entete, R.surface)
    local parts = {}
    for _, entree in ipairs(base.legende_statuts(etat.lignes)) do parts[#parts + 1] = { entree[3], entree[2] } end
    local rangees_legende = base.rangees_legende(interieur.largeur, plan.entete)
    panneaux.barre_empilee(cible, { x = interieur.x, y = interieur.y + rangees_legende, largeur = interieur.largeur,
      hauteur = 1 }, parts)
    p = plan.panneau_liste
    panneaux.panneau(cible, p.x, p.y, p.largeur, p.hauteur, "Lignes de la dernière passe")
  else
    base.legende(cible, zone, 1, plan.entete, R.fond)
  end
  base.dessiner_liste(cible, plan.liste, COLONNES, rangees(etat.lignes), fond, riche and R.fond or R.surface)
end

return requetes
