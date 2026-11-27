-- Tableau de bord de la production : bandeau et unités, liste des objets, détail, histogramme, riche ou compact.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local debit = require("production.debit")
local base = require("production.vues.base")
local detail = require("production.vues.detail")
local histogramme = require("production.vues.histogramme")
local liste = require("production.vues.liste")

local R = theme.ROLES

local vues = {}

--- Plus petite cible du gabarit riche (trois panneaux) ; en dessous, gabarit compact.
vues.RICHE = { largeur = 72, hauteur = 26 }

local LARGEUR_BANDEAU_UNITES = 40 -- dessous, les boutons d'unité passent sur leur propre rangée
local ALERTES_MIN = 2
local LIGNES_FIXES = 3
local HAUTEUR_DETAIL_MAXI = 14
local HAUTEUR_PANNEAU_MINI = 8
local HAUTEUR_DETAIL_COMPACT = 7
local HAUTEUR_COMPACT_MINI = 4
local AIDE = "toucher un objet : son détail"

--- Gabarit d'une cible de `largeur` x `hauteur` cases : "riche" ou "compact".
function vues.gabarit(largeur, hauteur)
  if largeur >= vues.RICHE.largeur and hauteur >= vues.RICHE.hauteur then return "riche" end
  return "compact"
end

-- Erreurs sous le bandeau, les dernières repliées en « + N autres erreurs ».
local function lister_alertes(etat, hauteur)
  local alertes = {}
  local budget = math.max(ALERTES_MIN, math.floor((hauteur - LIGNES_FIXES) / 4))
  local erreurs = etat.erreurs or {}
  local montrees = #erreurs <= budget and #erreurs or budget - 1
  for i = 1, montrees do alertes[#alertes + 1] = "! " .. erreurs[i] end
  if #erreurs > montrees then alertes[#alertes + 1] = string.format("+ %d autres erreurs", #erreurs - montrees) end
  return alertes
end

local function rectangle(x, y, largeur, hauteur)
  return { x = x, y = y, largeur = largeur, hauteur = hauteur }
end

-- Onglets des unités : un par unité de `debit.UNITES`, libellé « /min ».
local function onglets_unites()
  local onglets = {}
  for i, unite in ipairs(debit.UNITES) do onglets[i] = { nom = unite, libelle = debit.LIBELLES[unite] } end
  return onglets
end

-- Largeur de la rangée des boutons d'unité.
local function largeur_unites()
  local zones = dessin.zones_onglets(1, 1, 100, onglets_unites())
  return zones[#zones].x2
end

local function disposer_riche(plan, etat, haut)
  local disponible = plan.hauteur - 2 - haut + 1
  local colonnes = panneaux.repartir(2, plan.largeur - 2, { 40, 60 }, 1)
  local gauche, droite = colonnes[1], colonnes[2]
  local haut_detail = math.max(HAUTEUR_PANNEAU_MINI, math.min(HAUTEUR_DETAIL_MAXI, math.floor(disponible / 2)))
  local haut_histo = disponible - haut_detail - 1
  if haut_histo < HAUTEUR_PANNEAU_MINI then haut_detail, haut_histo = disponible, 0 end
  plan.cadres = {
    { rectangle(gauche.debut, haut, gauche.taille, disponible), "Objets suivis", "débit moyen 1 min" },
    { rectangle(droite.debut, haut, droite.taille, haut_detail), "Détail", nil },
  }
  plan.liste = liste.disposer(panneaux.interieur(gauche.debut, haut, gauche.taille, disponible), etat)
  plan.detail = detail.disposer(panneaux.interieur(droite.debut, haut, droite.taille, haut_detail), plan.choisi)
  if haut_histo > 0 then
    local y = haut + haut_detail + 1
    plan.cadres[3] = { rectangle(droite.debut, y, droite.taille, haut_histo), "Débit par tranche",
      "sur " .. base.duree(etat.duree_graphe) }
    plan.histogramme = panneaux.interieur(droite.debut, y, droite.taille, haut_histo)
  end
end

-- Hauteurs de la liste, du détail et de l'histogramme (0 : omis) pour `reste` rangées et `total` objets.
local function repartir_compact(reste, total)
  if total == 0 then return math.min(#liste.MESSAGE_VIDE, reste), 0, 0 end
  local haut_liste = math.min(total, math.max(2, math.floor(reste * 0.35)))
  local haut_detail = math.min(HAUTEUR_DETAIL_COMPACT, reste - haut_liste)
  if haut_detail < HAUTEUR_COMPACT_MINI then
    haut_liste = math.min(total, math.max(1, reste - HAUTEUR_COMPACT_MINI))
    haut_detail = math.max(0, math.min(HAUTEUR_DETAIL_COMPACT, reste - haut_liste))
  end
  local haut_histo = reste - haut_liste - haut_detail
  return haut_liste, haut_detail, haut_histo >= HAUTEUR_COMPACT_MINI and haut_histo or 0
end

local function disposer_compact(plan, etat, haut)
  local reste = plan.hauteur - 1 - haut + 1
  if reste < 1 then return end
  local haut_liste, haut_detail, haut_histo = repartir_compact(reste, #etat.objets)
  plan.liste = liste.disposer(rectangle(1, haut, plan.largeur, haut_liste), etat)
  if haut_detail > 0 then
    plan.detail = detail.disposer(rectangle(1, haut + haut_liste, plan.largeur, haut_detail), plan.choisi)
  end
  if haut_histo > 0 then
    plan.histogramme = rectangle(1, haut + haut_liste + haut_detail, plan.largeur, haut_histo)
  end
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local plan = { largeur = largeur, hauteur = hauteur, riche = vues.gabarit(largeur, hauteur) == "riche",
    choisi = base.selection(etat), alertes = lister_alertes(etat, hauteur) }
  local total = largeur_unites()
  local dans_bandeau = largeur >= LARGEUR_BANDEAU_UNITES
  plan.reserve = dans_bandeau and total or nil
  plan.rangee_unites = dans_bandeau and 1 or 2
  plan.unites = dessin.zones_onglets(dans_bandeau and largeur - total or 1, plan.rangee_unites, total,
    onglets_unites())
  local haut = plan.rangee_unites + 1 + #plan.alertes + (plan.riche and 1 or 0)
  if plan.riche then disposer_riche(plan, etat, haut) else disposer_compact(plan, etat, haut) end
  return plan
end

local function dessiner_pied(cible, plan, etat)
  local texte = "Prochaine mesure dans " .. math.max(0, math.ceil(etat.prochaine_mesure or 0)) .. " s"
  local fond = plan.riche and R.surface or R.fond
  local x = plan.riche and 2 or 1
  if plan.riche then panneaux.rectangle(cible, 1, plan.hauteur, plan.largeur, 1, R.surface) end
  local ecrit = dessin.ecrire(cible, x, plan.hauteur, dessin.tronquer(texte, plan.largeur - x + 1), R.discret, fond)
  local longueur = panneaux.longueur(AIDE)
  if x + ecrit + 2 + longueur <= plan.largeur then
    dessin.ecrire(cible, plan.largeur - longueur + (plan.riche and 0 or 1), plan.hauteur, AIDE, R.discret, fond)
  end
end

--- Dessine tout le tableau de bord sur la cible, aux rôles du thème (la palette se pose ailleurs). Ramène dans
--- `etat.pagination` la page montrée de la liste quand elle est paginée.
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  dessin.effacer(cible, R.fond)
  local segments = { { etat.heure or "", R.accent } }
  if plan.reserve then segments[2] = { string.rep(" ", plan.reserve), R.discret } end
  panneaux.bandeau(cible, "Production", nil, segments)
  if plan.unites[1] then
    dessin.onglets(cible, plan.unites[1].x1, plan.rangee_unites, plan.largeur - plan.unites[1].x1 + 1,
      onglets_unites(), etat.unite)
  end
  for i, alerte in ipairs(plan.alertes) do
    dessin.ecrire(cible, 1, plan.rangee_unites + i, dessin.aligner(alerte, plan.largeur, "gauche"), R.alerte, R.fond)
  end
  for _, cadre in ipairs(plan.cadres or {}) do
    local c = cadre[1]
    panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, cadre[2], cadre[3])
  end
  local fond = plan.riche and R.surface or R.fond
  if plan.liste then liste.dessiner(cible, plan.liste, etat, plan.choisi, fond) end
  if plan.detail then detail.dessiner(cible, plan.detail, etat, fond) end
  if plan.histogramme then histogramme.dessiner(cible, plan.histogramme, etat, plan.choisi, fond) end
  dessiner_pied(cible, plan, etat)
  if type(etat.pagination) == "table" and plan.liste and plan.liste.commande then
    etat.pagination.objets = plan.liste.decoupe.page
  end
end

--- Action du toucher en (x, y), ou nil : `{ type = "unite", unite }`, `{ type = "selection", objet }`,
--- `{ type = "reset", objet }` ou `{ type = "pagination", liste, page }`.
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  local nom = dessin.onglet_sous_point(plan.unites, x, y)
  if nom then return { type = "unite", unite = nom } end
  for _, partie in ipairs({ plan.detail, plan.liste }) do
    for _, zone in ipairs(partie and partie.zones or {}) do
      if base.dedans(zone, x, y) then return zone.action end
    end
  end
  return nil
end

return vues
