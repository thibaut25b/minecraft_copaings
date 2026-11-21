-- L'appel protégé ne lève jamais : c'est lui qui garde la boucle principale en vie quand un périphérique disparaît.

local verif = require("verif")
local peripheriques = require("commun.peripheriques")

return {
  appel_reussi_renvoie_true_et_les_resultats = function()
    local ok, a, b = peripheriques.appel({ lire = function(x) return x, x * 2 end }, "lire", 21)
    verif.egal({ ok, a, b }, { true, 21, 42 })
  end,

  objet_absent_renvoie_false_sans_lever = function()
    local ok, message = peripheriques.appel(nil, "lire")
    verif.egal(ok, false)
    verif.vrai(message:find("absent", 1, true))
  end,

  methode_inconnue_renvoie_false_sans_lever = function()
    local ok, message = peripheriques.appel({}, "lire")
    verif.egal(ok, false)
    verif.vrai(message:find("lire", 1, true))
  end,

  erreur_du_peripherique_renvoie_false_et_son_message = function()
    local ok, message = peripheriques.appel({ lire = function() error("chunk déchargé") end }, "lire")
    verif.egal(ok, false)
    verif.vrai(tostring(message):find("chunk déchargé", 1, true))
  end,

  liste_des_fichiers_du_depot_est_exposee_aux_tests = function()
    verif.vrai(type(FICHIERS_DU_DEPOT) == "table" and #FICHIERS_DU_DEPOT > 0)
  end,
}
