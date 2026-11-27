-- Lecture du ME Bridge : absent = 0, illisible = pas de quantité, noms affichés, pannes sans exception.

local verif = require("verif")
local faux = require("faux.pont_me")
local lecture = require("production.lecture")
local coffre = require("faux.coffre")

local function contient(erreurs, motif)
  for _, message in ipairs(erreurs) do
    if message:find(motif, 1, true) then return true end
  end
  return false
end

local FER = { objet = "minecraft:iron_ingot", nom = "" }

return {
  la_quantite_est_le_champ_count_de_l_item = function()
    local pont, etat = faux.creer()
    etat.stock["minecraft:iron_ingot"] = 1234
    local quantites, _, erreurs = lecture.lire(pont, { FER })
    verif.egal(quantites, { ["minecraft:iron_ingot"] = 1234 })
    verif.egal(erreurs, {})
  end,

  un_objet_absent_de_l_ae_vaut_zero_sans_erreur = function()
    local pont = faux.creer()
    local quantites, noms, erreurs = lecture.lire(pont, { FER })
    verif.egal(quantites, { ["minecraft:iron_ingot"] = 0 })
    verif.egal(noms, {})
    verif.egal(erreurs, {})
  end,

  un_objet_fabricable_mais_absent_vaut_zero = function()
    local pont, etat = faux.creer()
    etat.fabricables["minecraft:iron_ingot"] = true
    local quantites = lecture.lire(pont, { FER })
    verif.egal(quantites["minecraft:iron_ingot"], 0)
  end,

  le_nom_affiche_est_lu_seulement_quand_nom_est_vide = function()
    local pont, etat = faux.creer()
    etat.stock["a:fer"], etat.stock["a:or"] = 5, 5
    etat.noms["a:fer"], etat.noms["a:or"] = "Iron Ingot", "Gold Ingot"
    local _, noms = lecture.lire(pont, { { objet = "a:fer", nom = "" }, { objet = "a:or", nom = "Or" } })
    verif.egal(noms, { ["a:fer"] = "Iron Ingot" })
  end,

  hors_reseau_une_lecture_est_illisible_avec_un_seul_message = function()
    local pont, etat = faux.creer()
    etat.connecte = false
    local quantites, _, erreurs = lecture.lire(pont, { FER, { objet = "a:b", nom = "" } })
    verif.egal(quantites, {})
    verif.egal(#erreurs, 1)
    verif.vrai(contient(erreurs, "NOT_CONNECTED"))
  end,

  un_code_d_erreur_rend_l_objet_illisible = function()
    local pont, etat = faux.creer()
    etat.codes.getItem = "ITEM_NOT_FOUND"
    local quantites, _, erreurs = lecture.lire(pont, { FER })
    verif.egal(quantites, {})
    verif.vrai(contient(erreurs, "minecraft:iron_ingot : ITEM_NOT_FOUND"))
  end,

  une_exception_du_pont_est_attrapee_et_les_autres_objets_restent_lus = function()
    local pont, etat = faux.creer()
    etat.stock["a:b"] = 7
    etat.exceptions.getItem = function(filtre) if filtre.name == "a:mauvais" then return "boum" end end
    local quantites, _, erreurs = lecture.lire(pont, { { objet = "a:mauvais", nom = "" }, { objet = "a:b", nom = "" } })
    verif.egal(quantites, { ["a:b"] = 7 })
    verif.vrai(contient(erreurs, "a:mauvais : boum"))
  end,

  un_pont_absent_donne_un_message_et_aucune_quantite = function()
    local quantites, noms, erreurs = lecture.lire(nil, { FER })
    verif.egal(quantites, {})
    verif.egal(noms, {})
    verif.egal(erreurs, { "ME Bridge absent" })
  end,

  une_quantite_non_numerique_est_illisible = function()
    local pont = { getItem = function() return { name = "a:b", count = "beaucoup" } end }
    local quantites, _, erreurs = lecture.lire(pont, { { objet = "a:b", nom = "" } })
    verif.egal(quantites, {})
    verif.vrai(contient(erreurs, "quantité illisible"))
  end,

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
}
