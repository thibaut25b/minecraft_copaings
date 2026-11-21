-- Tableau de bord de la colonie : bandeau, onglets, alertes, page `etat.page` et pied, au gabarit riche ou compact.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")

local R = theme.ROLES

local vues = {}

--- Plus petite cible du gabarit riche (panneaux et graphiques) ; en dessous, gabarit compact.
vues.RICHE = { largeur = 72, hauteur = 28 }

local LIGNE_ONGLETS = 2
local LIGNES_FIXES = 3 -- bandeau, onglets, pied
local ALERTES_MIN = 2

-- Les pages, dans l'ordre des onglets : un seul endroit pour les noms, les libellés et les modules.
local PAGES = {
  { nom = "resume", libelle = "Résumé", module = require("colonie.vues.resume") },
  { nom = "requetes", libelle = "Requêtes", module = require("colonie.vues.requetes") },
  { nom = "travaux", libelle = "Travaux", module = require("colonie.vues.travaux") },
  { nom = "chantiers", libelle = "Chantiers", module = require("colonie.vues.chantiers") },
  { nom = "habitants", libelle = "Habitants", module = require("colonie.vues.habitants") },
}

local function page_nommee(nom)
  for _, page in ipairs(PAGES) do
    if page.nom == nom then return page end
  end
  return PAGES[1]
end

--- Gabarit d'une cible de `largeur` x `hauteur` cases : "riche" ou "compact".
function vues.gabarit(largeur, hauteur)
  if largeur >= vues.RICHE.largeur and hauteur >= vues.RICHE.hauteur then return "riche" end
  return "compact"
end

-- Bandeaux sous les onglets : raid d'abord, puis les erreurs (les dernières repliées en « + N autres »).
local function lister_alertes(etat, hauteur)
  local alertes = {}
  if etat.colonie and etat.colonie.raid then
    alertes[1] = { texte = "RAID : colonie attaquée", alignement = "centre", couleur = R.texte, fond = R.mauvais }
  end
  local budget = math.max(ALERTES_MIN, math.floor((hauteur - LIGNES_FIXES) / 4))
  local erreurs = etat.erreurs
  local montrees = #erreurs <= budget and #erreurs or budget - 1
  for i = 1, montrees do
    alertes[#alertes + 1] = { texte = "! " .. erreurs[i], alignement = "gauche", couleur = R.alerte, fond = R.fond }
  end
  if #erreurs > montrees then
    alertes[#alertes + 1] = { texte = string.format("+ %d autres erreurs", #erreurs - montrees), alignement = "gauche",
      couleur = R.alerte, fond = R.fond }
  end
  return alertes
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local riche = vues.gabarit(largeur, hauteur) == "riche"
  local page = page_nommee(etat.page)
  local alertes = lister_alertes(etat, hauteur)
  local y = LIGNE_ONGLETS + 1 + #alertes + (riche and 1 or 0)
  local fin = hauteur - (riche and 2 or 1)
  local zone = { x = 1, y = y, largeur = largeur, hauteur = math.max(0, fin - y + 1) }
  return {
    largeur = largeur, hauteur = hauteur, riche = riche, page = page, alertes = alertes,
    onglets = dessin.zones_onglets(1, LIGNE_ONGLETS, largeur, PAGES),
    contenu = page.module.disposer(zone, etat, riche),
  }
end

local function dessiner_pied(cible, plan, etat)
  local secondes = math.max(0, math.ceil(etat.prochaine_passe))
  local texte = "Prochaine passe dans " .. secondes .. " s"
  if plan.riche then
    panneaux.rectangle(cible, 1, plan.hauteur, plan.largeur, 1, R.surface)
    dessin.ecrire(cible, 2, plan.hauteur, dessin.tronquer(texte, plan.largeur - 2), R.discret, R.surface)
    return
  end
  dessin.ecrire(cible, 1, plan.hauteur, dessin.tronquer(texte, plan.largeur), R.discret, R.fond)
end

--- Dessine tout le tableau de bord sur la cible, aux rôles du thème (la palette se pose ailleurs). Ramène dans
--- `etat.pagination` la page montrée de la liste paginée (retombée à 1 si la liste a rétréci).
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  dessin.effacer(cible, R.fond)
  local colonie = etat.colonie
  local sous_titre = colonie and colonie.style ~= "" and "style " .. colonie.style or nil
  panneaux.bandeau(cible, colonie and colonie.nom or "Colonie", plan.riche and sous_titre or nil,
    { { etat.heure, R.accent } })
  dessin.onglets(cible, 1, LIGNE_ONGLETS, plan.largeur, PAGES, plan.page.nom)
  for i, alerte in ipairs(plan.alertes) do
    dessin.ecrire(cible, 1, LIGNE_ONGLETS + i, dessin.aligner(alerte.texte, plan.largeur, alerte.alignement),
      alerte.couleur, alerte.fond)
  end
  plan.page.module.dessiner(cible, plan.contenu, etat, plan.riche)
  dessiner_pied(cible, plan, etat)
  local liste = plan.contenu.liste
  if liste and type(etat.pagination) == "table" then etat.pagination[liste.cle] = liste.decoupe.page end
end

--- Action du toucher en (x, y), ou nil : `{ type = "page", page }`, `{ type = "constructeur", cle }` (sous-onglet),
--- `{ type = "livraison", cle }` (bouton du constructeur montré) ou `{ type = "pagination", liste, page }`.
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  local page = dessin.onglet_sous_point(plan.onglets, x, y)
  if page then return { type = "page", page = page } end
  for _, zone in ipairs(plan.contenu.zones) do
    if x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2 then return zone.action end
  end
  return nil
end

return vues
