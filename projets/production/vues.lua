-- Tableau de bord de la production : bandeau, commandes, tuiles de totaux, liste classée, détail, courbe.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local flux = require("production.flux")
local base = require("production.vues.base")
local commandes = require("production.vues.commandes")
local detail = require("production.vues.detail")
local courbe = require("production.vues.courbe")
local liste = require("production.vues.liste")

local R = theme.ROLES

local vues = {}

--- Plus petite cible du gabarit riche (panneaux) ; en dessous, gabarit compact.
vues.RICHE = { largeur = 72, hauteur = 26 }

--- Hauteur à partir de laquelle le gabarit riche montre les tuiles de totaux.
vues.HAUTEUR_TUILES = 36

local ALERTES_MIN = 2
local LIGNES_FIXES = 3
local HAUTEUR_TUILE = 4
local HAUTEUR_COURBE_MINI = 7
local HAUTEUR_COURBE_COMPACT = 4

local TITRES = { tout = "Tout le réseau", suivis = "Objets suivis", alertes = "Alertes de rupture" }


--- Gabarit d'une cible de `largeur` x `hauteur` cases : "riche" ou "compact".
function vues.gabarit(largeur, hauteur)
  if largeur >= vues.RICHE.largeur and hauteur >= vues.RICHE.hauteur then return "riche" end
  return "compact"
end

--- Onglets de vue { nom, libelle } permis par `options` { tout, suivis, consommation } : Tout si tout le réseau est
--- lu, Suivis s'il y a une liste suivie (ou si seul le suivi est lu), Alertes si la consommation est mesurée.
function vues.onglets(options)
  local onglets = {}
  if options.tout then onglets[#onglets + 1] = { nom = "tout", libelle = "Tout" } end
  if options.suivis or not options.tout then onglets[#onglets + 1] = { nom = "suivis", libelle = "Suivis" } end
  if options.consommation then onglets[#onglets + 1] = { nom = "alertes", libelle = "Alertes" } end
  return onglets
end

-- Sens de la liste : celui de l'état, "prod" quand la consommation est masquée.
local function sens(etat)
  return etat.options.consommation and etat.sens or "prod"
end

-- Groupes de commandes : onglets (s'il y en a plusieurs), unité, fenêtre, sens (avec la consommation).
local function groupes(etat)
  local liste_groupes = {}
  local onglets = vues.onglets(etat.options)
  if #onglets > 1 then liste_groupes[1] = { cle = "onglet", options = onglets, actif = etat.onglet } end
  local unites, fenetres = {}, {}
  for i, unite in ipairs(flux.UNITES) do unites[i] = { nom = unite, libelle = flux.LIBELLES[unite] } end
  for i, fenetre in ipairs(flux.FENETRES) do fenetres[i] = { nom = fenetre, libelle = base.LIBELLES_FENETRES[fenetre] } end
  liste_groupes[#liste_groupes + 1] = { cle = "unite", options = unites, actif = etat.unite }
  liste_groupes[#liste_groupes + 1] = { cle = "fenetre", options = fenetres, actif = etat.fenetre }
  if etat.options.consommation then
    liste_groupes[#liste_groupes + 1] = { cle = "sens", actif = etat.sens, options = {
      { nom = "prod", libelle = "Prod" }, { nom = "bilan", libelle = "Bilan" }, { nom = "conso", libelle = "Conso" } } }
  end
  return liste_groupes
end

-- Message d'état court qui remplace la liste (pas encore de débit, rien à montrer), ou nil.
local function message(etat)
  local attente = math.max(0, math.ceil(etat.prochaine_mesure or 0))
  if etat.phase == "attente" then return "Première mesure dans " .. attente .. " s." end
  if etat.phase == "base" then return "Base prise : premiers débits dans " .. attente .. " s." end
  if #base.lignes(etat) > 0 then return nil end
  if etat.onglet == "alertes" then return "Aucune alerte." end
  if etat.onglet == "tout" then return "Aucun objet dans le réseau AE." end
  return "Aucun objet suivi."
end

-- Erreurs sous les commandes, les dernières repliées en « + N autres erreurs ».
local function lister_erreurs(etat, hauteur)
  local lignes = {}
  local budget = math.max(ALERTES_MIN, math.floor((hauteur - LIGNES_FIXES) / 4))
  local erreurs = etat.erreurs or {}
  local montrees = #erreurs <= budget and #erreurs or budget - 1
  for i = 1, montrees do lignes[#lignes + 1] = "! " .. erreurs[i] end
  if #erreurs > montrees then lignes[#lignes + 1] = string.format("+ %d autres erreurs", #erreurs - montrees) end
  return lignes
end

local function rectangle(x, y, largeur, hauteur)
  return { x = x, y = y, largeur = largeur, hauteur = hauteur }
end

local function disposer_liste(plan, etat, zone, avec_entete)
  if plan.message then
    plan.zone_message = zone
    return
  end
  local onglet = etat.onglet or "suivis"
  plan.liste = liste.disposer(zone, base.lignes(etat), onglet, (etat.pagination or {})[onglet], avec_entete)
end

local function disposer_riche(plan, etat, haut)
  if etat.classement and plan.hauteur >= vues.HAUTEUR_TUILES then
    local poids = etat.options.consommation and { 1, 1, 1 } or { 1, 1 }
    plan.tuiles = { y = haut, colonnes = panneaux.repartir(2, plan.largeur - 2, poids, 1) }
    haut = haut + HAUTEUR_TUILE + 1
  end
  local disponible = plan.hauteur - 1 - haut
  local colonnes = panneaux.repartir(2, plan.largeur - 2, { 55, 45 }, 1)
  local gauche, droite = colonnes[1], colonnes[2]
  plan.cadres = { { rectangle(gauche.debut, haut, gauche.taille, disponible), TITRES[etat.onglet or "suivis"] } }
  disposer_liste(plan, etat, panneaux.interieur(gauche.debut, haut, gauche.taille, disponible), true)
  local haut_detail = math.min(disponible, detail.HAUTEUR_AEREE + 3)
  local haut_courbe = disponible - haut_detail - 1
  if haut_courbe < HAUTEUR_COURBE_MINI then haut_detail, haut_courbe = disponible, 0 end
  plan.cadres[2] = { rectangle(droite.debut, haut, droite.taille, haut_detail), "Détail" }
  plan.detail = detail.disposer(panneaux.interieur(droite.debut, haut, droite.taille, haut_detail), plan.choisi)
  if haut_courbe > 0 then
    local y = haut + haut_detail + 1
    plan.cadres[3] = { rectangle(droite.debut, y, droite.taille, haut_courbe), "Débit" }
    plan.courbe = panneaux.interieur(droite.debut, y, droite.taille, haut_courbe)
  end
end

local function disposer_compact(plan, etat, haut)
  local reste = plan.hauteur - haut
  if reste < 1 then return end
  if plan.message then
    plan.zone_message = rectangle(1, haut, plan.largeur, reste)
    return
  end
  local haut_liste = math.min(math.max(3, math.floor(reste * 0.4)), math.max(1, #base.lignes(etat)))
  local haut_detail = math.max(0, math.min(etat.options.consommation and 6 or 5, reste - haut_liste))
  local haut_courbe = reste - haut_liste - haut_detail
  if haut_courbe < HAUTEUR_COURBE_COMPACT then haut_liste, haut_courbe = haut_liste + haut_courbe, 0 end
  disposer_liste(plan, etat, rectangle(1, haut, plan.largeur, math.min(reste, haut_liste)), false)
  if haut_detail > 0 then
    plan.detail = detail.disposer(rectangle(1, haut + haut_liste, plan.largeur, haut_detail), plan.choisi)
  end
  if haut_courbe > 0 then
    plan.courbe = rectangle(1, haut + haut_liste + haut_detail, plan.largeur, haut_courbe)
  end
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local plan = { largeur = largeur, hauteur = hauteur, riche = vues.gabarit(largeur, hauteur) == "riche",
    choisi = base.selection(etat), erreurs = lister_erreurs(etat, hauteur), message = message(etat) }
  local marge = plan.riche and 2 or 1
  plan.commandes = commandes.disposer(groupes(etat), marge, 2, largeur - 2 * marge + 2, plan.riche and 2 or 1)
  plan.y_erreurs = 2 + plan.commandes.rangees
  local haut = plan.y_erreurs + #plan.erreurs + (plan.riche and 1 or 0)
  if plan.riche then disposer_riche(plan, etat, haut) else disposer_compact(plan, etat, haut) end
  return plan
end

local function dessiner_tuiles(cible, plan, etat)
  local totaux, unite = etat.classement.totaux, etat.unite
  local tuiles = { { "Production totale", base.texte_absolu(totaux.production, unite), R.bon } }
  if etat.options.consommation then
    tuiles[2] = { "Consommation totale", base.texte_absolu(totaux.consommation, unite), R.mauvais }
  end
  tuiles[#tuiles + 1] = { "Types actifs", texte.milliers(totaux.actifs) .. " / " .. texte.milliers(totaux.connus),
    R.accent, "connus", totaux.connus > 0 and totaux.actifs / totaux.connus or 0 }
  for i, tuile in ipairs(tuiles) do
    local colonne = plan.tuiles.colonnes[i]
    panneaux.tuile(cible, colonne.debut, plan.tuiles.y, colonne.taille, HAUTEUR_TUILE, tuile[1], tuile[2], tuile[4],
      tuile[5], tuile[3])
  end
end

local function dessiner_pied(cible, plan, etat)
  local texte_pied = "Prochaine mesure dans " .. math.max(0, math.ceil(etat.prochaine_mesure or 0)) .. " s"
  local fond = plan.riche and R.surface or R.fond
  local x = plan.riche and 2 or 1
  if plan.riche then panneaux.rectangle(cible, 1, plan.hauteur, plan.largeur, 1, R.surface) end
  dessin.ecrire(cible, x, plan.hauteur, dessin.tronquer(texte_pied, plan.largeur - x + 1), R.discret, fond)
end

--- Dessine tout le tableau de bord sur la cible, aux rôles du thème (la palette se pose ailleurs). Ramène dans
--- `etat.pagination[onglet]` la page montrée de la liste quand elle est paginée.
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  dessin.effacer(cible, R.fond)
  local segments = {}
  local alertes = etat.classement and #etat.classement.alertes or 0
  if alertes > 0 then segments[1] = { texte.quantite(alertes, "alerte"), R.alerte } end
  segments[#segments + 1] = { etat.heure or "", R.accent }
  panneaux.bandeau(cible, "Production", etat.options.tout and "réseau AE" or "objets suivis", segments)
  commandes.dessiner(cible, plan.commandes)
  for i, ligne in ipairs(plan.erreurs) do
    dessin.ecrire(cible, 1, plan.y_erreurs + i - 1, dessin.aligner(ligne, plan.largeur, "gauche"), R.alerte, R.fond)
  end
  if plan.tuiles then dessiner_tuiles(cible, plan, etat) end
  for _, cadre in ipairs(plan.cadres or {}) do
    local c = cadre[1]
    panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, cadre[2])
  end
  local fond = plan.riche and R.surface or R.fond
  if plan.zone_message then liste.message(cible, plan.zone_message, plan.message, fond) end
  if plan.liste then
    liste.dessiner(cible, plan.liste, etat, etat.onglet == "alertes" and "alertes" or sens(etat), plan.choisi, fond)
  end
  if plan.detail then detail.dessiner(cible, plan.detail, etat, fond) end
  if plan.courbe then courbe.dessiner(cible, plan.courbe, etat, plan.choisi, fond) end
  dessiner_pied(cible, plan, etat)
  if type(etat.pagination) == "table" and plan.liste and plan.liste.commande then
    etat.pagination[etat.onglet or "suivis"] = plan.liste.decoupe.page
  end
end

--- Action du toucher en (x, y), ou nil : `{ type = "onglet" | "unite" | "fenetre" | "sens", [type] = valeur }`,
--- `{ type = "selection", cle }`, `{ type = "reset", cle }` ou `{ type = "pagination", liste, page }`.
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  local choix = commandes.action(plan.commandes, x, y)
  if choix then return choix end
  for _, partie in ipairs({ plan.detail, plan.liste }) do
    for _, zone in ipairs(partie and partie.zones or {}) do
      if base.dedans(zone, x, y) then return zone.action end
    end
  end
  return nil
end

return vues
