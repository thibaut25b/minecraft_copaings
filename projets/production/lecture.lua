-- Lecture des quantités d'items dans l'AE via le ME Bridge (seul module de production qui touche le pont).

local peripheriques = require("commun.peripheriques")

local lecture = {}

--- Lit le stock de chaque entrée de `objets` ({ objet, nom }) sur `pont`. Renvoie `quantites` ({ [objet] =
--- quantité }, absent de l'AE = 0, illisible = pas de clé), `noms` ({ [objet] = nom affiché } pour les entrées
--- dont `nom` est "" et que l'AE connaît) et la liste des messages d'erreur. Pont hors réseau : un seul message.
function lecture.lire(pont, objets)
  local quantites, noms, erreurs = {}, {}, {}
  if pont == nil then
    erreurs[1] = "ME Bridge absent"
    return quantites, noms, erreurs
  end
  for _, entree in ipairs(objets) do
    local ok, item, code = peripheriques.appel(pont, "getItem", { name = entree.objet })
    if not ok then
      erreurs[#erreurs + 1] = entree.objet .. " : " .. tostring(item)
    elseif item == nil and code == nil then
      quantites[entree.objet] = 0
    elseif item == nil then
      if code == "NOT_CONNECTED" then
        erreurs[#erreurs + 1] = "ME Bridge hors réseau (NOT_CONNECTED)"
        return quantites, noms, erreurs
      end
      erreurs[#erreurs + 1] = entree.objet .. " : " .. tostring(code)
    elseif type(item) ~= "table" or type(item.count) ~= "number" then
      erreurs[#erreurs + 1] = entree.objet .. " : quantité illisible"
    else
      quantites[entree.objet] = item.count
      if entree.nom == "" and type(item.displayName) == "string" and item.displayName ~= "" then
        noms[entree.objet] = item.displayName
      end
    end
  end
  return quantites, noms, erreurs
end

return lecture
