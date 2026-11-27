-- Débit des items : calculs purs sur des séries d'échantillons { t = secondes, n = quantité }, du plus ancien au plus récent.

local debit = {}

--- Unités de débit, dans l'ordre de rotation de l'affichage.
debit.UNITES = { "s", "min", "h" }

--- Libellé affiché de chaque unité.
debit.LIBELLES = { s = "/s", min = "/min", h = "/h" }

local SECONDES = { s = 1, min = 60, h = 3600 }

--- Part minimale de la fenêtre que l'historique doit couvrir pour que le débit ne soit pas dit partiel.
debit.COUVERTURE_MINI = 0.95

-- Indice du dernier échantillon dont l'instant est <= `instant` (0 s'il n'y en a pas), par dichotomie.
local function dernier_jusqu_a(serie, instant)
  local bas, haut = 0, #serie
  while bas < haut do
    local milieu = math.floor((bas + haut + 1) / 2)
    if serie[milieu].t <= instant then bas = milieu else haut = milieu - 1 end
  end
  return bas
end

-- Quantité au `instant`, interpolée entre deux échantillons voisins. Suppose 1 <= i = dernier_jusqu_a.
local function valeur_a(serie, i, instant)
  local avant, apres = serie[i], serie[i + 1]
  if not apres or apres.t == avant.t then return avant.n end
  return avant.n + (apres.n - avant.n) * (instant - avant.t) / (apres.t - avant.t)
end

--- Ajoute à `series[objet]` l'échantillon { t = instant, n = quantité } de chaque lecture numérique
--- (`lectures = { [objet] = quantité }` ; nil = illisible, rien n'est ajouté), puis retire de chaque série les
--- échantillons plus vieux que `duree` secondes en gardant les 2 derniers au moins.
function debit.noter(series, lectures, instant, duree)
  for objet, quantite in pairs(lectures) do
    if type(quantite) == "number" then
      local serie = series[objet]
      if not serie then
        serie = {}
        series[objet] = serie
      end
      serie[#serie + 1] = { t = instant, n = quantite }
    end
  end
  for _, serie in pairs(series) do
    while #serie > 2 and serie[1].t < instant - duree do
      table.remove(serie, 1)
    end
  end
end

--- Débit moyen en items par seconde sur les `fenetre` dernières secondes (négatif quand le stock baisse), puis
--- `partiel` : vrai si l'historique couvre moins de 95 % de la fenêtre. nil s'il manque des échantillons.
function debit.debit(serie, fenetre)
  local dernier = #serie
  if dernier < 2 or fenetre <= 0 then return nil end
  local depart = math.max(dernier_jusqu_a(serie, serie[dernier].t - fenetre), 1)
  local duree = serie[dernier].t - serie[depart].t
  if duree <= 0 then return nil end
  return (serie[dernier].n - serie[depart].n) / duree, duree < fenetre * debit.COUVERTURE_MINI
end

--- `nombre` débits (items/s) pour des tranches égales couvrant les `duree` dernières secondes, de la plus
--- ancienne à la plus récente. Une tranche sans échantillon, ou qui commence avant l'historique, vaut nil.
function debit.barres(serie, duree, nombre)
  local barres = {}
  local dernier = #serie
  if dernier < 2 or duree <= 0 or nombre < 1 then return barres end
  local fin = serie[dernier].t
  local largeur = duree / nombre
  for k = 1, nombre do
    local a = fin - duree + (k - 1) * largeur
    local b = k == nombre and fin or fin - duree + k * largeur
    local ia, ib = dernier_jusqu_a(serie, a), dernier_jusqu_a(serie, b)
    if ia >= 1 and ib > ia then
      barres[k] = (valeur_a(serie, ib, b) - valeur_a(serie, ia, a)) / largeur
    end
  end
  return barres
end

--- Note dans `departs[objet]` le premier échantillon { t, n } lu de chaque objet numérique (`lectures` comme pour
--- `noter`) ; un départ déjà noté ne change pas. Vider `departs[objet]` remet le suivi de l'objet à zéro.
function debit.noter_departs(departs, lectures, instant)
  for objet, quantite in pairs(lectures) do
    if type(quantite) == "number" and departs[objet] == nil then departs[objet] = { t = instant, n = quantite } end
  end
end

--- Variation totale et durée écoulée entre le `depart` de l'objet (voir `noter_departs`) et le dernier échantillon
--- de `serie`, même si la fenêtre gardée a déjà oublié le départ. nil sans départ, sans échantillon ou sans durée.
function debit.depuis_debut(serie, depart)
  local dernier = serie[#serie]
  if not depart or not dernier or dernier.t <= depart.t then return nil end
  return dernier.n - depart.n, dernier.t - depart.t
end

--- Convertit un débit en items/s vers l'unité `unite` ("s", "min" ou "h"). Unité inconnue : erreur.
function debit.convertir(debit_par_seconde, unite)
  local facteur = SECONDES[unite]
  if not facteur then error("unité inconnue : " .. tostring(unite), 2) end
  return debit_par_seconde * facteur
end

return debit
