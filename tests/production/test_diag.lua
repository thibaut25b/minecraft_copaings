-- Diagnostic : lectures seules, recherche d'id par texte, rapport écrit, sans lever même sans pont.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local pont_me = require("faux.pont_me")

local function lancer(presents, types, arguments)
  local disque = systeme.installer()
  disque.disque["production.cfg"] = textutils.serialize({ objets = { { objet = "minecraft:iron_ingot", nom = "" } } })
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
  print = function(texte) sortie[#sortie + 1] = texte end
  assert(loadfile("projets/production/diag.lua"))(table.unpack(arguments or {}))
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
    }
  end
  return pont
end

return {
  diag_montre_l_etat_du_pont_et_lit_les_objets_configures = function()
    local disque, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" })
    verif.vrai(texte:find("isConnected = true, isOnline = true", 1, true), texte)
    verif.vrai(texte:find("minecraft:iron_ingot = 42 (Iron Ingot)", 1, true), texte)
    verif.vrai(disque.disque["production-diag.txt"] ~= nil)
  end,

  diag_avec_un_texte_cherche_dans_l_id_et_le_nom_sans_tenir_compte_de_la_casse = function()
    local _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, { "IRON" })
    verif.vrai(texte:find("minecraft:iron_ingot | Iron Ingot | 42", 1, true), texte)
    verif.vrai(texte:find("minecraft:iron_block | Block of Iron | 3", 1, true), texte)
    verif.egal(texte:find("steel", 1, true), nil)
    verif.vrai(texte:find("2 item(s)", 1, true), texte)
    _, texte = lancer({ pont_0 = pont_garni() }, { pont_0 = "me_bridge" }, { "steel" })
    verif.vrai(texte:find("mekanism:ingot_steel | Steel Ingot | 7", 1, true), texte)
  end,

  diag_sans_pont_ne_leve_pas = function()
    local disque, texte = lancer({}, {}, { "fer" })
    verif.vrai(texte:find("ME Bridge : introuvable", 1, true), texte)
    verif.vrai(disque.disque["production-diag.txt"] ~= nil)
  end,
}
