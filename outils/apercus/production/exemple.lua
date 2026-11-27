-- Données réalistes de la production pour l'aperçu et les tests de vues : une heure de mesures notée par le vrai `flux`.

local flux = require("production.flux")
local inventaire = require("production.inventaire")
local classement = require("production.classement")
local suivi = require("production.suivi")

local exemple = {}

local COMB = "productivebees:configurable_honeycomb"

--- Instant de la dernière mesure de l'exemple (secondes).
exemple.DEBUT = 1764000000
exemple.PERIODE = 10
exemple.DUREE = 3600
exemple.INSTANT = exemple.DEBUT + exemple.DUREE

--- Clé de l'objet au pic isolé (une livraison d'un coup, cinq minutes avant la fin).
exemple.PIC = "ae2:certus_quartz_crystal|"

-- { id, nbt, nom affiché, stock de départ, production/s, consommation/s }
local OBJETS = {
  { "minecraft:iron_ingot", nil, "Iron Ingot", 12000, 4.0, 1.2 },
  { "mekanism:ingot_osmium", nil, "Osmium Ingot", 5000, 2.2, 0.4 },
  { "ae2:certus_quartz_crystal", nil, "Certus Quartz Crystal", 2500, 1.5, 0.3 },
  { "minecraft:copper_ingot", nil, "Copper Ingot", 3000, 1.0, 1.6 },
  { "minecraft:redstone", nil, "Redstone Dust", 30000, 0, 0.4 },
  { COMB, "a3f1c9e2", "Diamond Comb", 340, 0.3, 0.1 },
  { COMB, "7be04d51", "Allthemodium Comb", 120, 0.05, 0 },
  { "minecraft:coal", nil, "Coal", 600, 0.5, 0.6 },
  { "minecraft:gold_ingot", nil, "Gold Ingot", 900, 0.2, 0 },
  { "allthemodium:allthemodium_ingot", nil, "Allthemodium Ingot", 180, 0.01, 0 },
  { "minecraft:diamond", nil, "Diamond", 64, 0, 0 },
  { "minecraft:cobblestone", nil, "Cobblestone", 184320, 0, 0 },
  { "minecraft:oak_log", nil, "Oak Log", 2304, 0, 0 },
  { "minecraft:glass", nil, "Glass", 960, 0, 0 },
  { "minecraft:sand", nil, "Sand", 7488, 0, 0 },
  { "mekanism:basic_control_circuit", nil, "Basic Control Circuit", 212, 0, 0 },
  { "ae2:fluix_crystal", nil, "Fluix Crystal", 1450, 0, 0 },
  { "minecraft:netherite_ingot", nil, "Netherite Ingot", 37, 0, 0 },
}

local REGLAGES = { seuil_coupure = 0.2, delai_aller_retour = 0, exclure = {}, debit_mini = 0, delai_alerte = 3600 }

-- Mesures entre deux prélèvements d'un objet (l'autocraft consomme par lots).
local LOT_CONSO = 12

-- Flux d'une heure : production continue, consommation par lots, un pic isolé.
local function simuler(objets, duree, avec_conso)
  local etat, stocks, noms = flux.nouveau(), {}, {}
  local mesures = math.floor(duree / exemple.PERIODE)
  for k = 0, mesures do
    local instantane = {}
    for i, o in ipairs(objets) do
      local cle = inventaire.cle(o[1], o[2])
      noms[cle] = o[3]
      local stock = stocks[cle] or o[4]
      if k > 0 then
        stock = stock + o[5] * exemple.PERIODE * (1 + 0.4 * math.sin(k / 9 + i) + 0.15 * math.sin(k * 1.7 + i))
        if avec_conso and k % LOT_CONSO == i % LOT_CONSO then
          stock = stock - o[6] * LOT_CONSO * exemple.PERIODE * (1 + 0.3 * math.cos(k / 7 + i))
        end
        if cle == exemple.PIC and k == mesures - 30 then stock = stock + 4000 end
      end
      stocks[cle] = math.max(0, math.floor(stock))
      if stocks[cle] > 0 then instantane[cle] = stocks[cle] end
    end
    flux.noter(etat, instantane, exemple.INSTANT - (mesures - k) * exemple.PERIODE, REGLAGES)
  end
  flux.nommer(etat, noms)
  return etat
end

--- État du tableau de bord. `options` : onglet, unite, fenetre, sens, selection, pagination, erreurs, tout (true par
--- défaut), consommation (true par défaut), vide (aucun objet ni liste suivie), phase ("attente", "base"),
--- objets_en_plus (nombre d'objets ajoutés), duree (secondes d'historique, 3600 par défaut).
function exemple.etat(options)
  options = options or {}
  local tout = options.tout ~= false
  local avec_conso = options.consommation ~= false
  local objets = {}
  for _, o in ipairs(options.vide and {} or OBJETS) do objets[#objets + 1] = o end
  for i = 1, options.objets_en_plus or 0 do
    objets[#objets + 1] = { "extra:item_" .. i, nil, "Extra Item " .. i, 500 + 37 * i, 0.1 * (i % 5), 0.05 * (i % 3) }
  end
  local etat_flux = simuler(objets, options.duree or exemple.DUREE, avec_conso)
  local liste = options.vide and {} or suivi.fusionner({ { objet = "minecraft:iron_ingot", nom = "" },
    { objet = COMB, nom = "" } }, { [1] = { name = "minecraft:coal", count = 1 }, [2] = { name = "minecraft:copper_ingot",
    count = 1 } })
  local ecran = {
    heure = "14:32", erreurs = options.erreurs or {}, prochaine_mesure = 4, pagination = options.pagination or {},
    options = { tout = tout and not options.vide, suivis = not options.vide, consommation = avec_conso,
      delai_alerte = REGLAGES.delai_alerte },
    onglet = options.onglet or (tout and not options.vide and "tout" or "suivis"), unite = options.unite or "min",
    fenetre = options.fenetre or 600, sens = options.sens or "prod", selection = options.selection,
    phase = options.phase or "suivi",
  }
  if ecran.phase == "attente" then return ecran end
  ecran.flux, ecran.instant = etat_flux, exemple.INSTANT
  local reglages = { consommation = avec_conso, exclure = {}, debit_mini = 0, delai_alerte = REGLAGES.delai_alerte }
  ecran.classement = classement.ecran(etat_flux, exemple.INSTANT, { fenetre = ecran.fenetre, sens = ecran.sens,
    onglet = ecran.onglet, suivis = liste, tout = ecran.options.tout }, reglages)
  return ecran
end

return exemple
