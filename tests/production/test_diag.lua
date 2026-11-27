-- Diagnostic : lectures seules, recherche d'id par texte, rapport écrit, sans lever même sans pont.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local pont_me = require("faux.pont_me")
local coffre = require("faux.coffre")
local vers_cc = require("commun.texte").vers_cc

local SAUT = string.char(10)

local function lancer(presents, types, arguments, config)
  local disque = systeme.installer()
  disque.disque["production.cfg"] = textutils.serialize(config or { objets = { { objet = "minecraft:iron_ingot", nom = "" } } })
  peripheral = {
    find = function(type_voulu)
      for nom, objet in pairs(presents) do
        if types[nom] == type_voulu then return objet end
      end
      return nil
    end,
    wrap = function(nom) return presents[nom] end,
    getNames = function()
      local noms = {}
      for nom in pairs(presents) do noms[#noms + 1] = nom end
      table.sort(noms)
      return noms
    end,
    getType = function(nom) return types[nom] end,
  }
  local sortie = {}
  local affiche = print
  print = function(texte) sortie[#sortie + 1] = texte end
  local ok, erreur = pcall(assert(loadfile("projets/production/diag.lua")), table.unpack(arguments or {}))
  print = affiche
  if not ok then error(erreur, 0) end
  return disque, table.concat(sortie, "\n")
end

local function pont_garni()
  local pont, etat = pont_me.creer()
  etat.stock["minecraft:iron_ingot"] = 42
  etat.noms["minecraft:iron_ingot"] = "Iron Ingot"
  pont.isOnline = function() return true end
  pont.getItems = function()
    return {
      { name = "minecraft:iron_ingot", displayName = "Iron Ingot", count = 42 },
      { name = "mekanism:ingot_steel", displayName = "Steel Ingot", count = 7 },
      { name = "minecraft:iron_block", displayName = "Block of Iron", count = 3 },
      { name = "productivebees:configurable_honeycomb", nbt = "a3f1c9e2", displayName = "Diamond Comb", count = 5 },
    }
  end
  return pont
end

return {
  diag_montre_l_etat_du_pont_et_les_cles_suivies = function()
    local disque, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" })
    verif.vrai(texte:find("isConnected = true, isOnline = true", 1, true), texte)
    verif.vrai(texte:find("minecraft:iron_ingot (toutes variantes)", 1, true), texte)
    verif.vrai(disque.disque["production-diag.txt"] ~= nil)
  end,

  diag_avec_un_texte_cherche_dans_l_id_et_le_nom_et_montre_id_nbt_nom_quantite = function()
    local _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, { "IRON" })
    verif.vrai(texte:find("minecraft:iron_ingot | - | Iron Ingot | 42", 1, true), texte)
    verif.vrai(texte:find("minecraft:iron_block | - | Block of Iron | 3", 1, true), texte)
    verif.egal(texte:find("steel", 1, true), nil)
    verif.vrai(texte:find("2 item(s)", 1, true), texte)
    _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, { "diamond comb" })
    verif.vrai(texte:find("productivebees:configurable_honeycomb | a3f1c9e2 | Diamond Comb | 5", 1, true), texte)
  end,

  diag_tout_chronometre_get_items_sans_collectgarbage_absent_de_cc = function()
    local ramasse = collectgarbage
    collectgarbage = nil
    local ok, disque, texte = pcall(lancer, { pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, { "tout" })
    collectgarbage = ramasse
    verif.vrai(ok, tostring(disque))
    verif.vrai(texte:find("getItems%(%) : %d+ ms, 4 entr.-, 4 types"), texte)
    verif.vrai(disque.disque["production-diag.txt"]:find("chrono", 1, true))
  end,

  diag_sans_pont_ne_leve_pas = function()
    local disque, texte = lancer({}, {}, { "fer" })
    verif.vrai(texte:find("ME Bridge : introuvable", 1, true), texte)
    verif.vrai(texte:find("ME Bridge absent", 1, true), texte)
    verif.vrai(disque.disque["production-diag.txt"] ~= nil)
  end,

  diag_montre_les_cles_du_coffre_modele = function()
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [1] = { name = "minecraft:iron_ingot", count = 1 },
      [4] = { name = "minecraft:gold_ingot", count = 2 } })
    local _, texte = lancer({ pont_0 = pont_garni(), chest_0 = c }, { pont_0 = "me_bridge", chest_0 = "minecraft:chest" },
      nil, { coffre = "chest_0" })
    verif.vrai(texte:find(vers_cc("Coffre modèle chest_0 :" .. SAUT .. "  minecraft:iron_ingot|" .. SAUT
      .. "  minecraft:gold_ingot|"), 1, true),
      texte)
  end,

  diag_signale_un_coffre_absent_ou_non_configure = function()
    local _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, nil, { coffre = "chest_9" })
    verif.vrai(texte:find(vers_cc("Coffre modèle absent : chest_9"), 1, true), texte)
    _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" })
    verif.vrai(texte:find(vers_cc("Coffre modèle : non configuré"), 1, true), texte)
  end,
}
