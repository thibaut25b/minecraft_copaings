-- Liste des objets suivis : nom, stock et débit moyen sur une minute, une ligne touchable par objet, paginée.

local dessin = require("commun.dessin")
local pagination = require("commun.pagination")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local debit = require("production.debit")
local base = require("production.vues.base")

local R = theme.ROLES

local liste = {}

local CLE = "objets"
local LARGEUR_NOM_MINI = 14

--- Géométrie de la liste dans `zone` : { zone, decoupe, commande, zones }. Une ligne touchée choisit son objet.
function liste.disposer(zone, etat)
  local demandee = type(etat.pagination) == "table" and etat.pagination[CLE] or nil
  local decoupe = pagination.decouper(#etat.objets, zone.hauteur, demandee)
  local zones = {}
  for i = decoupe.debut, decoupe.fin do
    local y = zone.y + i - decoupe.debut
    zones[#zones + 1] = { x1 = zone.x, x2 = zone.x + zone.largeur - 1, y1 = y, y2 = y,
      action = { type = "selection", objet = etat.objets[i].objet } }
  end
  local commande = decoupe.commande and zone.hauteur >= 1
    and pagination.commande(zone.x, zone.y + zone.hauteur - 1, zone.largeur, decoupe) or nil
  for _, bouton in ipairs(commande and { commande.precedent, commande.suivant } or {}) do
    zones[#zones + 1] = { x1 = bouton.x1, x2 = bouton.x2, y1 = bouton.y, y2 = bouton.y,
      action = { type = "pagination", liste = CLE, page = bouton.page } }
  end
  return { zone = zone, decoupe = decoupe, commande = commande, zones = zones }
end

-- Textes de stock et de débit de chaque objet, et leurs largeurs de colonne (sur tous les objets : stable d'une page à l'autre).
local function colonnes(etat, unite)
  local lignes, largeur_stock, largeur_debit = {}, 0, 0
  for i, entree in ipairs(etat.objets) do
    local serie = etat.series[entree.objet] or {}
    local par_seconde, partiel = debit.debit(serie, base.FENETRE_LISTE)
    local ligne = { stock = base.stock(etat, entree.objet), debit = base.texte_debit(par_seconde, partiel, unite),
      encre = base.couleur_debit(par_seconde, unite) }
    lignes[i] = ligne
    largeur_stock = math.max(largeur_stock, panneaux.longueur(ligne.stock))
    largeur_debit = math.max(largeur_debit, panneaux.longueur(ligne.debit))
  end
  return lignes, largeur_stock, largeur_debit
end

--- Dessine la liste disposée sur `fond`, la ligne de l'objet `choisi` en évidence.
function liste.dessiner(cible, plan, etat, choisi, fond)
  local zone, decoupe = plan.zone, plan.decoupe
  if #etat.objets == 0 then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Aucun objet suivi", zone.largeur), R.discret, fond)
    return
  end
  local lignes, largeur_stock, largeur_debit = colonnes(etat, etat.unite)
  if zone.largeur - largeur_stock - largeur_debit - 2 < LARGEUR_NOM_MINI then largeur_stock = 0 end
  local place = zone.largeur - largeur_debit - (largeur_stock > 0 and largeur_stock + 1 or 0) - 1
  for i = decoupe.debut, decoupe.fin do
    local entree, ligne = etat.objets[i], lignes[i]
    local y = zone.y + i - decoupe.debut
    local choisie = entree.objet == choisi
    local fond_ligne = choisie and R.bordure or fond
    panneaux.rectangle(cible, zone.x, y, zone.largeur, 1, fond_ligne)
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(base.nom(etat, entree), place), choisie and R.texte or R.discret,
      fond_ligne)
    if largeur_stock > 0 then
      dessin.ecrire(cible, zone.x + place + 1, y, dessin.aligner(ligne.stock, largeur_stock, "droite"), R.texte,
        fond_ligne)
    end
    dessin.ecrire(cible, zone.x + zone.largeur - largeur_debit, y, dessin.aligner(ligne.debit, largeur_debit, "droite"),
      ligne.encre, fond_ligne)
  end
  if plan.commande then pagination.dessiner(cible, plan.commande, fond) end
end

return liste
