-- Données réalistes de l'usine pour l'aperçu et les tests de vues : état bâti par la vraie régulation.

local regulation = require("usine.regulation")

local exemple = {}

local CAPACITE = 16384
local SEUILS = { delestage = 0.95, reprise = 0.80 }
local COTES = { "top", "bottom", "left", "right", "front", "back" }

local LIGNES = {
  { "Broyeurs à minerai", "create:crushed_raw_iron", 512, 4096, 1 },
  { "Mélange de laiton", "create:brass_ingot", 256, 2048, 2 },
  { "Presse à plaques", "create:iron_sheet", 500, 2000, 3 },
  { "Four à briques", "minecraft:brick", 200, 1000, 4 },
  { "Chaîne mécanismes", "create:precision_mechanism", 16, 64, 2 },
  { "Ligne de béton", "minecraft:gray_concrete", 1000, 4000, 5 },
}

local STOCK = {
  ["create:crushed_raw_iron"] = 2304, ["create:brass_ingot"] = 180, ["create:iron_sheet"] = 2000,
  ["minecraft:brick"] = 400, ["create:precision_mechanism"] = 18, ["minecraft:gray_concrete"] = 1500,
  ["create:track"] = 236, ["create:belt_connector"] = 96, ["create:zinc_ingot"] = 64, ["create:cogwheel"] = 1480,
}

local STOCKS = {
  { nom = "Plaques de fer", objet = "create:iron_sheet", seuil = 1000 },
  { nom = "Lingots de laiton", objet = "create:brass_ingot", seuil = 256 },
  { nom = "Rails", objet = "create:track", seuil = 200 },
  { nom = "Courroies", objet = "create:belt_connector", seuil = 50 },
  { nom = "Lingots de zinc", objet = "create:zinc_ingot", seuil = 256 },
  { nom = "Engrenages", objet = "create:cogwheel", seuil = 256 },
}

-- 120 mesures : montée au-delà du délestage puis retour à 82 %.
local function courbe(points)
  local valeurs = {}
  for i = 1, points do
    local t = (i - 1) / (points - 1)
    local bosse = math.exp(-((t - 0.55) / 0.12) ^ 2)
    valeurs[i] = CAPACITE * (0.70 + 0.12 * t + 0.20 * bosse + 0.02 * math.sin(i * 0.7))
  end
  valeurs[points] = 0.82 * CAPACITE
  return valeurs
end

--- État du tableau de bord. `options` : panne_ticker (stock inconnu), erreurs, deux_reseaux, lignes_en_plus (nombre
--- de lignes ajoutées, pour la pagination), pagination.
function exemple.etat(options)
  options = options or {}
  local reseaux = { { nom = "Principal" } }
  if options.deux_reseaux then
    reseaux = { { nom = "Nord", stressometre = "s0", speedometre = "v0" }, { nom = "Sud", stressometre = "s1",
      speedometre = false } }
  end
  local lignes = {}
  for i, l in ipairs(LIGNES) do
    lignes[i] = { nom = l[1], produit = l[2], mini = l[3], maxi = l[4], priorite = l[5], relais = "redstone_relay_0",
      cote = COTES[i], signal_coupe = true,
      reseau = reseaux[1].nom }
  end
  for i = 1, options.lignes_en_plus or 0 do
    lignes[#lignes + 1] = { nom = "Ligne annexe " .. i, produit = "create:andesite_alloy", mini = 100, maxi = 900,
      priorite = 6, relais = "redstone_relay_1", cote = "top", signal_coupe = true, reseau = reseaux[1].nom }
  end
  local memoire = regulation.memoire(lignes)
  memoire["Four à briques"].mode = "arret"
  local stock = STOCK
  local mesure = { stress = 0.82 * CAPACITE, capacite = CAPACITE, vitesse = 128 }
  memoire = regulation.passer(lignes, memoire, { stock = stock, reseaux = { [reseaux[1].nom] =
    { stress = 0.97 * CAPACITE, capacite = CAPACITE } } }, SEUILS)
  local mesures = { [reseaux[1].nom] = mesure }
  if options.deux_reseaux then mesures.Sud = { stress = 2100, capacite = 8192 } end
  local lues = { stock = not options.panne_ticker and stock or nil, reseaux = mesures }
  local sorties
  memoire, sorties = regulation.passer(lignes, memoire, lues, SEUILS)
  return {
    heure = "14:32", erreurs = options.erreurs or {}, prochaine_passe = 3, pagination = options.pagination or {},
    reseau = 1, lignes = lignes, reseaux = reseaux, stocks = STOCKS, periode = 5, seuils = SEUILS, memoire = memoire,
    sorties = sorties, mesures = mesures, courbes = { [reseaux[1].nom] = courbe(120) }, stock = lues.stock,
  }
end

return exemple
