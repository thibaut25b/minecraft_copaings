-- Lecture de la colonie par le Colony Integrator : instantané, requêtes normalisées et huttes de constructeur.

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

-- Le métier d'un citoyen est porté par son bâtiment de travail (`workBuilding.job`), absent s'il est sans emploi.
local function job_de(citoyen)
  return type(citoyen.workBuilding) == "table" and citoyen.workBuilding.job or nil
end

local function metier(job)
  if type(job) ~= "string" then return "" end
  local nom = job:match(":(.+)$") or job
  return nom:sub(1, 1):upper() .. nom:sub(2)
end

local function habitant(citoyen)
  return {
    nom = citoyen.name or "",
    metier = metier(job_de(citoyen)),
    etat = citoyen.state or "",
    sante = tonumber(citoyen.health) or 0,         -- 0 : entité non chargée
    sante_max = tonumber(citoyen.maxHealth) or 0,
    loge = citoyen.homeBuilding ~= nil,
    employe = job_de(citoyen) ~= nil,
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

-- Advanced Peripherals 0.8.2a lève cette erreur dans `getRequests` dès qu'une requête ouverte porte un objet enchanté.
local ERREUR_OBJET_ENCHANTE = "is not valid in current registry set"
local AIDE_OBJET_ENCHANTE = "Requêtes bloquées par un objet enchanté (bogue d'Advanced Peripherals) : "
  .. "sers ou annule la requête d'équipement dans le presse-papiers"

local function message_requetes_illisibles(erreur)
  local texte = tostring(erreur)
  if texte:find(ERREUR_OBJET_ENCHANTE, 1, true) then return AIDE_OBJET_ENCHANTE end
  return "Requêtes illisibles : " .. texte
end

--- Renvoie les requêtes normalisées de la colonie, ou `nil, message`. Des bâtiments illisibles laissent le demandeur vide.
function lecture.requetes(integrateur)
  local ok, message = verifier_colonie(integrateur)
  if not ok then return nil, message end
  local lu, brutes = peripheriques.appel(integrateur, "getRequests")
  if not lu or type(brutes) ~= "table" then return nil, message_requetes_illisibles(brutes) end
  return requetes.normaliser(brutes, lire(integrateur, "getBuildings", {}))
end

-- Type de schéma (`getBuildings()[i].type`) d'une hutte de constructeur.
local TYPE_CONSTRUCTEUR = "builder"

local function nombre(valeur)
  return math.max(0, tonumber(valeur) or 0)
end

local function ressource(brute)
  local item = type(brute.item) == "table" and brute.item or {}
  if type(item.name) ~= "string" then return nil end
  local besoin, disponible, en_livraison = nombre(brute.needs), nombre(brute.available), nombre(brute.delivering)
  return {
    item = item.name,
    libelle = brute.displayName or item.displayName or item.name,
    besoin = besoin,
    disponible = disponible,
    en_livraison = en_livraison,
    manque = math.max(0, besoin - disponible - en_livraison),
  }
end

local function lire_ressources(integrateur, pos)
  local ok, brutes = peripheriques.appel(integrateur, "getBuilderResources", pos)
  if not ok then return {}, "Ressources illisibles : " .. tostring(brutes) end
  if type(brutes) ~= "table" then return {}, "Ressources illisibles : hutte introuvable à cette position" end
  local liste = {}
  for _, brute in ipairs(brutes) do
    local lue = type(brute) == "table" and ressource(brute) or nil
    if lue then liste[#liste + 1] = lue end
  end
  return liste
end

local function nom_affecte(batiment)
  for _, citoyen in ipairs(type(batiment.citizens) == "table" and batiment.citizens or {}) do
    if type(citoyen) == "table" and type(citoyen.name) == "string" and citoyen.name ~= "" then return citoyen.name end
  end
  return nil
end

--- Renvoie les huttes de constructeur triées par clé de position, ou `nil, message`. Chacune :
-- `{ cle, pos, nom, niveau, ressources = { { item, libelle, besoin, disponible, en_livraison, manque } }, erreur }`.
-- Une hutte aux ressources illisibles garde une liste vide et `erreur` ; les autres sont lues quand même.
function lecture.constructeurs(integrateur)
  local ok, message = verifier_colonie(integrateur)
  if not ok then return nil, message end
  local lu, batiments = peripheriques.appel(integrateur, "getBuildings")
  if not lu or type(batiments) ~= "table" then return nil, "Bâtiments illisibles : " .. tostring(batiments) end
  local liste = {}
  for _, batiment in ipairs(batiments) do
    local cle = type(batiment) == "table" and batiment.type == TYPE_CONSTRUCTEUR and requetes.cle_position(batiment.pos)
    if cle and cle ~= "" then liste[#liste + 1] = { cle = cle, batiment = batiment } end
  end
  table.sort(liste, function(a, b) return a.cle < b.cle end)
  for numero, entree in ipairs(liste) do
    local batiment = entree.batiment
    local ressources, erreur = lire_ressources(integrateur, batiment.pos)
    liste[numero] = {
      cle = entree.cle,
      pos = batiment.pos,
      nom = nom_affecte(batiment) or ("Constructeur " .. numero),
      niveau = tonumber(batiment.level) or 0,
      ressources = ressources,
      erreur = erreur,
    }
  end
  return liste
end

return lecture
