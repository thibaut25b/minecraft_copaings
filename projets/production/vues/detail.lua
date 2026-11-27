-- Détail de l'objet choisi : nom et bouton Reset, stock, variation depuis le départ, débits moyens sur trois fenêtres.

local dessin = require("commun.dessin")
local panneaux = require("commun.panneaux")
local texte = require("commun.texte")
local theme = require("commun.theme")
local flux = require("production.flux")
local base = require("production.vues.base")

local R = theme.ROLES

local detail = {}

local LIBELLE_RESET = "Reset"
local LARGEUR_LIBELLE = 7

--- Hauteur qui montre tout le détail aéré ; en dessous, sans rangée vide, puis tronqué par le bas.
detail.HAUTEUR_AEREE = 8

--- Géométrie du détail de `cle` dans `zone` : { zone, cle, reset, zones }. Le bouton Reset remet son suivi à zéro.
function detail.disposer(zone, cle)
  local largeur = #LIBELLE_RESET + 2
  local reset = { x1 = zone.x + zone.largeur - largeur, x2 = zone.x + zone.largeur - 1, y1 = zone.y, y2 = zone.y }
  reset.action = { type = "reset", cle = cle }
  return { zone = zone, cle = cle, reset = reset, zones = zone.hauteur >= 1 and cle and { reset } or {} }
end

-- Rangées du détail : { libelle, cellules { { texte, couleur } } } ; nil = rangée vide (omise si la place manque).
local function rangees(etat, cle)
  local objet = etat.flux and etat.flux.objets[cle]
  local liste = { false, { "Stock", { { objet and texte.milliers(objet.stock) or "0", R.texte } } } }
  local variation, duree = nil, nil
  if etat.flux then variation, duree = flux.depuis_depart(etat.flux, cle) end
  if variation then
    liste[#liste + 1] = { "Départ", { { (variation > 0 and "+" or "") .. texte.milliers(variation) .. " en "
      .. base.duree(duree), base.couleur_debit(variation, "s") } } }
  else
    liste[#liste + 1] = { "Départ", { { "-", R.discret } } }
  end
  liste[#liste + 1] = false
  local entete, prod, conso = { flux.LIBELLES[etat.unite], {} }, { "Prod", {} }, { "Conso", {} }
  for i, fenetre in ipairs(flux.FENETRES) do
    local production, consommation, _, partiel = 0, 0, 0, true
    if etat.flux and etat.instant then
      production, consommation, _, partiel = flux.debits(etat.flux, cle, fenetre, etat.instant)
    end
    entete[2][i] = { base.LIBELLES_FENETRES[fenetre], R.discret }
    prod[2][i] = { base.texte_debit(production, partiel, etat.unite), base.couleur_debit(production, etat.unite) }
    conso[2][i] = { base.texte_debit(-consommation, partiel, etat.unite), base.couleur_debit(-consommation, etat.unite) }
  end
  liste[#liste + 1] = entete
  liste[#liste + 1] = prod
  if etat.options.consommation then liste[#liste + 1] = conso end
  return liste
end

-- Nombre de colonnes de fenêtres qui tiennent sur `place` cases, et leur largeur commune.
local function colonnes(liste, place)
  local plus = 0
  for _, rangee in ipairs(liste) do
    if rangee and #rangee[2] > 1 then
      for _, cellule in ipairs(rangee[2]) do plus = math.max(plus, panneaux.longueur(cellule[1])) end
    end
  end
  local nombre = math.max(1, math.min(#flux.FENETRES, math.floor(place / (plus + 1))))
  return nombre, math.floor(place / nombre)
end

--- Dessine le détail disposé sur `fond` ; sans objet choisi, un message discret.
function detail.dessiner(cible, plan, etat, fond)
  local zone = plan.zone
  if zone.hauteur < 1 then return end
  if not plan.cle then
    dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer("Aucun objet choisi", zone.largeur), R.discret, fond)
    return
  end
  dessin.ecrire(cible, zone.x, zone.y, dessin.tronquer(base.nom(etat, plan.cle), zone.largeur - #LIBELLE_RESET - 3),
    R.accent, fond)
  panneaux.pastille(cible, plan.reset.x1, zone.y, LIBELLE_RESET, R.alerte)
  local liste = rangees(etat, plan.cle)
  local aeree = zone.hauteur >= detail.HAUTEUR_AEREE
  local place = zone.largeur - LARGEUR_LIBELLE
  local nombre, largeur = colonnes(liste, place)
  local y = zone.y + 1
  for _, rangee in ipairs(liste) do
    if y > zone.y + zone.hauteur - 1 then return end
    if rangee then
      dessin.ecrire(cible, zone.x, y, dessin.tronquer(rangee[1], LARGEUR_LIBELLE - 1), R.discret, fond)
      local cellules = rangee[2]
      if #cellules == 1 then
        dessin.ecrire(cible, zone.x + LARGEUR_LIBELLE, y, dessin.aligner(cellules[1][1], place, "droite"),
          cellules[1][2], fond)
      else
        for i = 1, nombre do
          local x = zone.x + zone.largeur - (nombre - i + 1) * largeur
          dessin.ecrire(cible, x, y, dessin.aligner(cellules[i][1], largeur, "droite"), cellules[i][2], fond)
        end
      end
      y = y + 1
    elseif aeree then
      y = y + 1
    end
  end
end

return detail
