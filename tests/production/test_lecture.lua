-- Lecture du ME Bridge (getItems de tout le réseau ou par id) et du coffre modèle, pannes sans exception.

local verif = require("verif")
local faux = require("faux.pont_me")
local lecture = require("production.lecture")
local coffre = require("faux.coffre")

return {
  le_contenu_du_coffre_est_le_resultat_de_list = function()
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [3] = { name = "a:b", count = 5 } })
    local contenu, erreur = lecture.lire_coffre(c, "chest_0")
    verif.egal(contenu, { [3] = { name = "a:b", count = 5 } })
    verif.egal(erreur, nil)
  end,

  un_coffre_absent_donne_un_message_et_aucun_contenu = function()
    local contenu, erreur = lecture.lire_coffre(nil, "chest_9")
    verif.egal(contenu, nil)
    verif.egal(erreur, "Coffre modèle absent : chest_9")
  end,

  un_coffre_en_panne_donne_un_message_sans_lever = function()
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27)
    c.panne = "chunk déchargé"
    local contenu, erreur = lecture.lire_coffre(c, "chest_0")
    verif.egal(contenu, nil)
    verif.vrai(erreur:find("chunk déchargé", 1, true), erreur)
  end,

  lire_tout_rend_une_entree_par_variante = function()
    local pont, etat = faux.creer()
    etat.stock["a:b"] = 3
    etat.variantes["a:b"] = { { nbt = "x", count = 4 } }
    etat.stock["a:c"] = 1
    local items, erreur = lecture.lire_tout(pont)
    verif.egal(erreur, nil)
    verif.egal(#items, 3)
    verif.egal({ items[1].name, items[1].nbt, items[1].count }, { "a:b", nil, 3 })
    verif.egal({ items[2].name, items[2].nbt, items[2].count }, { "a:b", "x", 4 })
    verif.egal(faux.appels_de(etat, "getItems"), { {} })
  end,

  lire_ids_fait_un_get_items_par_id_et_met_les_listes_bout_a_bout = function()
    local pont, etat = faux.creer()
    etat.stock["a:b"], etat.stock["a:c"], etat.stock["a:d"] = 1, 2, 3
    etat.variantes["a:b"] = { { nbt = "x", count = 4 } }
    local items = lecture.lire_ids(pont, { "a:b", "a:d" })
    verif.egal(#items, 3)
    verif.egal(items[3].name, "a:d")
    verif.egal(faux.appels_de(etat, "getItems"), { { { name = "a:b" } }, { { name = "a:d" } } })
  end,

  lire_ids_echoue_en_entier_si_un_id_echoue = function()
    local pont, etat = faux.creer()
    etat.stock["a:b"] = 1
    etat.exceptions.getItems = function(filtre) if filtre.name == "a:mauvais" then return "boum" end end
    local items, erreur = lecture.lire_ids(pont, { "a:b", "a:mauvais" })
    verif.egal(items, nil)
    verif.egal(erreur, "a:mauvais : boum")
  end,

  hors_reseau_lire_tout_et_lire_ids_donnent_un_seul_message = function()
    local pont, etat = faux.creer()
    etat.connecte = false
    verif.egal({ lecture.lire_tout(pont) }, { nil, "ME Bridge hors réseau (NOT_CONNECTED)" })
    verif.egal({ lecture.lire_ids(pont, { "a:b", "a:c" }) }, { nil, "ME Bridge hors réseau (NOT_CONNECTED)" })
  end,

  un_pont_absent_ou_une_liste_illisible_donne_nil_et_un_message = function()
    verif.egal({ lecture.lire_tout(nil) }, { nil, "ME Bridge absent" })
    verif.egal({ lecture.lire_ids(nil, { "a:b" }) }, { nil, "ME Bridge absent" })
    verif.egal({ lecture.lire_tout({ getItems = function() return "rien" end }) }, { nil, "getItems : liste illisible" })
    verif.egal({ lecture.lire_tout({ getItems = function() return nil, "BIZARRE" end }) }, { nil, "getItems : BIZARRE" })
  end,

  get_items_filtre_par_nbt_hash_et_vide_cible_la_variante_sans_composants = function()
    local pont, etat = faux.creer()
    etat.stock["a:b"] = 3
    etat.variantes["a:b"] = { { nbt = "x", count = 4 } }
    verif.egal(#pont.getItems({ name = "a:b", nbtHash = "" }), 1)
    verif.egal(pont.getItems({ name = "a:b", nbtHash = "x" })[1].count, 4)
    verif.egal(pont.getItem({ name = "a:b", nbtHash = "x" }).count, 4)
  end,

  le_nbt_des_piles_du_coffre_est_rendu = function()
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [1] = { name = "a:b", count = 5, nbt = "x" } })
    verif.egal(lecture.lire_coffre(c, "chest_0"), { [1] = { name = "a:b", count = 5, nbt = "x" } })
  end,
}
