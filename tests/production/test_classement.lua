-- Classement : tri par sens départagé par nom, exclusions, débit mini, totaux, alertes, consommation masquable.

local verif = require("verif")
local flux = require("production.flux")
local classement = require("production.classement")

local BRUT = { seuil_coupure = 1, delai_aller_retour = 0 }

-- État à 60 s : chaque objet passe de `avant` à `apres` en 60 s ; noms donnés par `noms`.
local function etat_de(objets, noms)
  local etat = flux.nouveau()
  local debut, fin = {}, {}
  for cle, valeurs in pairs(objets) do debut[cle], fin[cle] = valeurs[1], valeurs[2] end
  flux.noter(etat, debut, 0, BRUT)
  flux.noter(etat, fin, 60, BRUT)
  flux.nommer(etat, noms or {})
  return etat
end

-- Instructions Lua permises à une mesure suivie de son classement (5000 types) : quelques dixièmes de seconde
-- pour la VM de CC, qui coupe un programme après 7 s sans pause.
local BUDGET_INSTRUCTIONS = 5000000
local REGLAGES = { consommation = true, exclure = {}, debit_mini = 0, delai_alerte = 3600 }

local function avec(modifs)
  local r = {}
  for cle, valeur in pairs(REGLAGES) do r[cle] = valeur end
  for cle, valeur in pairs(modifs or {}) do r[cle] = valeur end
  return r
end

local function cles(lignes)
  local liste = {}
  for i, ligne in ipairs(lignes) do liste[i] = ligne.cle end
  return liste
end

local ETAT = {
  ["a:fer|"] = { 0, 600 },     -- +10/s
  ["a:or|"] = { 600, 0 },      -- -10/s
  ["a:cuivre|"] = { 0, 120 },  -- +2/s
  ["b:pierre|"] = { 0, 600 },  -- +10/s
}
local NOMS = { ["a:fer|"] = "Fer", ["a:or|"] = "Or", ["a:cuivre|"] = "Cuivre", ["b:pierre|"] = "Pierre" }

return {
  le_sens_prod_trie_par_production_decroissante_departagee_par_nom = function()
    local resultat = classement.classer(etat_de(ETAT, NOMS), 60, { fenetre = 60, sens = "prod" }, avec())
    verif.egal(cles(resultat.lignes), { "a:fer|", "b:pierre|", "a:cuivre|" })
    verif.egal(resultat.lignes[1], { cle = "a:fer|", nom = "Fer", stock = 600, production = 10, consommation = 0,
      net = 10, partiel = false })
  end,

  le_sens_conso_trie_par_consommation_et_bilan_par_net_absolu = function()
    local etat = etat_de(ETAT, NOMS)
    verif.egal(cles(classement.classer(etat, 60, { fenetre = 60, sens = "conso" }, avec()).lignes)[1], "a:or|")
    verif.egal(cles(classement.classer(etat, 60, { fenetre = 60, sens = "bilan" }, avec()).lignes),
      { "a:fer|", "a:or|", "b:pierre|", "a:cuivre|" })
  end,

  les_exclusions_prennent_un_id_exact_ou_un_prefixe_de_mod = function()
    local resultat = classement.classer(etat_de(ETAT, NOMS), 60, { fenetre = 60, sens = "prod" },
      avec({ exclure = { "b:", "a:or" } }))
    verif.egal(cles(resultat.lignes), { "a:fer|", "a:cuivre|" })
    verif.egal(resultat.totaux.connus, 2)
  end,

  le_debit_mini_par_minute_masque_les_lignes_sous_le_critere_du_tri = function()
    local resultat = classement.classer(etat_de(ETAT, NOMS), 60, { fenetre = 60, sens = "prod" },
      avec({ debit_mini = 200 }))
    verif.egal(cles(resultat.lignes), { "a:fer|", "b:pierre|" })
    verif.egal(resultat.totaux.connus, 4)
  end,

  les_totaux_comptent_production_consommation_actifs_et_connus = function()
    local objets = { ["a:immobile|"] = { 5, 5 } }
    for cle, valeurs in pairs(ETAT) do objets[cle] = valeurs end
    local resultat = classement.classer(etat_de(objets, NOMS), 60, { fenetre = 60, sens = "prod" }, avec())
    verif.egal(resultat.totaux, { production = 22, consommation = 10, actifs = 4, connus = 5 })
  end,

  une_alerte_signale_un_net_negatif_avant_rupture_triee_par_temps_restant = function()
    local etat = etat_de({ ["a:or|"] = { 1800, 1200 }, ["a:sel|"] = { 120, 60 }, ["a:eau|"] = { 1e9, 1e9 - 60 } })
    local resultat = classement.classer(etat, 60, { fenetre = 60, sens = "prod" }, avec())
    verif.egal(#resultat.alertes, 2)
    verif.egal(resultat.alertes[1], { cle = "a:sel|", nom = "a:sel", stock = 60, net = -1, avant_rupture = 60 })
    verif.egal(resultat.alertes[2].cle, "a:or|")
  end,

  sans_consommation_aucun_chiffre_de_conso_ni_de_net_ni_alerte_et_sens_prod = function()
    local resultat = classement.classer(etat_de(ETAT, NOMS), 60, { fenetre = 60, sens = "conso" },
      avec({ consommation = false }))
    verif.egal(cles(resultat.lignes), { "a:fer|", "b:pierre|", "a:cuivre|" })
    for _, ligne in ipairs(resultat.lignes) do
      verif.egal(ligne.consommation, nil)
      verif.egal(ligne.net, nil)
    end
    verif.egal(resultat.totaux, { production = 22, actifs = 3, connus = 4 })
    verif.egal(resultat.alertes, {})
  end,

  la_liste_suivie_filtre_les_cles_et_un_id_sans_nbt_prend_toutes_ses_variantes = function()
    local etat = etat_de({ ["c|x"] = { 0, 60 }, ["c|y"] = { 0, 120 }, ["a:fer|"] = { 0, 600 } })
    local suivis = { { objet = "c", nom = "" }, { objet = "a:absent", nom = "Absent", nbt = "" } }
    local resultat = classement.classer(etat, 60, { fenetre = 60, sens = "prod", suivis = suivis }, avec())
    verif.egal(cles(resultat.lignes), { "c|y", "c|x", "a:absent|" })
    verif.egal(resultat.lignes[3], { cle = "a:absent|", nom = "Absent", stock = 0, production = 0,
      consommation = 0, net = 0, partiel = true })
  end,

  un_id_suivi_sans_variante_connue_donne_la_variante_sans_composants = function()
    local resultat = classement.classer(flux.nouveau(), 60, { fenetre = 60, sens = "prod",
      suivis = { { objet = "a:b", nom = "" } } }, avec())
    verif.egal(cles(resultat.lignes), { "a:b|" })
    verif.egal(resultat.lignes[1].nom, "a:b")
  end,

  -- Mesure et classement se font d'un bloc, sans rendre la main : leur coût doit rester loin de la limite de CC.
  mesurer_et_classer_5000_types_dont_1000_actifs_tient_dans_un_budget_court = function()
    local reglages = { seuil_coupure = 0.2, delai_aller_retour = 30 }
    local function instantane(t)
      local liste = {}
      for i = 1, 5000 do liste["a:" .. i .. "|"] = i <= 1000 and 1000 + (i % 7) * t - (t % 30 == 0 and 50 or 0) or i end
      return liste
    end
    local etat = flux.nouveau()
    for t = 0, 590, 10 do flux.noter(etat, instantane(t), t, reglages) end
    local suivant = instantane(600)
    local instructions = 0
    debug.sethook(function() instructions = instructions + 1000 end, "", 1000)
    flux.noter(etat, suivant, 600, reglages)
    local resultat = classement.ecran(etat, 600, { fenetre = 600, sens = "prod", onglet = "tout", suivis = {},
      tout = true }, avec())
    debug.sethook()
    verif.vrai(resultat.totaux.actifs == 1000, "actifs : " .. resultat.totaux.actifs)
    verif.vrai(instructions < BUDGET_INSTRUCTIONS, "instructions : " .. instructions)
  end,

  l_onglet_suivis_ne_garde_que_la_liste_mais_totaux_et_alertes_couvrent_tout_le_reseau = function()
    local etat = etat_de(ETAT)
    local suivis = { { objet = "a:fer", nom = "" } }
    local vue = { fenetre = 60, sens = "prod", onglet = "suivis", suivis = suivis, tout = true }
    local resultat = classement.ecran(etat, 60, vue, avec())
    verif.egal(cles(resultat.lignes), { "a:fer|" })
    verif.egal(resultat.totaux.connus, 4)
    verif.egal(#resultat.alertes, 1)
    vue.onglet = "tout"
    verif.egal(#classement.ecran(etat, 60, vue, avec()).lignes, 3)
  end,

  sans_tout_le_perimetre_est_la_liste_suivie = function()
    local etat = etat_de(ETAT)
    local vue = { fenetre = 60, sens = "prod", onglet = "suivis", suivis = { { objet = "a:or", nom = "" } }, tout = false }
    local resultat = classement.ecran(etat, 60, vue, avec())
    verif.egal(cles(resultat.lignes), { "a:or|" })
    verif.egal(resultat.totaux.connus, 1)
  end,

  sans_liste_suivie_seuls_les_objets_qui_bougent_dans_le_sens_sont_listes = function()
    local etat = etat_de({ ["a:monte|"] = { 0, 600 }, ["a:baisse|"] = { 600, 0 }, ["a:fixe|"] = { 50, 50 } })
    local function lister(sens, suivis)
      return cles(classement.classer(etat, 60, { fenetre = 60, sens = sens, suivis = suivis }, avec()).lignes)
    end
    verif.egal(lister("prod"), { "a:monte|" })
    verif.egal(lister("conso"), { "a:baisse|" })
    verif.egal(lister("bilan"), { "a:baisse|", "a:monte|" })
    verif.egal(#lister("prod", { { objet = "a:fixe", nom = "" }, { objet = "a:baisse", nom = "" } }), 2)
  end,
}
