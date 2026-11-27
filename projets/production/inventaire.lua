-- Instantanés du stock (logique pure) : clé d'un objet, normalisation des items du pont, détection de coupure.

local inventaire = {}

--- Clé d'un objet : `name .. "|" .. nbt` (nbt absent = "" : la variante sans composants).
function inventaire.cle(name, nbt)
  return name .. "|" .. (nbt or "")
end

--- Identifiant et nbt d'une clé (nbt nil pour la variante sans composants).
function inventaire.decouper(cle)
  local name, nbt = cle:match("^(.-)|(.*)$")
  if not name then return cle, nil end
  return name, nbt ~= "" and nbt or nil
end

--- Instantané `{ [cle] = quantité }` et noms `{ [cle] = nom affiché sans crochets }` d'une liste d'items du pont
--- (`getItems`). Items illisibles (pas une table, `name` vide, `count` non numérique) ignorés ; une clé répétée
--- additionne ses quantités.
function inventaire.normaliser(items)
  local instantane, noms = {}, {}
  for _, item in ipairs(items) do
    if type(item) == "table" and type(item.name) == "string" and item.name ~= "" and type(item.count) == "number"
      and (item.nbt == nil or type(item.nbt) == "string") then
      local cle = inventaire.cle(item.name, item.nbt)
      instantane[cle] = (instantane[cle] or 0) + item.count
      if type(item.displayName) == "string" then
        local nom = item.displayName:match("^%[(.*)%]$") or item.displayName
        if nom ~= "" then noms[cle] = nom end
      end
    end
  end
  return instantane, noms
end

--- Vrai si l'instantané est vide (aucune clé).
function inventaire.vide(instantane)
  return next(instantane) == nil
end

--- Nombre de types que l'instantané de référence doit compter pour qu'une coupure soit détectée : vider un objet
--- d'une petite liste suivie n'est pas un lecteur déchargé.
inventaire.TYPES_MINI_COUPURE = 20

--- Vrai si `instantane` est une coupure (lecteur déchargé) par rapport à `reference` (instantané précédent, nil
--- s'il n'y en a pas, d'au moins `TYPES_MINI_COUPURE` types) : la part des types disparus, ou celle des types
--- apparus, ou la chute relative du total dépasse `seuil`. Les parts se rapportent aux types et au total de `reference`.
function inventaire.coupure(reference, instantane, seuil)
  if reference == nil then return false end
  local types, total, disparus = 0, 0, 0
  for cle, quantite in pairs(reference) do
    types, total = types + 1, total + quantite
    if instantane[cle] == nil then disparus = disparus + 1 end
  end
  if types < inventaire.TYPES_MINI_COUPURE then return false end
  local apparus, nouveau_total = 0, 0
  for cle, quantite in pairs(instantane) do
    nouveau_total = nouveau_total + quantite
    if reference[cle] == nil then apparus = apparus + 1 end
  end
  if disparus / types > seuil or apparus / types > seuil then return true end
  return total > 0 and (total - nouveau_total) / total > seuil
end

return inventaire
