-- Lecture du stock via le ME Bridge et du contenu du coffre modèle (seul module de production qui touche ces périphériques).

local peripheriques = require("commun.peripheriques")

local lecture = {}

-- Items de `getItems(filtre)` sur `pont`, ou nil et un message (préfixé de `quoi` sauf hors réseau).
local function lire_items(pont, filtre, quoi)
  local ok, items, code = peripheriques.appel(pont, "getItems", filtre)
  if not ok then return nil, quoi .. " : " .. tostring(items) end
  if items == nil and code == "NOT_CONNECTED" then return nil, "ME Bridge hors réseau (NOT_CONNECTED)" end
  if items == nil then return nil, quoi .. " : " .. tostring(code) end
  if type(items) ~= "table" then return nil, quoi .. " : liste illisible" end
  return items
end

--- Tous les items du réseau (`getItems()` : une entrée par variante), ou nil et un message.
function lecture.lire_tout(pont)
  if pont == nil then return nil, "ME Bridge absent" end
  return lire_items(pont, nil, "getItems")
end

--- Items des `ids` (un `getItems({ name = id })` par id, listes mises bout à bout), ou nil et le message du
--- premier échec : une lecture partielle ferait croire à une consommation.
function lecture.lire_ids(pont, ids)
  if pont == nil then return nil, "ME Bridge absent" end
  local tous = {}
  for _, id in ipairs(ids) do
    local items, message = lire_items(pont, { name = id }, id)
    if not items then return nil, message end
    for _, item in ipairs(items) do tous[#tous + 1] = item end
  end
  return tous
end

--- Contenu de l'inventaire `inventaire` nommé `nom` : `{ [emplacement] = { name, count, nbt? } }`, ou nil et un
--- message d'erreur si l'inventaire est absent ou en panne.
function lecture.lire_coffre(inventaire, nom)
  if inventaire == nil then return nil, "Coffre modèle absent : " .. tostring(nom) end
  local ok, contenu = peripheriques.appel(inventaire, "list")
  if not ok then return nil, "Coffre modèle : " .. tostring(contenu) end
  if type(contenu) ~= "table" then return nil, "Coffre modèle : contenu illisible" end
  return contenu
end

return lecture
