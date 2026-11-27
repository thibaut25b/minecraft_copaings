-- Briques des vues de la production : objet choisi, noms, textes et couleurs des débits, zones touchables.

local texte = require("commun.texte")
local theme = require("commun.theme")
local debit = require("production.debit")

local R = theme.ROLES

local base = {}

--- Fenêtres des débits moyens du détail, en secondes, avec leur libellé.
base.FENETRES = { { 10, "10 s" }, { 60, "1 min" }, { 600, "10 min" }, { 3600, "1 h" } }

--- Fenêtre du débit montré dans la liste, en secondes.
base.FENETRE_LISTE = 60

--- Identifiant de l'objet choisi : `etat.selection` s'il est suivi, sinon le premier objet, nil sans objet.
function base.selection(etat)
  if base.entree(etat, etat.selection) then return etat.selection end
  return etat.objets[1] and etat.objets[1].objet or nil
end

--- Entrée { objet, nom } suivie sous l'identifiant `objet`, ou nil.
function base.entree(etat, objet)
  for _, entree in ipairs(etat.objets) do
    if entree.objet == objet then return entree end
  end
  return nil
end

--- Nom affiché d'une `entree` { objet, nom } : son nom de config, sinon celui lu dans l'AE, sinon l'identifiant.
function base.nom(etat, entree)
  if entree.nom ~= "" then return entree.nom end
  return (etat.noms or {})[entree.objet] or entree.objet
end

--- Stock lu à la dernière mesure : « 12 480 », ou « ? » s'il est illisible.
function base.stock(etat, objet)
  local quantite = (etat.quantites or {})[objet]
  return quantite and texte.milliers(quantite) or "?"
end

-- Débit signé à un chiffre après la virgule sous 10, entier au-delà.
local function nombre_signe(valeur)
  local absolu = math.abs(valeur)
  if absolu < 0.05 then return "0" end
  local signe = valeur < 0 and "-" or "+"
  if absolu < 10 then return signe .. string.format("%.1f", absolu):gsub("%.", ",") end
  return signe .. texte.milliers(absolu)
end

--- Débit en items/s (nil : pas encore mesurable) converti dans l'unité : « +12,5 », « ~-3 » si `partiel`, « - » si nil.
function base.texte_debit(par_seconde, partiel, unite)
  if par_seconde == nil then return "-" end
  return (partiel and "~" or "") .. nombre_signe(debit.convertir(par_seconde, unite))
end

--- Rôle de couleur d'un débit : bon s'il monte, mauvais s'il baisse, discret s'il est inconnu, texte à zéro.
function base.couleur_debit(par_seconde, unite)
  if par_seconde == nil then return R.discret end
  local valeur = debit.convertir(par_seconde, unite)
  if math.abs(valeur) < 0.05 then return R.texte end
  return valeur > 0 and R.bon or R.mauvais
end

--- Durée en secondes lisible : « 45 s », « 12 min », « 3 h 20 min ».
function base.duree(secondes)
  secondes = math.floor(secondes + 0.5)
  if secondes < 60 then return secondes .. " s" end
  local minutes = math.floor(secondes / 60)
  if minutes < 60 then return minutes .. " min" end
  local heures = math.floor(minutes / 60)
  if minutes % 60 == 0 then return heures .. " h" end
  return heures .. " h " .. minutes % 60 .. " min"
end

--- Vrai si (x, y) est dans la zone { x1, x2, y1, y2 }.
function base.dedans(zone, x, y)
  return x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2
end

return base
