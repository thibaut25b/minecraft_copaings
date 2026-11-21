-- Briques des panneaux de l'usine : listes paginées, couleur du stress, zones touchables.

local pagination = require("commun.pagination")
local theme = require("commun.theme")

local R = theme.ROLES

local base = {}

--- Liste `cle` de `total` éléments dans `zone`, à `pas` rangées par élément si tout tient, sinon une rangée par
--- élément et une commande de pagination sur la dernière rangée. Renvoie { zone, pas, decoupe, commande, zones }.
function base.liste(zone, cle, total, etat, pas)
  if total * pas <= zone.hauteur then
    return { zone = zone, pas = pas, decoupe = { debut = 1, fin = total, commande = false }, zones = {} }
  end
  local demandee = type(etat.pagination) == "table" and etat.pagination[cle] or nil
  local decoupe = pagination.decouper(total, zone.hauteur, demandee)
  local commande = pagination.commande(zone.x, zone.y + zone.hauteur - 1, zone.largeur, decoupe)
  local zones = {}
  if commande then
    for _, bouton in ipairs({ commande.precedent, commande.suivant }) do
      zones[#zones + 1] = { x1 = bouton.x1, x2 = bouton.x2, y1 = bouton.y, y2 = bouton.y,
        action = { type = "pagination", liste = cle, page = bouton.page } }
    end
  end
  return { zone = zone, pas = 1, decoupe = decoupe, commande = commande, zones = zones, cle = cle }
end

--- Dessine la commande de pagination de la liste, si elle en a une, sur `fond`.
function base.dessiner_commande(cible, liste, fond)
  if liste.commande then pagination.dessiner(cible, liste.commande, fond) end
end

--- Rôle de couleur d'une charge : bon sous la reprise, moyen jusqu'au délestage, mauvais au-delà.
function base.couleur_stress(ratio, seuils)
  if ratio == nil then return R.discret end
  if ratio <= seuils.reprise then return R.bon end
  if ratio < seuils.delestage then return R.moyen end
  return R.mauvais
end

--- Pourcentage arrondi : « 82 % ».
function base.pourcent(ratio)
  return math.floor(100 * ratio + 0.5) .. " %"
end

--- Nombre court pour une graduation : 16384 donne « 16k ».
function base.court(nombre)
  if nombre >= 1000 then return math.floor(nombre / 1000 + 0.5) .. "k" end
  return tostring(math.floor(nombre + 0.5))
end

return base
