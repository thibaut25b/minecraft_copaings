-- La config complète les réglages du fichier par les défauts et ne détruit jamais un fichier que le joueur doit corriger.

local verif = require("verif")
local systeme = require("faux.systeme")
local config = require("commun.config")

local DEFAUTS = { periode = 30, cote = "up", exclusions = {} }

return {
  defauts_completent_les_cles_absentes_du_fichier = function()
    local etat = systeme.installer()
    etat.disque["a.cfg"] = "{ periode = 5 }"
    local reglages, message = config.charger("/a.cfg", DEFAUTS)
    verif.egal(reglages, { periode = 5, cote = "up", exclusions = {} })
    verif.egal(message, nil)
  end,

  cle_inconnue_des_defauts_est_conservee = function()
    local etat = systeme.installer()
    etat.disque["a.cfg"] = "{ periode = 5, bonus = true }"
    local reglages = config.charger("/a.cfg", DEFAUTS)
    verif.egal(reglages.bonus, true)
  end,

  fichier_absent_est_cree_avec_les_defauts = function()
    local etat = systeme.installer()
    local reglages = config.charger("/a.cfg", DEFAUTS)
    verif.egal(reglages, DEFAUTS)
    verif.egal(textutils.unserialize(etat.disque["a.cfg"]), DEFAUTS)
  end,

  fichier_corrompu_renvoie_les_defauts_et_un_message_sans_etre_ecrase = function()
    local etat = systeme.installer()
    etat.disque["a.cfg"] = "{ periode = "
    local reglages, message = config.charger("/a.cfg", DEFAUTS)
    verif.egal(reglages, DEFAUTS)
    verif.vrai(message and message:find("a.cfg", 1, true))
    verif.egal(etat.disque["a.cfg"], "{ periode = ")
    verif.egal(etat.ecritures, {})
  end,

  fichier_qui_n_est_pas_une_table_est_traite_comme_corrompu = function()
    local etat = systeme.installer()
    etat.disque["a.cfg"] = "42"
    local reglages, message = config.charger("/a.cfg", DEFAUTS)
    verif.egal(reglages, DEFAUTS)
    verif.vrai(message)
    verif.egal(etat.disque["a.cfg"], "42")
  end,

  modifier_les_reglages_rendus_ne_change_pas_les_defauts = function()
    systeme.installer()
    local reglages = config.charger("/a.cfg", DEFAUTS)
    reglages.exclusions[1] = "x"
    verif.egal(DEFAUTS.exclusions, {})
  end,

  enregistrer_puis_charger_redonne_les_reglages = function()
    systeme.installer()
    config.enregistrer("/a.cfg", { periode = 9 })
    verif.egal(config.charger("/a.cfg", DEFAUTS).periode, 9)
  end,
}
