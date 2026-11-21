-- Tableau de bord de l'usine : bandeau, alertes, lignes, stress du réseau montré, courbe et stocks, riche ou compact.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local lignes = require("usine.vues.lignes")
local reseau = require("usine.vues.reseau")
local stocks = require("usine.vues.stocks")

local R = theme.ROLES

local vues = {}

--- Plus petite cible du gabarit riche (panneaux, jauge et courbe) ; en dessous, gabarit compact.
vues.RICHE = { largeur = 72, hauteur = 26 }

local ALERTES_MIN = 2
local LIGNES_FIXES = 3
local HAUTEUR_LIGNES_MIN = 10
local HAUTEUR_BAS_MIN = 6
local AIDE = "toucher une ligne : auto, marche, arrêt"

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

local function disposer_riche(plan, etat, haut)
  local bas = plan.hauteur - 2
  local disponible = bas - haut + 1
  local colonnes = panneaux.repartir(2, plan.largeur - 2, { 63, 37 }, 1)
  local gauche, droite = colonnes[1], colonnes[2]
  local besoin = 4 + 2 * #etat.lignes
  local haut_lignes = math.max(HAUTEUR_LIGNES_MIN, math.min(besoin, math.floor(disponible * 0.6)))
  if disponible - haut_lignes - 1 < HAUTEUR_BAS_MIN then haut_lignes = disponible end
  plan.cadre_lignes = rectangle(gauche.debut, haut, gauche.taille, haut_lignes)
  plan.cadre_jauge = rectangle(droite.debut, haut, droite.taille, haut_lignes)
  plan.lignes = lignes.disposer(panneaux.interieur(gauche.debut, haut, gauche.taille, haut_lignes), etat, true)
  local y = haut + haut_lignes + 1
  if bas - y + 1 >= HAUTEUR_BAS_MIN then
    plan.cadre_courbe = rectangle(gauche.debut, y, gauche.taille, bas - y + 1)
    plan.cadre_stocks = rectangle(droite.debut, y, droite.taille, bas - y + 1)
    plan.stocks = stocks.disposer(panneaux.interieur(droite.debut, y, droite.taille, bas - y + 1), etat, true)
  end
  plan.zone_reseau = { x1 = droite.debut, x2 = droite.debut + droite.taille - 1, y1 = haut,
    y2 = haut + haut_lignes - 1 }
end

local function disposer_compact(plan, etat, haut)
  local bas = plan.hauteur - 1
  plan.rangee_reseau = haut
  plan.zone_reseau = { x1 = 1, x2 = plan.largeur, y1 = haut, y2 = haut }
  local y = haut + 1
  if bas - y + 1 >= 12 then y = y + 1 end
  local reste = bas - y + 1
  if reste < 2 then return end
  local haut_lignes = math.min(1 + #etat.lignes, math.max(2, math.ceil(reste * 0.55)))
  if #stocks.entrees(etat) == 0 then haut_lignes = math.min(1 + math.max(1, #etat.lignes), reste) end
  haut_lignes = math.min(haut_lignes, reste)
  plan.lignes = lignes.disposer(rectangle(1, y, plan.largeur, haut_lignes), etat, false)
  local y_stocks = y + haut_lignes + 1
  if bas - y_stocks + 1 >= 2 then
    plan.titre_stocks = y_stocks
    plan.stocks = stocks.disposer(rectangle(1, y_stocks + 1, plan.largeur, bas - y_stocks), etat, false)
  end
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local plan = { largeur = largeur, hauteur = hauteur, riche = vues.gabarit(largeur, hauteur) == "riche" }
  plan.alertes = lister_alertes(etat, hauteur)
  plan.montre = reseau.montre(etat)
  local haut = 2 + #plan.alertes + (plan.riche and 1 or 0)
  if plan.riche then disposer_riche(plan, etat, haut) else disposer_compact(plan, etat, haut) end
  return plan
end

local function dessiner_pied(cible, plan, etat)
  local texte = "Prochaine passe dans " .. math.max(0, math.ceil(etat.prochaine_passe or 0)) .. " s"
  local fond = plan.riche and R.surface or R.fond
  local x = plan.riche and 2 or 1
  if plan.riche then panneaux.rectangle(cible, 1, plan.hauteur, plan.largeur, 1, R.surface) end
  local ecrit = dessin.ecrire(cible, x, plan.hauteur, dessin.tronquer(texte, plan.largeur - x + 1), R.discret, fond)
  local longueur = panneaux.longueur(AIDE)
  if x + ecrit + 2 + longueur <= plan.largeur then
    dessin.ecrire(cible, plan.largeur - longueur + (plan.riche and 0 or 1), plan.hauteur, AIDE, R.discret, fond)
  end
end

local function dessiner_riche(cible, plan, etat)
  local c = plan.cadre_lignes
  panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, "Lignes de production", #etat.lignes .. " lignes")
  lignes.dessiner(cible, plan.lignes, etat, R.surface)
  c = plan.cadre_jauge
  local zone = panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, "Stress actuel",
    reseau.annotation(etat, plan.montre))
  reseau.dessiner_jauge(cible, zone, etat, plan.montre)
  if plan.cadre_courbe then
    c = plan.cadre_courbe
    local capacite = plan.montre.mesure and plan.montre.mesure.capacite
    zone = panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, "Stress du réseau",
      type(capacite) == "number" and "capacité " .. panneaux.milliers(capacite) .. " su" or nil)
    reseau.dessiner_courbe(cible, zone, etat, plan.montre)
    c = plan.cadre_stocks
    panneaux.panneau(cible, c.x, c.y, c.largeur, c.hauteur, "Stocks", "sous le seuil en rouge")
    stocks.dessiner(cible, plan.stocks, R.surface)
  end
end

local function dessiner_compact(cible, plan, etat)
  reseau.dessiner_rangee(cible, 1, plan.rangee_reseau, plan.largeur, etat, plan.montre)
  if plan.lignes then lignes.dessiner(cible, plan.lignes, etat, R.fond) end
  if plan.stocks then
    dessin.ecrire(cible, 1, plan.titre_stocks, "stocks", R.discret, R.fond)
    stocks.dessiner(cible, plan.stocks, R.fond)
  end
end

--- Dessine tout le tableau de bord sur la cible, aux rôles du thème (la palette se pose ailleurs). Ramène dans
--- `etat.pagination` la page montrée de chaque liste paginée.
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  dessin.effacer(cible, R.fond)
  local sous_titre = plan.riche and plan.montre.reseau and "réseau " .. plan.montre.reseau.nom or nil
  panneaux.bandeau(cible, "Usine Create", sous_titre, { { etat.heure or "", R.accent } })
  for i, alerte in ipairs(plan.alertes) do
    dessin.ecrire(cible, 1, 1 + i, dessin.aligner(alerte, plan.largeur, "gauche"), R.alerte, R.fond)
  end
  if plan.riche then dessiner_riche(cible, plan, etat) else dessiner_compact(cible, plan, etat) end
  dessiner_pied(cible, plan, etat)
  if type(etat.pagination) == "table" then
    for _, partie in ipairs({ plan.lignes, plan.stocks }) do
      if partie and partie.liste.commande then etat.pagination[partie.liste.cle] = partie.liste.decoupe.page end
    end
  end
end

local function dedans(zone, x, y)
  return x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2
end

--- Action du toucher en (x, y), ou nil : `{ type = "mode", ligne }`, `{ type = "reseau" }` (réseau suivant, s'il y
--- en a plusieurs) ou `{ type = "pagination", liste, page }`.
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  for _, partie in ipairs({ plan.stocks, plan.lignes }) do
    for _, zone in ipairs(partie and partie.zones or {}) do
      if dedans(zone, x, y) then return zone.action end
    end
  end
  if #etat.reseaux > 1 and plan.zone_reseau and dedans(plan.zone_reseau, x, y) then return { type = "reseau" } end
  return nil
end

return vues
