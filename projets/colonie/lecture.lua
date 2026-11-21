-- Lecture de la colonie par le Colony Integrator : instantané pour l'affichage et requêtes normalisées.

local peripheriques = require("commun.peripheriques")
local requetes = require("colonie.requetes")

local lecture = {}

-- Libellés des `WorkOrderType.name` connus ; un type inconnu s'affiche en minuscules.
local TYPES_TRAVAUX = {
  BUILD = "construction", UPGRADE = "amélioration", REPAIR = "réparation", REMOVE = "démolition",
}

-- Valeur d'une lecture, ou `defaut` si l'appel échoue ou renvoie un autre type.
local function lire(integrateur, methode, defaut)
  local ok, valeur = peripheriques.appel(integrateur, methode)
  if ok and type(valeur) == type(defaut) then return valeur end
  return defaut
end

local function metier(job)
  if type(job) ~= "string" then return "" end
  local nom = job:match(":(.+)$") or job
  return nom:sub(1, 1):upper() .. nom:sub(2)
end

local function habitant(citoyen)
  return {
    nom = citoyen.name or "",
    metier = metier(citoyen.job),
    etat = citoyen.state or "",
    sante = tonumber(citoyen.health) or 0,         -- 0 : entité non chargée
    sante_max = tonumber(citoyen.maxHealth) or 0,
    loge = citoyen.homeBuilding ~= nil,
    employe = citoyen.job ~= nil,
  }
end

local function meme_position(a, b)
  return type(a) == "table" and type(b) == "table" and a.x == b.x and a.y == b.y and a.z == b.z
end

-- Nom du citoyen qui travaille dans le bâtiment `hutte` (bâtiment de base), "" sinon.
local function nom_du_constructeur(hutte, citoyens)
  if type(hutte) ~= "table" then return "" end
  for _, citoyen in ipairs(citoyens) do
    if type(citoyen) == "table" and type(citoyen.workBuilding) == "table"
      and meme_position(citoyen.workBuilding.pos, hutte.pos) then
      return citoyen.name or ""
    end
  end
  return ""
end

local function travail(commande, citoyens)
  local type_brut = commande.type
  return {
    id = commande.id,
    batiment = commande.displayName or "",
    type = TYPES_TRAVAUX[type_brut] or (type(type_brut) == "string" and type_brut:lower() or ""),
    niveau = tonumber(commande.targetLevel) or 0,
    constructeur = nom_du_constructeur(commande.builderHome, citoyens),
    pris = commande.isClaimed == true,
  }
end

local function verifier_colonie(integrateur)
  if integrateur == nil then return false, "Intégrateur de colonie introuvable" end
  local ok, dedans = peripheriques.appel(integrateur, "isInColony")
  if not ok then return false, "Intégrateur illisible : " .. tostring(dedans) end
  if dedans ~= true then return false, "Intégrateur hors colonie" end
  return true
end

--- Renvoie l'instantané de colonie, ou `nil, message` si l'intégrateur est absent ou hors colonie.
-- Un champ secondaire illisible vaut 0, false ou liste vide.
function lecture.lire(integrateur)
  local ok, message = verifier_colonie(integrateur)
  if not ok then return nil, message end
  local lu, nom = peripheriques.appel(integrateur, "getColonyName")
  if not lu or type(nom) ~= "string" then return nil, "Colonie illisible : " .. tostring(nom) end

  local citoyens = lire(integrateur, "getCitizens", {})
  local habitants, travaux = {}, {}
  for _, citoyen in ipairs(citoyens) do
    if type(citoyen) == "table" then habitants[#habitants + 1] = habitant(citoyen) end
  end
  for _, commande in ipairs(lire(integrateur, "getWorkOrders", {})) do
    if type(commande) == "table" then travaux[#travaux + 1] = travail(commande, citoyens) end
  end

  return {
    nom = nom,
    style = lire(integrateur, "getColonyStyle", ""),
    bonheur = math.floor(lire(integrateur, "getHappiness", 0) * 10 + 0.5) / 10,
    citoyens = lire(integrateur, "getCitizenCount", 0),
    limite = lire(integrateur, "getCitizenLimit", 0),
    tombes = lire(integrateur, "getGraveCount", 0),
    visiteurs = #lire(integrateur, "getVisitors", {}),
    raid = lire(integrateur, "isUnderAttack", false) or lire(integrateur, "isUnderRaid", false),
    chantiers = lire(integrateur, "amountOfConstructionSites", 0),
    travaux = travaux,
    habitants = habitants,
  }
end

--- Renvoie les requêtes normalisées de la colonie, ou `nil, message`. Des bâtiments illisibles laissent le demandeur vide.
function lecture.requetes(integrateur)
  local ok, message = verifier_colonie(integrateur)
  if not ok then return nil, message end
  local lu, brutes = peripheriques.appel(integrateur, "getRequests")
  if not lu or type(brutes) ~= "table" then return nil, "Requêtes illisibles : " .. tostring(brutes) end
  return requetes.normaliser(brutes, lire(integrateur, "getBuildings", {}))
end

return lecture
