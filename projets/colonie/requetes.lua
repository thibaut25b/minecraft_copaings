-- Requêtes des colons : normalisation des requêtes brutes et décision pure (livrer, fabriquer, attendre...).

local requetes = {}

-- Tags d'item qui font d'une requête une demande d'équipement (motifs Lua sur le nom du tag).
local TAGS_EQUIPEMENT = {
  "^c:tools$", "^c:tools/",
  "^c:armors$", "^c:armors/",
  "^minecraft:swords$", "^minecraft:axes$", "^minecraft:pickaxes$", "^minecraft:shovels$", "^minecraft:hoes$",
  "^minecraft:head_armor$", "^minecraft:chest_armor$", "^minecraft:leg_armor$", "^minecraft:foot_armor$",
}

local function est_equipement(item)
  if type(item.tags) ~= "table" then return false end
  for tag in pairs(item.tags) do
    for _, motif in ipairs(TAGS_EQUIPEMENT) do
      if type(tag) == "string" and tag:find(motif) then return true end
    end
  end
  return false
end

local function meme_position(a, b)
  return type(b) == "table" and a.x == b.x and a.y == b.y and a.z == b.z
end

local function nommer_demandeur(cible, batiments)
  if type(cible) == "string" then return cible end
  if type(cible) ~= "table" then return "" end
  for _, batiment in ipairs(batiments) do
    if meme_position(cible, batiment.pos) then
      return batiment.displayName or batiment.type or ""
    end
  end
  return ""
end

local function normaliser_une(brute, batiments)
  local candidats, vus, equipement = {}, {}, false
  for _, item in ipairs(type(brute.items) == "table" and brute.items or {}) do
    if type(item) == "table" and type(item.name) == "string" and not vus[item.name] then
      vus[item.name] = true
      candidats[#candidats + 1] = item.name
      equipement = equipement or est_equipement(item)
    end
  end
  local quantite = tonumber(brute.count) or 0
  local quantite_min = math.min(tonumber(brute.minCount) or quantite, quantite)
  return {
    id = tostring(brute.id),
    libelle = brute.displayName or "",
    demandeur = nommer_demandeur(brute.target, batiments),
    quantite = quantite,
    quantite_min = quantite_min,
    candidats = candidats,
    equipement = equipement,
  }
end

--- Transforme le retour de `getRequests` en requêtes normalisées ; `batiments` (retour de `getBuildings`) nomme le demandeur.
function requetes.normaliser(brutes, batiments)
  local liste = {}
  for _, brute in ipairs(brutes or {}) do
    if type(brute) == "table" then liste[#liste + 1] = normaliser_une(brute, batiments or {}) end
  end
  return liste
end

--- Sépare les motifs d'exclusion utilisables des motifs Lua mal formés : renvoie `valides, invalides`.
-- Le `pcall` ne couvre que `string.find` sur un motif fourni par la config.
function requetes.trier_motifs(motifs)
  local valides, invalides = {}, {}
  for _, motif in ipairs(motifs or {}) do
    if type(motif) == "string" and pcall(string.find, "", motif) then
      valides[#valides + 1] = motif
    else
      invalides[#invalides + 1] = tostring(motif)
    end
  end
  return valides, invalides
end

local function exclu(nom, motifs)
  for _, motif in ipairs(motifs) do
    if nom:find(motif) then return true end
  end
  return false
end

local function action(type_action, item, quantite, raison)
  return { type = type_action, item = item, quantite = quantite, raison = raison }
end

--- Décide quoi faire d'une requête normalisée. `stocks[nom] = { quantite, fabricable }`, `en_cours[nom] = true`
-- si une fabrication tourne. `reglages.exclusions` doit déjà être passé par `trier_motifs`.
function requetes.decider(requete, stocks, reglages, en_cours)
  if requete.equipement and reglages.ignorer_equipement then
    return action("ignorer", nil, 0, "équipement laissé aux colons")
  end
  local retenus = {}
  for _, nom in ipairs(requete.candidats) do
    if not exclu(nom, reglages.exclusions) then retenus[#retenus + 1] = nom end
  end
  if #requete.candidats == 0 then return action("manquant", nil, 0, "aucun item exploitable") end
  if #retenus == 0 then return action("ignorer", nil, 0, "exclu par les réglages") end

  local seuil = math.max(requete.quantite_min, 1)
  for _, nom in ipairs(retenus) do
    local stock = stocks[nom]
    if stock and stock.quantite >= seuil then
      return action("livrer", nom, math.min(requete.quantite, stock.quantite), "")
    end
  end
  for _, nom in ipairs(retenus) do
    if en_cours[nom] then return action("attendre", nom, 0, "fabrication en cours") end
  end
  if reglages.fabriquer then
    for _, nom in ipairs(retenus) do
      local stock = stocks[nom]
      if stock and stock.fabricable then
        return action("fabriquer", nom, requete.quantite - stock.quantite, "")
      end
    end
  end
  return action("manquant", nil, 0, "stock insuffisant")
end

return requetes
