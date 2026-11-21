-- Action sur les relais : valeur selon signal_coupe, relais absent, faux relais sans setOutput, panne.

local verif = require("verif")
local faux = require("faux.create")
local action = require("usine.action")

local function ligne(nom, relais, cote, signal_coupe)
  return { nom = nom, relais = relais, cote = cote, signal_coupe = signal_coupe }
end

local function brancher(presents)
  peripheral = { wrap = function(nom) return presents[nom] end }
end

return {
  signal_coupe_vrai_sortie_active_a_l_arret = function()
    local l = ligne("A", "r", "back", true)
    verif.egal(action.valeur(l, false), true)
    verif.egal(action.valeur(l, true), false)
  end,

  signal_coupe_faux_sortie_active_en_marche = function()
    local l = ligne("A", "r", "back", false)
    verif.egal(action.valeur(l, true), true)
    verif.egal(action.valeur(l, false), false)
  end,

  chaque_ligne_est_posee_sur_son_relais_et_son_cote = function()
    local r = faux.relais()
    brancher({ r = r })
    local erreurs = action.appliquer({ ligne("A", "r", "back", true), ligne("B", "r", "left", false) },
      { { marche = true }, { marche = true } })
    verif.egal(erreurs, {})
    verif.egal(r.sorties, { back = false, left = true })
  end,

  relais_absent_signale_sa_ligne_et_les_autres_sont_servies = function()
    local r = faux.relais()
    brancher({ r = r })
    local erreurs = action.appliquer({ ligne("A", "absent", "back", true), ligne("B", "r", "top", true) },
      { { marche = true }, { marche = false } })
    verif.egal(erreurs, { "Ligne A : relais absent introuvable" })
    verif.egal(r.sorties.top, true)
  end,

  relais_sans_setOutput_est_signale_comme_pas_un_relais_de_computercraft = function()
    brancher({ energie = { getThroughput = function() return 0 end } })
    local erreurs = action.appliquer({ ligne("A", "energie", "back", true) }, { { marche = true } })
    verif.egal(erreurs, { "Ligne A : relais energie : pas un relais redstone de ComputerCraft" })
  end,

  relais_en_panne_donne_un_message_sans_lever = function()
    local r = faux.relais()
    r.panne = "câble coupé"
    brancher({ r = r })
    local erreurs = action.appliquer({ ligne("A", "r", "back", true) }, { { marche = false } })
    verif.vrai(erreurs[1]:find("câble coupé", 1, true), erreurs[1])
  end,
}
