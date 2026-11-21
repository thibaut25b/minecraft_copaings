-- Données d'exemple de la colonie (aperçu hors jeu et tests) : une colonie réaliste au format de `etat`.

local exemple = {}

local HABITANTS = {
  { "Léa Fontaine", "Builder", "Working" }, { "Bastien Roux", "Builder", "Working" },
  { "Hélène Marchand", "Smelter", "Working" }, { "Marius Dupont", "Miner", "Working" },
  { "Agathe Perrin", "Farmer", "Working" }, { "Victor Laurent", "Baker", "Working" },
  { "Rose Garnier", "Cook", "Working" }, { "Jules Lefèvre", "Lumberjack", "Working" },
  { "Camille Bertin", "Fisherman", "Working" }, { "Hugo Mercier", "Guard", "Patrolling" },
  { "Inès Faure", "Courier", "Working" }, { "Louis Chevalier", "Courier", "Working" },
  { "Manon Girard", "Knight", "Patrolling" }, { "Théo Bonnet", "Archer", "Patrolling" },
  { "Chloé Lambert", "Healer", "Working" }, { "Nathan Rousseau", "Stonemason", "Working" },
  { "Zoé Blanc", "Shepherd", "Working" }, { "Arthur Guérin", "Sawmill", "Working" },
  { "Alice Morel", "Composter", "Working" }, { "Paul Fournier", "", "Idle" },
  { "Emma André", "Deliveryman", "Working" }, { "Lucas Mathieu", "", "Idle" },
  { "Jade Clément", "Researcher", "Working" },
}

-- { demandeur, libellé, quantité, livrée, statut, message }
local LIGNES = {
  { "Hélène Marchand", "Iron Ore", 32, 0, "manquant", "ni en stock ni fabricable" },
  { "Victor Laurent", "Wheat", 64, 40, "partiel", "24 encore à livrer" },
  { "Marius Dupont", "Iron Pickaxe", 1, 0, "en_fabrication", "auto-craft AE2 lancé" },
  { "Rose Garnier", "Cooked Beef", 16, 16, "livre", "" },
  { "Agathe Perrin", "Bone Meal", 32, 32, "livre", "" },
  { "Hugo Mercier", "Iron Sword", 1, 0, "ignore", "équipement laissé aux colons" },
  { "Jules Lefèvre", "Stone Axe", 1, 0, "ignore", "équipement laissé aux colons" },
  { "Chloé Lambert", "Golden Carrot", 8, 0, "manquant", "ni en stock ni fabricable" },
  { "Nathan Rousseau", "Cobblestone", 128, 128, "livre", "" },
  { "Arthur Guérin", "Oak Log", 64, 64, "livre", "" },
  { "Camille Bertin", "String", 12, 12, "livre", "" },
  { "Zoé Blanc", "Shears", 1, 0, "en_fabrication", "auto-craft AE2 lancé" },
  { "Emma André", "Bread", 24, 24, "livre", "" },
  { "Alice Morel", "Dirt", 64, 64, "livre", "" },
  { "Jade Clément", "Paper", 16, 0, "erreur", "le pont ME a refusé l'export" },
  { "Inès Faure", "Torch", 32, 32, "livre", "" },
}

-- { libellé, item, besoin, disponible, en livraison }
local MATERIAUX_LEA = {
  { "Stone Bricks", "minecraft:stone_bricks", 384, 384, 0 },
  { "Oak Planks", "minecraft:oak_planks", 256, 180, 40 },
  { "Glass Pane", "minecraft:glass_pane", 48, 12, 0 },
  { "Spruce Stairs", "minecraft:spruce_stairs", 64, 64, 0 },
  { "Oak Door", "minecraft:oak_door", 4, 0, 4 },
  { "Lantern", "minecraft:lantern", 12, 3, 0 },
  { "Cobblestone Wall", "minecraft:cobblestone_wall", 40, 40, 0 },
  { "Spruce Log", "minecraft:spruce_log", 96, 50, 16 },
  { "White Wool", "minecraft:white_wool", 6, 0, 0 },
  { "Chest", "minecraft:chest", 2, 2, 0 },
  { "Ladder", "minecraft:ladder", 18, 18, 0 },
  { "Bricks", "minecraft:bricks", 120, 64, 0 },
}

local MATERIAUX_BASTIEN = {
  { "Cobblestone", "minecraft:cobblestone", 512, 512, 0 },
  { "Oak Log", "minecraft:oak_log", 64, 64, 0 },
  { "Torch", "minecraft:torch", 24, 20, 4 },
}

local function ligne_passe(entree, numero)
  return {
    requete = { id = "r" .. numero, libelle = entree[2], demandeur = entree[1], quantite = entree[3],
      quantite_min = 1, candidats = {}, equipement = false },
    action = { type = "livrer", quantite = 0, raison = "" },
    statut = entree[5], livre = entree[4], message = entree[6],
  }
end

local function ressources(liste)
  local resultat = {}
  for i, m in ipairs(liste) do
    resultat[i] = { item = m[2], libelle = m[1], besoin = m[3], disponible = m[4], en_livraison = m[5],
      manque = math.max(0, m[3] - m[4] - m[5]) }
  end
  return resultat
end

-- Six heures de mesures, une toutes les cinq minutes, qui finissent sur l'état présent.
local function historique()
  local serie = {}
  local debut = 1767300000
  for i = 1, 72 do
    local t = i / 72
    serie[i] = {
      instant = debut + 300 * i,
      bonheur = math.floor((6.6 + 0.8 * t + 0.25 * math.sin(i / 5)) * 10 + 0.5) / 10,
      population = math.min(23, 19 + math.floor(4 * t + 0.3)),
      limite = i < 30 and 22 or 25,
      ouvertes = math.max(2, math.floor(8 + 4 * math.sin(i / 7) - 3 * t + 0.5)),
      problemes = math.max(0, math.floor(2 + 2 * math.sin(i / 4 + 1) + 0.5)),
    }
  end
  serie[#serie].bonheur, serie[#serie].ouvertes, serie[#serie].problemes = 7.4, 9, 3
  return serie
end

--- État d'exemple complet : colonie de Valbourg, 16 lignes de passe, deux constructeurs, six heures d'historique.
--- `options` : page, raid, erreurs (liste), sans_colonie, sans_requete, sans_chantier (Bastien sans ressource),
--- pagination (table), constructeur (clé), nombre (habitants et lignes multipliés pour les longues listes).
function exemple.etat(options)
  options = options or {}
  local habitants, travaux, lignes = {}, {}, {}
  for tour = 1, options.nombre or 1 do
    for i, h in ipairs(HABITANTS) do
      local n = (tour - 1) * #HABITANTS + i
      habitants[n] = {
        nom = h[1] .. (tour > 1 and " " .. tour or ""), metier = h[2], etat = h[3],
        sante = (i == 4 and 9) or (i == 13 and 14) or 20, sante_max = i == 17 and 0 or 20,
        loge = i ~= 20 and i ~= 22 and i ~= 23, employe = h[2] ~= "",
      }
    end
    if not options.sans_requete then
      for i, entree in ipairs(LIGNES) do lignes[#lignes + 1] = ligne_passe(entree, #lignes + i) end
    end
  end
  travaux = {
    { id = 1, batiment = "Tavern", type = "construction", niveau = 1, constructeur = "Léa Fontaine", pris = true },
    { id = 2, batiment = "Warehouse", type = "amélioration", niveau = 3, constructeur = "Bastien Roux", pris = true },
    { id = 3, batiment = "Bakery", type = "amélioration", niveau = 2, constructeur = "", pris = false },
    { id = 4, batiment = "Guard Tower", type = "construction", niveau = 1, constructeur = "", pris = false },
    { id = 5, batiment = "Residence", type = "réparation", niveau = 2, constructeur = "", pris = false },
  }
  local colonie = nil
  if not options.sans_colonie then
    colonie = {
      nom = "Valbourg", style = "medieval_oak", bonheur = 7.4, citoyens = #habitants, limite = 25 * (options.nombre or 1),
      tombes = 1, visiteurs = 2, raid = options.raid == true, chantiers = 2, travaux = travaux, habitants = habitants,
    }
  end
  local constructeurs = {
    { cle = "120,64,-35", pos = { x = 120, y = 64, z = -35 }, nom = "Léa Fontaine", niveau = 3,
      ressources = ressources(MATERIAUX_LEA) },
    { cle = "88,63,12", pos = { x = 88, y = 63, z = 12 }, nom = "Bastien Roux", niveau = 2,
      ressources = options.sans_chantier and {} or ressources(MATERIAUX_BASTIEN) },
  }
  return {
    heure = "21:40", page = options.page or "resume", colonie = colonie, lignes = lignes, prochaine_passe = 18,
    erreurs = options.erreurs or {}, constructeurs = constructeurs, constructeur = options.constructeur,
    lignes_chantiers = { ["120,64,-35"] = {
      ["minecraft:oak_planks"] = ligne_passe({ "Léa Fontaine", "Oak Planks", 36, 0, "en_fabrication", "" }, 90),
      ["minecraft:glass_pane"] = ligne_passe({ "Léa Fontaine", "Glass Pane", 36, 20, "partiel", "" }, 91),
      ["minecraft:white_wool"] = ligne_passe({ "Léa Fontaine", "White Wool", 6, 0, "manquant", "" }, 92),
    } },
    livraison = { ["120,64,-35"] = true },
    historique = options.sans_colonie and {} or historique(),
    pagination = options.pagination or {},
  }
end

--- Erreurs d'exemple : pont ME absent et requêtes bloquées par un objet enchanté.
exemple.ERREURS = {
  "Pont ME introuvable",
  "Requêtes : Requêtes bloquées par un objet enchanté (bogue d'Advanced Peripherals) : sers ou annule la requête "
    .. "d'équipement dans le presse-papiers",
}

return exemple
