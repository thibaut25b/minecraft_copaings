-- Panneau des lignes de production : nom, mode, état et raison, stock ; toucher une ligne change son mode.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("usine.vues.base")

local R = theme.ROLES

local lignes = {}

local LISTE = "lignes"
local LARGEUR_ETAT = 15
local LARGEUR_ETAT_ETROIT = 13
local LARGE = 50
local LARGEUR_STOCK = 15
local LARGEUR_QUANTITE = 7
local NOM_MIN = 14 -- en dessous, la colonne de stock se réduit à la quantité

local LIBELLES_MODE = { auto = "auto", marche = "marche", arret = "arrêt" }

-- Colonnes : x de chaque colonne et largeurs, selon la largeur de la zone ; sous `LARGE`, mode et état rétrécissent.
local function colonnes(zone)
  local large = zone.largeur >= LARGE
  local mode = large and 8 or 7
  local etat = large and LARGEUR_ETAT or LARGEUR_ETAT_ETROIT
  local reste = zone.largeur - mode - 1 - etat - 1
  local stock = reste >= LARGEUR_STOCK + 1 + NOM_MIN and LARGEUR_STOCK or LARGEUR_QUANTITE
  local nom = math.max(1, reste - stock - 1)
  local x_mode = zone.x + nom + 1
  local x_etat = x_mode + mode + 1
  return { nom = nom, mode = mode, etat = etat, stock = stock, x_mode = x_mode, x_etat = x_etat,
    x_stock = zone.x + zone.largeur - stock }
end

--- Géométrie du panneau dans `zone` (en-tête compris) : { zone, colonnes, liste, zones }.
function lignes.disposer(zone, etat, riche)
  local corps = { x = zone.x, y = zone.y + 1, largeur = zone.largeur, hauteur = math.max(0, zone.hauteur - 1) }
  local liste = base.liste(corps, LISTE, #etat.lignes, etat, riche and 2 or 1)
  local zones = {}
  for i = liste.decoupe.debut, liste.decoupe.fin do
    local y = corps.y + (i - liste.decoupe.debut) * liste.pas + liste.pas - 1
    zones[#zones + 1] = { x1 = zone.x, x2 = zone.x + zone.largeur - 1, y1 = y, y2 = y,
      action = { type = "mode", ligne = etat.lignes[i].nom } }
  end
  for _, bouton in ipairs(liste.zones) do zones[#zones + 1] = bouton end
  return { zone = zone, colonnes = colonnes(zone), liste = liste, zones = zones }
end

-- Couleurs de la marque et du texte d'état d'une ligne.
local function couleurs_etat(sortie)
  if sortie.raison == "délestée" then return R.alerte, R.alerte end
  if sortie.raison == "stock inconnu" then return R.moyen, R.moyen end
  if sortie.marche then return R.bon, R.texte end
  return R.bordure, R.discret
end

local function dessiner_mode(cible, x, y, largeur, mode, fond)
  local libelle = LIBELLES_MODE[mode] or mode
  if mode == "auto" then
    dessin.ecrire(cible, x, y, dessin.aligner(libelle, largeur, "centre"), R.discret, fond)
  else
    panneaux.pastille(cible, x, y, libelle, mode == "marche" and R.info or R.alerte, largeur)
  end
end

local function texte_stock(ligne, quantite, largeur)
  if quantite == nil then return "?" end
  if largeur >= LARGEUR_STOCK then return panneaux.milliers(quantite) .. " / " .. panneaux.milliers(ligne.maxi) end
  return panneaux.milliers(quantite)
end

--- Dessine le panneau disposé sur `fond`.
function lignes.dessiner(cible, plan, etat, fond)
  local zone, c = plan.zone, plan.colonnes
  if #etat.lignes == 0 then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Aucune ligne : remplis lignes dans /usine.cfg",
      zone.largeur), R.discret, fond)
    return
  end
  dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("ligne", c.nom), R.discret, fond)
  dessin.ecrire(cible, c.x_mode, zone.y, dessin.aligner("mode", c.mode, "centre"), R.discret, fond)
  dessin.ecrire(cible, c.x_etat, zone.y, "état", R.discret, fond)
  dessin.ecrire(cible, c.x_stock, zone.y, dessin.aligner(c.stock >= LARGEUR_STOCK and "stock / maxi" or "stock",
    c.stock, "droite"), R.discret, fond)
  local liste = plan.liste
  for i = liste.decoupe.debut, liste.decoupe.fin do
    local ligne, sortie = etat.lignes[i], etat.sorties[i] or { marche = false, raison = "en attente" }
    local memoire = etat.memoire[ligne.nom] or { mode = "auto" }
    local y = liste.zone.y + (i - liste.decoupe.debut) * liste.pas + liste.pas - 1
    local marque, encre = couleurs_etat(sortie)
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(ligne.nom, c.nom), sortie.marche and R.texte or R.discret, fond)
    dessiner_mode(cible, c.x_mode, y, c.mode, memoire.mode, fond)
    panneaux.legende(cible, c.x_etat, y, marque, dessin.tronquer(sortie.raison, c.etat - 2), fond, encre)
    local quantite = sortie.quantite
    local bas = quantite ~= nil and quantite <= ligne.mini
    dessin.ecrire(cible, c.x_stock, y, dessin.aligner(texte_stock(ligne, quantite, c.stock), c.stock, "droite"),
      bas and R.mauvais or (quantite == nil and R.moyen or R.texte), fond)
  end
  base.dessiner_commande(cible, liste, fond)
end

return lignes
