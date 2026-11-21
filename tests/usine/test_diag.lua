-- Diagnostic : lectures seules (jamais de setOutput), rapport écrit, sans lever même sans périphérique.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local faux = require("faux.create")

local function lancer(presents, types)
  local disque = systeme.installer()
  disque.disque["usine.cfg"] = textutils.serialize({ lignes = { { nom = "A", relais = "relais_0", cote = "back" },
    { nom = "B", relais = "absent", cote = "top" } } })
  peripheral = {
    find = function() return nil end,
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
  assert(loadfile("projets/usine/diag.lua"))()
  return disque, table.concat(sortie, "\n")
end

return {
  diag_lit_tout_sans_jamais_poser_de_sortie = function()
    local relais = faux.relais()
    relais.sorties.back = true
    local disque, texte = lancer({
      relais_0 = relais, stress_0 = faux.stressometre(10, 20), ticker_0 = faux.ticker({ ["create:cogwheel"] = 7 }),
    }, { relais_0 = "redstone_relay", stress_0 = "Create_Stressometer", ticker_0 = "Create_StockTicker" })
    verif.egal(relais.ordres, 0)
    verif.vrai(texte:find("getOutput = true", 1, true), texte)
    verif.vrai(texte:find("getStress = 10", 1, true), texte)
    verif.vrai(texte:find("create:cogwheel = 7", 1, true), texte)
    verif.vrai(texte:find("introuvable", 1, true), texte)
    verif.vrai(disque.disque["usine-diag.txt"] ~= nil)
  end,

  diag_sans_peripherique_ne_leve_pas = function()
    local disque, texte = lancer({}, {})
    verif.vrai(texte:find("Stock Ticker : aucun", 1, true), texte)
    verif.vrai(disque.disque["usine-diag.txt"] ~= nil)
  end,
}
