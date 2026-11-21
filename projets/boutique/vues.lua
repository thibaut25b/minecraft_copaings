-- Tableau de bord de la boutique : bandeau, erreurs, articles paginés et dernières ventes, au gabarit riche ou compact.

local dessin = require("commun.dessin")
local pagination = require("commun.pagination")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")

local R = theme.ROLES

local vues = {}

--- Plus petite cible du gabarit riche (panneaux) ; en dessous, gabarit compact.
vues.RICHE = { largeur = 72, hauteur = 24 }

vues.AUCUN_COMPTOIR = "Aucun comptoir vu : relie un Item Trader au réseau de l'ordinateur."
vues.AUCUNE_OFFRE = "Aucune offre de vente : crée-les dans l'Item Trader."
vues.AUCUNE_VENTE = "Aucune vente pour l'instant."

local ECART = 1
local ALERTES_MIN = 2
local PAGE_COMPACT_MIN = 8 -- hauteur sous les alertes à partir de laquelle les ventes ont leur place en compact
local BAS = 0.25           -- part de la réserve sous laquelle le comptoir passe en jaune

-- Colonnes des articles ; `chute` : ordre dans lequel elles tombent quand la place manque (la plus grande d'abord).
local COLONNES = {
  { cle = "nom", titre = "Article", min = 14 },
  { cle = "prix", titre = "Prix", largeur = 8 },
  { cle = "comptoir", titre = "Comptoir", largeur = 8, alignement = "droite" },
  { cle = "barre", titre = "", largeur = 6, chute = 7 },
  { cle = "usine", titre = "Usine", largeur = 6, alignement = "droite", chute = 3 },
  { cle = "route", titre = "Route", largeur = 5, alignement = "droite", chute = 4 },
  { cle = "vendus", titre = "Vendus", largeur = 6, alignement = "droite", chute = 5 },
  { cle = "recette", titre = "Recette", largeur = 7, alignement = "droite", chute = 6 },
}

local COLONNES_VENTES = {
  { titre = "Heure", largeur = 5, facultatif = true },
  { titre = "Joueur", largeur = 14 },
  { titre = "Article", min = 6 },
  { titre = "Montant", largeur = 9, alignement = "droite" },
}

--- Gabarit d'une cible de `largeur` x `hauteur` cases : "riche" ou "compact".
function vues.gabarit(largeur, hauteur)
  if largeur >= vues.RICHE.largeur and hauteur >= vues.RICHE.hauteur then return "riche" end
  return "compact"
end

-- Colonnes retenues sur `largeur` cases, avec leur position x (relative) et leur largeur ; Article prend le reste.
local function placer_colonnes(largeur)
  local retenues = {}
  for _, colonne in ipairs(COLONNES) do retenues[#retenues + 1] = colonne end
  local function fixe()
    local total = ECART * (#retenues - 1)
    for _, colonne in ipairs(retenues) do total = total + (colonne.largeur or colonne.min) end
    return total
  end
  while fixe() > largeur do
    local pire
    for i, colonne in ipairs(retenues) do
      if colonne.chute and (not pire or colonne.chute > retenues[pire].chute) then pire = i end
    end
    if not pire then break end
    table.remove(retenues, pire)
  end
  local places, x = {}, 0
  for _, colonne in ipairs(retenues) do
    local taille = colonne.largeur or math.max(colonne.min, largeur - fixe() + colonne.min)
    places[#places + 1] = { colonne = colonne, x = x, largeur = taille }
    x = x + taille + ECART
  end
  return places
end

local function erreurs_en_alertes(erreurs, hauteur)
  local alertes = {}
  local budget = math.max(ALERTES_MIN, math.floor((hauteur - 2) / 4))
  local montrees = #erreurs <= budget and #erreurs or budget - 1
  for i = 1, montrees do alertes[#alertes + 1] = "! " .. erreurs[i] end
  if #erreurs > montrees then alertes[#alertes + 1] = ("+ %d autres erreurs"):format(#erreurs - montrees) end
  return alertes
end

-- Géométrie de tout l'écran : une seule source pour le dessin et pour le toucher.
local function disposer(cible, etat)
  local largeur, hauteur = cible.getSize()
  local riche = vues.gabarit(largeur, hauteur) == "riche"
  local alertes = erreurs_en_alertes(etat.erreurs or {}, hauteur)
  local haut = 2 + #alertes + (riche and 1 or 0)
  local reste = hauteur - haut + 1 - (riche and 1 or 0)
  local plan = { largeur = largeur, hauteur = hauteur, riche = riche, alertes = alertes }
  -- Les articles prennent ce qu'il leur faut, les ventes le reste, au moins une vente visible.
  local cadre = riche and 3 or 0
  local ventes_min = riche and 5 or (reste >= PAGE_COMPACT_MIN and 3 or 0)
  local ecart = riche and 1 or 0
  local voulue = math.max(1, #(etat.articles or {})) + 1 + cadre
  local hauteur_articles = math.max(0, math.min(voulue, reste - ventes_min - ecart))
  local hauteur_ventes = ventes_min > 0 and reste - hauteur_articles - ecart or 0
  if riche then
    plan.panneau_articles = { x = 2, y = haut, largeur = largeur - 2, hauteur = hauteur_articles }
    plan.articles = panneaux.interieur(2, haut, largeur - 2, hauteur_articles)
    plan.panneau_ventes = { x = 2, y = haut + hauteur_articles + 1, largeur = largeur - 2, hauteur = hauteur_ventes }
    plan.ventes = panneaux.interieur(2, plan.panneau_ventes.y, largeur - 2, hauteur_ventes)
  else
    plan.articles = { x = 1, y = haut, largeur = largeur, hauteur = hauteur_articles }
    if hauteur_ventes > 0 then
      plan.ventes = { x = 1, y = haut + hauteur_articles + 1, largeur = largeur, hauteur = hauteur_ventes - 1 }
      plan.titre_ventes = haut + hauteur_articles
    end
  end
  local total = #(etat.articles or {})
  local demandee = type(etat.pagination) == "table" and etat.pagination.articles or nil
  plan.decoupe = pagination.decouper(total, plan.articles.hauteur - 1, demandee)
  plan.commande = pagination.commande(plan.articles.x, plan.articles.y + plan.articles.hauteur - 1,
    plan.articles.largeur, plan.decoupe)
  return plan
end

local function ecrire(cible, x, y, largeur, valeur, alignement, couleur, fond)
  if largeur < 1 then return end
  dessin.ecrire(cible, x, y, dessin.aligner(valeur, largeur, alignement), couleur, fond)
end

local function nombre(valeur)
  if type(valeur) ~= "number" then return "-" end
  return texte.milliers(valeur)
end

-- Cellules d'une ligne d'article : { [cle] = { texte, couleur } } et le ratio du comptoir.
local function cellules(article, comptes)
  local vendu = comptes[article.objet] or {}
  local ratio = article.comptoir and article.reserve > 0 and article.comptoir / article.reserve or nil
  local couleur = R.bon
  if not article.comptoir then
    couleur = R.alerte
  elseif article.comptoir == 0 then
    couleur = R.mauvais
  elseif ratio and ratio < BAS then
    couleur = R.moyen
  end
  return {
    nom = { article.nom, article.comptoir == 0 and R.mauvais or R.texte },
    prix = { article.texte or "?", R.accent },
    comptoir = { (article.comptoir and texte.milliers(article.comptoir) or "?") .. "/" .. article.reserve, couleur },
    usine = { nombre(article.usine), article.usine == 0 and R.mauvais or R.texte },
    route = { article.en_route > 0 and texte.milliers(article.en_route) or "-", R.info },
    vendus = { nombre(vendu.vendus or 0), R.texte },
    recette = { nombre(vendu.recette or 0), R.bon },
  }, ratio, couleur
end

local function dessiner_articles(cible, plan, etat, fond)
  local zone = plan.articles
  if zone.hauteur < 1 then return end
  local articles = etat.articles or {}
  if #articles == 0 then
    local message = (etat.comptoirs or 0) == 0 and vues.AUCUN_COMPTOIR or vues.AUCUNE_OFFRE
    ecrire(cible, zone.x, zone.y, zone.largeur, message, "gauche", R.discret, fond)
    return
  end
  local places = placer_colonnes(zone.largeur)
  for _, place in ipairs(places) do
    ecrire(cible, zone.x + place.x, zone.y, place.largeur, place.colonne.titre, place.colonne.alignement, R.discret,
      fond)
  end
  local comptes = (etat.ventes or {}).articles or {}
  for rang = plan.decoupe.debut, plan.decoupe.fin do
    local y = zone.y + 1 + rang - plan.decoupe.debut
    local valeurs, ratio, couleur = cellules(articles[rang], comptes)
    for _, place in ipairs(places) do
      local x = zone.x + place.x
      if place.colonne.cle == "barre" then
        panneaux.barre_fine(cible, x, y, place.largeur, ratio or 0, couleur, R.bordure, fond)
      else
        local cellule = valeurs[place.colonne.cle]
        ecrire(cible, x, y, place.largeur, cellule[1], place.colonne.alignement, cellule[2], fond)
      end
    end
  end
  if plan.commande then
    pagination.dessiner(cible, plan.commande, fond)
    local rappel = plan.decoupe.debut .. " à " .. plan.decoupe.fin .. " sur " .. #articles
    if panneaux.longueur(rappel) <= plan.commande.x - zone.x - 1 then
      ecrire(cible, zone.x, plan.commande.precedent.y, panneaux.longueur(rappel), rappel, "gauche", R.discret, fond)
    end
  end
end

local function dessiner_ventes(cible, zone, etat, noms, fond)
  if not zone or zone.hauteur < 1 then return end
  local dernieres = (etat.ventes or {}).dernieres or {}
  if #dernieres == 0 then
    ecrire(cible, zone.x, zone.y, zone.largeur, vues.AUCUNE_VENTE, "gauche", R.discret, fond)
    return
  end
  local lignes = {}
  for i, vente in ipairs(dernieres) do
    local article = noms[vente.objet] or vente.objet
    if (vente.quantite or 0) > 1 then article = vente.quantite .. " x " .. article end
    lignes[i] = { vente.heure or "", tostring(vente.joueur), article,
      { texte = type(vente.texte) == "string" and vente.texte or texte.milliers(vente.montant or 0), couleur = R.bon } }
  end
  local visibles = {}
  for i = 1, math.min(#lignes, zone.hauteur - 1) do visibles[i] = lignes[i] end
  dessin.tableau(cible, zone.x, zone.y, zone.largeur, zone.hauteur, COLONNES_VENTES, visibles, { fond = fond })
end

--- Dessine tout le tableau de bord sur la cible, aux rôles du thème (la palette se pose ailleurs). Ramène dans
--- `etat.pagination.articles` la page montrée (retombée à 1 si la liste a rétréci).
function vues.dessiner(cible, etat)
  local plan = disposer(cible, etat)
  dessin.effacer(cible, R.fond)
  local recette = (etat.ventes or {}).recette or 0
  local comptoirs = etat.comptoirs or 0
  panneaux.bandeau(cible, "Boutique", plan.riche and (comptoirs .. " comptoir" .. (comptoirs > 1 and "s" or "")) or nil,
    { { "Recette " .. texte.milliers(recette), R.bon }, { etat.heure or "", R.accent } })
  for i, alerte in ipairs(plan.alertes) do
    ecrire(cible, 1, 1 + i, plan.largeur, alerte, "gauche", R.alerte, R.fond)
  end
  local noms = {}
  for _, article in ipairs(etat.articles or {}) do noms[article.objet] = article.nom end
  if plan.riche then
    local p = plan.panneau_articles
    if p.hauteur >= 3 then
      panneaux.panneau(cible, p.x, p.y, p.largeur, p.hauteur, "Articles", "comptoir / réserve")
      dessiner_articles(cible, plan, etat, R.surface)
    end
    local v = plan.panneau_ventes
    panneaux.panneau(cible, v.x, v.y, v.largeur, v.hauteur, "Dernières ventes")
    dessiner_ventes(cible, plan.ventes, etat, noms, R.surface)
  else
    dessiner_articles(cible, plan, etat, R.fond)
    if plan.ventes then
      ecrire(cible, 1, plan.titre_ventes, plan.largeur, "Dernières ventes", "gauche", R.accent, R.fond)
      dessiner_ventes(cible, plan.ventes, etat, noms, R.fond)
    end
  end
  if type(etat.pagination) == "table" then etat.pagination.articles = plan.decoupe.page end
end

--- Action du toucher en (x, y), ou nil : `{ type = "pagination", page }`.
function vues.action_touchee(cible, etat, x, y)
  local plan = disposer(cible, etat)
  if not plan.commande then return nil end
  for _, bouton in ipairs({ plan.commande.precedent, plan.commande.suivant }) do
    if y == bouton.y and x >= bouton.x1 and x <= bouton.x2 then return { type = "pagination", page = bouton.page } end
  end
  return nil
end

return vues
