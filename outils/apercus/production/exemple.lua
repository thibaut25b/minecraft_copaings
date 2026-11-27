-- Données réalistes de la production pour l'aperçu et les tests de vues : séries bâties par le vrai `debit.noter`.

local debit = require("production.debit")

local exemple = {}

local PERIODE = 2
local DUREE = 3600

-- { id, nom de config, stock de départ, pente en items/s (variable : a + b * sin) }
local OBJETS = {
  { "minecraft:iron_ingot", "", 12000, 4.0 },
  { "minecraft:copper_ingot", "Copper Ingot", 8000, -1.5 },
  { "minecraft:gold_ingot", "", 900, 0.2 },
  { "minecraft:redstone", "", 30000, -0.4 },
  { "minecraft:diamond", "", 64, 0 },
  { "mekanism:ingot_osmium", "", 5000, 2.2 },
}

local NOMS = { ["minecraft:iron_ingot"] = "Iron Ingot", ["minecraft:gold_ingot"] = "Gold Ingot",
  ["minecraft:redstone"] = "Redstone Dust", ["minecraft:diamond"] = "Diamond", ["mekanism:ingot_osmium"] = "Osmium Ingot" }

--- État du tableau de bord. `options` : erreurs, objets_en_plus (nombre d'objets ajoutés, pour la pagination),
--- pagination, unite, selection, vide (aucun objet suivi).
function exemple.etat(options)
  options = options or {}
  local objets, series, departs, quantites = {}, {}, {}, {}
  for _, o in ipairs(options.vide and {} or OBJETS) do objets[#objets + 1] = { objet = o[1], nom = o[2] } end
  for i = 1, options.objets_en_plus or 0 do
    objets[#objets + 1] = { objet = "minecraft:objet_" .. i, nom = "Objet annexe " .. i }
  end
  local base = { }
  for _, o in ipairs(OBJETS) do base[o[1]] = o end
  for i, entree in ipairs(objets) do
    local o = base[entree.objet] or { entree.objet, "", 1000 * i, 0.5 }
    for t = 0, DUREE, PERIODE do
      local pente = o[4] * (1 + 0.6 * math.sin(t / 150 + i))
      o.courant = (o.courant or o[3]) + pente * PERIODE
      debit.noter(series, { [entree.objet] = math.floor(o.courant) }, t, DUREE)
      debit.noter_departs(departs, { [entree.objet] = math.floor(o.courant) }, t)
    end
    quantites[entree.objet] = series[entree.objet][#series[entree.objet]].n
    o.courant = nil
  end
  return {
    heure = "14:32", erreurs = options.erreurs or {}, prochaine_mesure = 1, pagination = options.pagination or {},
    unite = options.unite or "min", selection = options.selection, objets = objets, noms = NOMS,
    quantites = quantites, series = series, departs = departs, periode = PERIODE, duree_graphe = 600,
  }
end

return exemple
