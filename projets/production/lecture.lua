-- Lecture du stock via le ME Bridge et du contenu du coffre modèle (seul module de production qui touche ces périphériques).

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

--- Contenu de l'inventaire `inventaire` nommé `nom` : `{ [emplacement] = { name, count } }`, ou nil et un
--- message d'erreur si l'inventaire est absent ou en panne.
function lecture.lire_coffre(inventaire, nom)
  if inventaire == nil then return nil, "Coffre modèle absent : " .. tostring(nom) end
  local ok, contenu = peripheriques.appel(inventaire, "list")
  if not ok then return nil, "Coffre modèle : " .. tostring(contenu) end
  if type(contenu) ~= "table" then return nil, "Coffre modèle : contenu illisible" end
  return contenu
end

return lecture
