-- Panneau des stocks : produits des lignes et stocks surveillés, ceux sous leur seuil en rouge et en tête.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local theme = require("commun.theme")
local base = require("usine.vues.base")

local R = theme.ROLES

local stocks = {}

local LISTE = "stocks"
local LARGEUR_SEUIL = 30 -- dès cette largeur, le seuil suit la quantité

-- « create:iron_sheet » donne « iron sheet ».
local function libelle_objet(objet)
  return (objet:gsub("^[^:]*:", ""):gsub("_", " "))
end

--- Entrées affichées, triées : { nom, quantite (nil si inconnue), seuil, bas }. Le produit d'une ligne a pour seuil
--- son `mini` ; un stock surveillé du même objet impose son nom et son seuil.
function stocks.entrees(etat)
  local par_objet, ordre = {}, {}
  local function ajouter(objet, nom, seuil)
    if not par_objet[objet] then ordre[#ordre + 1] = objet end
    par_objet[objet] = { nom = nom, seuil = seuil }
  end
  for _, ligne in ipairs(etat.lignes) do
    if not par_objet[ligne.produit] then ajouter(ligne.produit, libelle_objet(ligne.produit), ligne.mini) end
  end
  for _, surveille in ipairs(etat.stocks) do ajouter(surveille.objet, surveille.nom, surveille.seuil) end
  local entrees = {}
  for i, objet in ipairs(ordre) do
    local quantite = etat.stock and (etat.stock[objet] or 0) or nil
    local entree = par_objet[objet]
    entrees[#entrees + 1] = { nom = entree.nom, seuil = entree.seuil, quantite = quantite, ordre = i,
      bas = quantite ~= nil and quantite < entree.seuil }
  end
  table.sort(entrees, function(a, b)
    if a.bas ~= b.bas then return a.bas end
    if a.quantite and b.quantite and a.seuil > 0 and b.seuil > 0 and a.quantite / a.seuil ~= b.quantite / b.seuil then
      return a.quantite / a.seuil < b.quantite / b.seuil
    end
    return a.ordre < b.ordre
  end)
  return entrees
end

--- Géométrie du panneau dans `zone` : { zone, entrees, liste, zones }.
function stocks.disposer(zone, etat, riche)
  local entrees = stocks.entrees(etat)
  local liste = base.liste(zone, LISTE, #entrees, etat, riche and 2 or 1)
  return { zone = zone, entrees = entrees, liste = liste, zones = liste.zones }
end

--- Dessine le panneau disposé sur `fond`.
function stocks.dessiner(cible, plan, fond)
  local zone, liste = plan.zone, plan.liste
  if #plan.entrees == 0 then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Aucun stock surveillé", zone.largeur), R.discret, fond)
    return
  end
  for i = liste.decoupe.debut, liste.decoupe.fin do
    local entree = plan.entrees[i]
    local y = zone.y + (i - liste.decoupe.debut) * liste.pas
    local chiffres = entree.quantite and panneaux.milliers(entree.quantite) or "?"
    if zone.largeur >= LARGEUR_SEUIL then chiffres = chiffres .. " / " .. panneaux.milliers(entree.seuil) end
    local place = zone.largeur - #chiffres - 1
    local encre = entree.bas and R.mauvais or R.texte
    dessin.ecrire(cible, zone.x, y, dessin.tronquer(entree.nom, place), encre, fond)
    dessin.ecrire(cible, zone.x + zone.largeur - #chiffres, y, chiffres,
      entree.bas and R.mauvais or (entree.quantite and R.discret or R.moyen), fond)
    if liste.pas == 2 and entree.quantite then
      local ratio = entree.seuil > 0 and entree.quantite / (2 * entree.seuil) or 1
      local couleur = entree.bas and R.mauvais or (ratio < 0.75 and R.moyen or R.bon)
      panneaux.barre_fine(cible, zone.x, y + 1, zone.largeur, ratio, couleur, R.bordure, fond)
    end
  end
  base.dessiner_commande(cible, liste, fond)
end

return stocks
