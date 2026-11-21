-- Fourniture contre un faux pont ME : comptabilité du stock, mémoire des livraisons et des fabrications, pannes.

local verif = require("verif")
local fourniture = require("colonie.fourniture")
local faux_pont = require("faux.pont_me")

local PLANCHE = "minecraft:oak_planks"
local PIERRE = "minecraft:stone"

local function regles(modifs)
  local r = { cible_export = "minecraft:chest_7", fabriquer = true, ignorer_equipement = true, exclusions = {} }
  for cle, valeur in pairs(modifs or {}) do r[cle] = valeur end
  return r
end

local function requete(id, quantite, quantite_min, candidats)
  return { id = id, libelle = id, demandeur = "", quantite = quantite, quantite_min = quantite_min or quantite,
           candidats = candidats or { PLANCHE }, equipement = false }
end

local function preparer(modifs)
  local pont, etat = faux_pont.creer()
  return fourniture.creer(pont, regles(modifs)), etat
end

local function contient(texte, morceau)
  verif.vrai(type(texte) == "string" and texte:find(morceau, 1, true), "« " .. tostring(texte) .. " » sans « " .. morceau .. " »")
end

return {
  deux_requetes_du_meme_item_se_partagent_le_stock_de_la_passe = function()
    local objet, etat = preparer({ fabriquer = false })
    etat.stock[PLANCHE] = 64
    local lignes = objet.passer({ requete("a", 64), requete("b", 64) })
    verif.egal({ lignes[1].statut, lignes[1].livre }, { "livre", 64 })
    verif.egal({ lignes[2].statut, lignes[2].action.type }, { "manquant", "manquant" })
    verif.egal(etat.livre[PLANCHE], 64)
  end,

  la_seconde_requete_voit_le_stock_restant_apres_export = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 40
    local lignes = objet.passer({ requete("a", 30), requete("b", 16, 8) })
    verif.egal({ lignes[1].livre, lignes[2].livre, lignes[2].statut }, { 30, 10, "livre" })
  end,

  export_transmet_la_cible_telle_quelle_puis_le_filtre = function()
    local objet, etat = preparer({ cible_export = "@up" })
    etat.stock[PLANCHE] = 64
    objet.passer({ requete("a", 16) })
    verif.egal(faux_pont.appels_de(etat, "exportItem"), { { "@up", { name = PLANCHE, count = 16 } } })
  end,

  requete_servie_n_est_pas_reexportee_a_la_passe_suivante = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    objet.passer({ requete("a", 16) })
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal(#faux_pont.appels_de(etat, "exportItem"), 1)
    verif.egal({ lignes[1].statut, lignes[1].livre, lignes[1].message }, { "livre", 16, "en attente du coursier" })
    verif.egal(etat.stock[PLANCHE], 48)
  end,

  requete_partielle_reprend_le_reste_a_la_passe_suivante_puis_n_est_plus_exportee = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.capacite = 5
    local premiere = objet.passer({ requete("a", 16, 8) })
    verif.egal({ premiere[1].statut, premiere[1].livre }, { "partiel", 5 })
    contient(premiere[1].message, "5 sur 8")
    etat.capacite = 100
    local seconde = objet.passer({ requete("a", 16, 8) })
    verif.egal({ seconde[1].statut, seconde[1].livre }, { "livre", 16 })
    local troisieme = objet.passer({ requete("a", 16, 8) })
    verif.egal({ troisieme[1].statut, troisieme[1].livre }, { "livre", 16 })
    verif.egal(faux_pont.appels_de(etat, "exportItem"), {
      { "minecraft:chest_7", { name = PLANCHE, count = 16 } },
      { "minecraft:chest_7", { name = PLANCHE, count = 11 } },
    })
  end,

  cumul_d_une_requete_partielle_ne_depasse_jamais_la_quantite = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.capacite = 2
    objet.passer({ requete("a", 10, 6) })
    etat.capacite = 3
    verif.egal(objet.passer({ requete("a", 10, 6) })[1].livre, 5)
    verif.egal(objet.passer({ requete("a", 10, 6) })[1].livre, 5)
    etat.capacite = nil
    local lignes = objet.passer({ requete("a", 10, 6) })
    verif.egal({ lignes[1].statut, lignes[1].livre, etat.livre[PLANCHE] }, { "livre", 10, 10 })
  end,

  requete_partielle_sans_stock_fabrique_le_reste_en_gardant_le_cumul = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.capacite = 5
    objet.passer({ requete("a", 16, 8) })
    etat.stock[PLANCHE] = 0
    etat.fabricables[PLANCHE] = true
    local lignes = objet.passer({ requete("a", 16, 8) })
    verif.egal({ lignes[1].statut, lignes[1].livre }, { "en_fabrication", 5 })
    verif.egal(faux_pont.appels_de(etat, "craftItem"), { { { name = PLANCHE, count = 11 } } })
  end,

  id_disparu_est_oublie_et_peut_etre_resservi = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    objet.passer({ requete("a", 16) })
    objet.passer({})
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "livre", "" })
    verif.egal(#faux_pont.appels_de(etat, "exportItem"), 2)
  end,

  fabrication_lancee_n_est_pas_relancee_tant_qu_elle_tourne = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    local premiere = objet.passer({ requete("a", 16) })
    verif.egal({ premiere[1].statut, premiere[1].action.type }, { "en_fabrication", "fabriquer" })
    local seconde = objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "en_cours"
    local troisieme = objet.passer({ requete("a", 16) })
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 1)
    verif.egal({ seconde[1].action.type, troisieme[1].action.type }, { "attendre", "attendre" })
    verif.egal(troisieme[1].statut, "en_fabrication")
  end,

  fabrication_demandee_avec_le_compte_manquant = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.stock[PLANCHE] = 6
    objet.passer({ requete("a", 16, 10) })
    verif.egal(faux_pont.appels_de(etat, "craftItem"), { { { name = PLANCHE, count = 10 } } })
  end,

  plusieurs_requetes_du_meme_item_lancent_une_seule_fabrication_pour_le_total = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.stock[PLANCHE] = 10
    local lignes = objet.passer({ requete("a", 64), requete("b", 64), requete("c", 8, 8, { PIERRE }) })
    verif.egal(faux_pont.appels_de(etat, "craftItem"), { { { name = PLANCHE, count = 118 } } })
    verif.egal({ lignes[1].statut, lignes[2].statut, lignes[3].statut }, { "en_fabrication", "en_fabrication", "manquant" })
  end,

  tache_finie_libere_l_item = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "fini"
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal(lignes[1].action.type, "fabriquer")
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 2)
  end,

  tache_annulee_libere_l_item_sans_signaler_d_echec = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "annule"
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "en_fabrication", "fabrication lancée" })
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 2)
  end,

  echec_de_calcul_rend_les_requetes_manquantes_avec_le_message_de_debogage = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16), requete("b", 4) })
    etat.taches[1].etat = "echec_calcul"
    etat.taches[1].debug = "Missing: 4x minecraft:oak_log"
    local lignes = objet.passer({ requete("a", 16), requete("b", 4) })
    for _, ligne in ipairs(lignes) do
      verif.egal(ligne.statut, "manquant")
      contient(ligne.message, "ingrédients manquants")
      contient(ligne.message, "Missing: 4x minecraft:oak_log")
    end
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 1)
  end,

  tache_en_erreur_est_signalee_comme_un_echec = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "erreur"
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "manquant", "fabrication impossible : ingrédients manquants ?" })
  end,

  echec_de_fabrication_est_retente_a_la_passe_suivante = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "echec_calcul"
    objet.passer({ requete("a", 16) })
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "en_fabrication", "fabrication lancée" })
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 2)
  end,

  succes_apres_echec_efface_le_message = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "echec_calcul"
    objet.passer({ requete("a", 16) })
    objet.passer({ requete("a", 16) })
    etat.taches[2].etat = "en_cours"
    local attente = objet.passer({ requete("a", 16) })
    verif.egal({ attente[1].statut, attente[1].message }, { "en_fabrication", "fabrication en cours" })
    etat.taches[2].etat = "fini"
    etat.stock[PLANCHE] = 16
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "livre", "" })
  end,

  objet_tache_illisible_se_rabat_sur_la_liste_des_taches = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.objets_illisibles = true
    objet.passer({ requete("a", 16) })
    etat.taches[1].etat = "en_cours"
    verif.egal(objet.passer({ requete("a", 16) })[1].action.type, "attendre")
    etat.taches[1].etat = "fini"
    verif.egal(objet.passer({ requete("a", 16) })[1].action.type, "fabriquer")
  end,

  tache_listee_par_le_pont_bloque_la_fabrication_sans_memoire = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.taches[1] = { numero = 1, nom = PLANCHE, quantite = 4, etat = "en_cours" }
    verif.egal(objet.passer({ requete("a", 16) })[1].action.type, "attendre")
    verif.egal(#faux_pont.appels_de(etat, "craftItem"), 0)
  end,

  fabrication_refusee_porte_le_code_et_ne_memorise_rien = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.codes.craftItem = "CPU_NOT_FOUND"
    local lignes = objet.passer({ requete("a", 16), requete("b", 4) })
    verif.egal({ lignes[1].statut, lignes[2].statut }, { "erreur", "erreur" })
    contient(lignes[1].message, "CPU_NOT_FOUND")
    etat.codes.craftItem = nil
    verif.egal(objet.passer({ requete("a", 16) })[1].action.type, "fabriquer")
  end,

  exception_de_fabrication_porte_son_message = function()
    local objet, etat = preparer()
    etat.fabricables[PLANCHE] = true
    etat.exceptions.craftItem = "chunk déchargé"
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal(lignes[1].statut, "erreur")
    contient(lignes[1].message, "chunk déchargé")
  end,

  export_vers_inventaire_plein_donne_une_erreur_et_ne_memorise_rien = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.capacite = 0
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].livre }, { "erreur", 0 })
    contient(lignes[1].message, "plein")
    etat.capacite = 64
    verif.egal(objet.passer({ requete("a", 16) })[1].statut, "livre")
  end,

  export_refuse_porte_le_code_d_origine = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.cibles = { ["@up"] = true }
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal(lignes[1].statut, "erreur")
    contient(lignes[1].message, "INVENTORY_NOT_FOUND")
  end,

  pont_hors_reseau_met_chaque_ligne_en_erreur_sans_planter = function()
    local objet, etat = preparer()
    etat.connecte = false
    local lignes = objet.passer({ requete("a", 16), requete("b", 4, 4, { PIERRE }) })
    for _, ligne in ipairs(lignes) do
      verif.egal(ligne.statut, "erreur")
      contient(ligne.message, "NOT_CONNECTED")
    end
  end,

  exception_du_pont_porte_son_message_et_n_empeche_pas_les_suivantes = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.stock[PIERRE] = 64
    etat.exceptions.getItem = function(filtre)
      if filtre.name == PLANCHE then return "câble coupé" end
    end
    local lignes = objet.passer({ requete("a", 16), requete("b", 8, 8, { PIERRE }) })
    verif.egal(lignes[1].statut, "erreur")
    contient(lignes[1].message, "câble coupé")
    verif.egal({ lignes[2].statut, lignes[2].livre }, { "livre", 8 })
  end,

  exception_a_l_export_porte_son_message = function()
    local objet, etat = preparer()
    etat.stock[PLANCHE] = 64
    etat.exceptions.exportItem = "câble coupé"
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].livre }, { "erreur", 0 })
    contient(lignes[1].message, "câble coupé")
  end,

  motif_d_exclusion_invalide_est_ignore_et_signale_sans_planter_la_passe = function()
    local objet, etat = preparer({ exclusions = { "[", "_sapling$" } })
    etat.stock[PLANCHE] = 64
    verif.egal(objet.passer({ requete("a", 16) })[1].statut, "livre")
    verif.egal(#objet.avertissements, 1)
    contient(objet.avertissements[1], "[")
  end,

  requete_exclue_est_ignoree_sans_export = function()
    local objet, etat = preparer({ exclusions = { "_planks$" } })
    etat.stock[PLANCHE] = 64
    local lignes = objet.passer({ requete("a", 16) })
    verif.egal({ lignes[1].statut, lignes[1].message }, { "ignore", "exclu par les réglages" })
    verif.egal(#faux_pont.appels_de(etat, "exportItem"), 0)
  end,
}
