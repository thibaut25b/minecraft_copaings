-- Flux : base sans débit, production et consommation séparées, aller-retour, cases alignées sur le temps absolu.

local verif = require("verif")
local flux = require("production.flux")

local K = "a:b|"
local BRUT = { seuil_coupure = 1, delai_aller_retour = 0 }
local RETOUR = { seuil_coupure = 1, delai_aller_retour = 30 }
local COUPE = { seuil_coupure = 0.2, delai_aller_retour = 30 }

local function proche(obtenu, attendu, ecart, message)
  verif.vrai(math.abs(obtenu - attendu) <= (ecart or 1e-9),
    (message or "") .. " attendu " .. tostring(attendu) .. ", obtenu " .. tostring(obtenu))
end

-- Note `stock(t)` (quantité de K, nil = absent) de `debut` à `fin` par pas de `pas` ; renvoie l'état.
local function suivre(etat, reglages, debut, fin, pas, stock)
  etat = etat or flux.nouveau()
  for t = debut, fin, pas do
    local quantite = stock(t)
    flux.noter(etat, quantite and { [K] = quantite } or {}, t, reglages)
  end
  return etat
end

-- 7/s régulier ; à 60 s, `baisse` items sortent ; ils reviennent à `retour` s (nil : jamais).
local function sept_par_seconde(baisse, retour)
  return function(t)
    local stock = 1000 + 7 * t
    if t >= 60 and (retour == nil or t < retour) then stock = stock - baisse end
    return stock
  end
end

-- Instantané de `types` clés « a:1| » à « a:N| », chacune à `quantite`.
local function reseau(types, quantite)
  local instantane = {}
  for i = 1, types do instantane["a:" .. i .. "|"] = quantite end
  return instantane
end

-- Production et consommation totales de K sur toutes ses cases d'une minute.
local function totaux(etat)
  local production, consommation = 0, 0
  for _, case in pairs(etat.objets[K].larges.cases) do
    production, consommation = production + case.production, consommation + case.consommation
  end
  return production, consommation
end

-- Sur 1 h, période 10 s : vérifie qu'avec le délai de 30 s, production et consommation valent à 5 % près les
-- variations visibles (délai nul), et les renvoie.
local function sur_une_heure(stock)
  local p_brut, c_brut = flux.debits(suivre(nil, BRUT, 0, 3600, 10, stock), K, 3600, 3600)
  local production, consommation = flux.debits(suivre(nil, RETOUR, 0, 3600, 10, stock), K, 3600, 3600)
  proche(production, p_brut, 0.05 * p_brut, "production avec délai")
  proche(consommation, c_brut, 0.05 * c_brut, "consommation avec délai")
  return production, consommation
end

-- Stock constant à 1000 de 0 à 90 s, puis les valeurs de `suite`, une toutes les 10 s.
local function apres_un_calme(suite)
  local etat = suivre(nil, RETOUR, 0, 90, 10, function() return 1000 end)
  for k, quantite in ipairs(suite) do flux.noter(etat, { [K] = quantite }, 90 + 10 * k, RETOUR) end
  return etat
end

return {
  le_premier_instantane_sert_de_base_sans_debit = function()
    local etat = flux.nouveau()
    verif.egal(flux.noter(etat, { [K] = 50 }, 100, BRUT), "base")
    verif.egal({ flux.debits(etat, K, 60, 100) }, { 0, 0, 0, true })
    verif.egal(flux.depuis_depart(etat, K), nil)
    verif.egal(etat.objets[K].stock, 50)
    verif.egal(flux.noter(etat, { [K] = 50 }, 110, BRUT), "mesure")
  end,

  production_et_consommation_sont_separees_jamais_un_simple_net = function()
    local etat = flux.nouveau()
    flux.noter(etat, { [K] = 0 }, 0, BRUT)
    flux.noter(etat, { [K] = 100 }, 2, BRUT)
    flux.noter(etat, { [K] = 40 }, 4, BRUT)
    verif.egal({ flux.debits(etat, K, 60, 10) }, { 10, 6, 4, true })
  end,

  une_cle_absente_d_un_instantane_valide_vaut_zero = function()
    local etat = flux.nouveau()
    flux.noter(etat, { [K] = 10, ["a:c|"] = 5 }, 0, BRUT)
    flux.noter(etat, { ["a:c|"] = 5 }, 10, BRUT)
    verif.egal(etat.objets[K].stock, 0)
    local _, consommation = flux.debits(etat, K, 60, 10)
    verif.egal(consommation, 1)
  end,

  une_lecture_manquee_repartit_la_variation_au_prorata_du_temps = function()
    local etat = flux.nouveau()
    flux.noter(etat, { [K] = 0 }, 0, BRUT)
    flux.noter(etat, { [K] = 20 }, 20, BRUT)
    local barres = flux.barres(etat, K, 600, 20)
    verif.egal(barres[59].production, 1)
    verif.egal(barres[60].production, 1)
  end,

  un_objet_apparu_apres_la_base_compte_sa_quantite_en_production = function()
    local etat = flux.nouveau()
    flux.noter(etat, { ["a:c|"] = 1 }, 0, BRUT)
    flux.noter(etat, { ["a:c|"] = 1, [K] = 50 }, 10, BRUT)
    local production = flux.debits(etat, K, 60, 10)
    verif.egal(production, 5)
    verif.egal({ flux.depuis_depart(etat, K) }, { 50, 10 })
  end,

  deux_variantes_du_meme_id_restent_separees = function()
    local etat = flux.nouveau()
    flux.noter(etat, { ["c|a"] = 10, ["c|b"] = 10 }, 0, BRUT)
    flux.noter(etat, { ["c|a"] = 20, ["c|b"] = 5 }, 10, BRUT)
    verif.egal({ flux.debits(etat, "c|a", 60, 10) }, { 1, 0, 1, true })
    verif.egal({ flux.debits(etat, "c|b", 60, 10) }, { 0, 0.5, -0.5, true })
  end,

  le_cas_vu_en_jeu_7_par_seconde_moins_250_puis_retour_4_s_apres_n_est_que_production = function()
    local etat = suivre(nil, RETOUR, 0, 200, 2, sept_par_seconde(250, 64))
    local production, consommation = flux.debits(etat, K, 60, 120)
    proche(production, 7, 0.5, "production sur 1 min")
    verif.egal(consommation, 0)
    production, consommation = flux.debits(etat, K, 600, 200)
    proche(production, 7, 1e-6, "production depuis le départ")
    verif.egal(consommation, 0)
    verif.egal(etat.objets[K].attente, {})
  end,

  un_retrait_sans_retour_devient_consommation_apres_le_delai_datee_de_la_baisse = function()
    local avec = suivre(nil, RETOUR, 0, 88, 2, sept_par_seconde(250))
    local _, consommation = flux.debits(avec, K, 600, 88)
    verif.egal(consommation, 0)
    suivre(avec, RETOUR, 90, 100, 2, sept_par_seconde(250))
    local brut = suivre(nil, BRUT, 0, 100, 2, sept_par_seconde(250))
    local p_avec, c_avec = flux.debits(avec, K, 600, 100)
    local p_brut, c_brut = flux.debits(brut, K, 600, 100)
    proche(p_avec, p_brut, 1e-9, "production inchangée")
    proche(c_avec, c_brut, 1e-9, "consommation")
    proche(c_avec * 100, 236, 1e-6, "baisse vue entre deux mesures")
    proche(flux.barres(avec, K, 600, 100)[56].consommation, 23.6, 1e-9, "case de la baisse")
  end,

  -- Récolte de 300 toutes les 30 s, consommation de 5/s : la période qui reçoit la récolte ne voit que +250.
  une_recolte_par_a_coups_avec_une_consommation_reguliere_n_efface_aucune_consommation = function()
    local production, consommation = sur_une_heure(function(t) return 10000 - 5 * t + 300 * math.floor(t / 30) end)
    proche(production, 250 / 30, 0.05 * 250 / 30, "production")
    proche(consommation, 100 / 30, 0.05 * 100 / 30, "consommation")
  end,

  -- 10/s livrés par piles de 64, 8/s consommés : chaque période voit +48 (deux piles) ou -16 (une pile).
  une_production_livree_par_piles_de_64_n_est_pas_absorbee_par_les_remboursements = function()
    local production, consommation = sur_une_heure(function(t) return 10000 + 64 * math.floor(10 * t / 64) - 8 * t end)
    proche(production, 2.7, 0.05 * 2.7, "production")
    proche(consommation, 0.7, 0.05 * 0.7, "consommation")
  end,

  une_baisse_habituelle_est_comptee_tout_de_suite = function()
    local etat = suivre(nil, RETOUR, 0, 100, 10, function(t) return 10000 - 5 * t end)
    verif.egal({ flux.debits(etat, K, 60, 100) }, { 0, 5, -5, false })
  end,

  un_objet_neuf_n_annule_rien_avant_six_mesures_d_historique = function()
    local etat = flux.nouveau()
    flux.noter(etat, { ["a:c|"] = 1 }, 0, RETOUR)
    flux.noter(etat, { ["a:c|"] = 1, [K] = 1000 }, 10, RETOUR)
    flux.noter(etat, { ["a:c|"] = 1, [K] = 500 }, 20, RETOUR)
    flux.noter(etat, { ["a:c|"] = 1, [K] = 1000 }, 30, RETOUR)
    verif.egal(etat.objets[K].attente, {})
    verif.egal({ totaux(etat) }, { 1500, 500 })
  end,

  une_hausse_ne_rembourse_jamais_une_somme_de_baisses = function()
    local etat = apres_un_calme({ 900, 800, 1000, 1000, 1000 })
    verif.egal(etat.objets[K].attente, {})
    verif.egal({ totaux(etat) }, { 200, 200 })
  end,

  une_hausse_rembourse_une_seule_baisse_la_plus_proche_en_taille = function()
    local etat = apres_un_calme({ 900, 790, 898, 898, 898 })
    verif.egal(etat.objets[K].attente, {})
    verif.egal({ totaux(etat) }, { 0, 102 })
  end,

  une_hausse_qui_n_est_pas_anormale_ne_rembourse_rien = function()
    local etat = suivre(nil, RETOUR, 0, 90, 10, function(t) return 1000 + 10 * t end)
    flux.noter(etat, { [K] = 1800 }, 100, RETOUR)
    flux.noter(etat, { [K] = 2000 }, 110, RETOUR)
    verif.egal(#etat.objets[K].attente, 1)
    suivre(etat, RETOUR, 120, 150, 10, function(t) return 2000 + 10 * (t - 110) end)
    verif.egal({ totaux(etat) }, { 1500, 100 })
  end,

  production_moins_consommation_egale_la_variation_de_stock_avec_le_delai_actif = function()
    local graine, stocks, stock, retour = 12345, {}, 5000, 0
    local function tirer(n)
      graine = (graine * 16807) % 2147483647
      return graine % n
    end
    for k = 0, 300 do
      stock = stock + retour + tirer(100) - tirer(60)
      retour = 0
      if k > 10 and tirer(7) == 0 then
        retour = 200 + tirer(300)
        stock = stock - retour
      elseif tirer(11) == 0 then
        stock = stock - 150 - tirer(200)
      end
      stocks[k] = stock
    end
    local function serie(t) return stocks[t / 10] end
    local avec = suivre(nil, RETOUR, 0, 3000, 10, serie)
    local brut = suivre(nil, BRUT, 0, 3000, 10, serie)
    local p_avec, c_avec = totaux(avec)
    local p_brut, c_brut = totaux(brut)
    local en_attente = 0
    for _, baisse in ipairs(avec.objets[K].attente) do en_attente = en_attente + baisse.n end
    proche(p_avec - c_avec, stocks[300] - stocks[0] + en_attente, 1e-6, "conservation")
    proche(p_brut - p_avec, c_brut - c_avec - en_attente, 1e-6, "remboursements nets nuls")
    verif.vrai(p_brut - p_avec > 1000, "allers-retours annulés : " .. (p_brut - p_avec))
  end,

  un_delai_nul_donne_le_comportement_brut = function()
    local etat = suivre(nil, BRUT, 0, 200, 2, sept_par_seconde(250, 64))
    local production, consommation = flux.debits(etat, K, 600, 200)
    proche(consommation * 200, 236, 1e-6)
    proche(production * 200, 1400 + 236, 1e-6)
  end,

  production_moins_consommation_egale_la_variation_de_stock_sur_une_fenetre_complete = function()
    local function stock(t) return 5000 + ((t * 37) % 101) * 3 - ((t * 13) % 7) * 11 end
    local etat = suivre(nil, BRUT, 0, 1300, 10, stock)
    local production, consommation, net, partiel = flux.debits(etat, K, 600, 1300)
    verif.egal(partiel, false)
    verif.vrai(production > 0 and consommation > 0)
    proche((production - consommation) * 600, stock(1300) - stock(700), 1e-6)
    proche(net, production - consommation, 1e-9)
  end,

  les_barres_sont_identiques_avant_et_apres_une_mesure_sans_variation_au_decalage_pres = function()
    local etat = suivre(nil, BRUT, 100, 200, 10, function(t) return t end)
    local avant = flux.barres(etat, K, 600, 200)
    flux.noter(etat, { [K] = 200 }, 210, BRUT)
    local apres = flux.barres(etat, K, 600, 210)
    for k = 1, 59 do verif.egal(apres[k], avant[k + 1], "barre " .. k) end
    verif.egal(apres[60], { production = 0, consommation = 0, vide = false })
  end,

  pas_de_dents_de_scie_quand_la_periode_vaut_la_largeur_de_case = function()
    local etat = suivre(nil, BRUT, 5, 305, 10, function(t) return 7 * t end)
    local barres = flux.barres(etat, K, 600, 305)
    for k = 31, 60 do proche(barres[k].production, k == 60 and 3.5 or 7, 1e-9, "barre " .. k) end
  end,

  les_cases_avant_l_historique_sont_vides = function()
    local etat = suivre(nil, BRUT, 1000, 1100, 10, function(t) return t end)
    local barres = flux.barres(etat, K, 600, 1100)
    verif.egal(barres[50].vide, true)
    verif.egal(barres[51].vide, false)
    verif.egal(#flux.barres(etat, K, 3600, 1100), 60)
  end,

  le_debit_est_partiel_tant_que_l_historique_est_plus_court_que_la_fenetre = function()
    local etat = suivre(nil, BRUT, 0, 300, 10, function(t) return t end)
    verif.egal(select(4, flux.debits(etat, K, 600, 300)), true)
    verif.egal(select(4, flux.debits(etat, K, 60, 300)), false)
    suivre(etat, BRUT, 310, 600, 10, function(t) return t end)
    verif.egal({ flux.debits(etat, K, 600, 600) }, { 1, 0, 1, false })
  end,

  la_fenetre_d_une_heure_lit_les_cases_d_une_minute = function()
    local etat = suivre(nil, BRUT, 0, 3600, 60, function(t) return 2 * t end)
    verif.egal({ flux.debits(etat, K, 3600, 3600) }, { 2, 0, 2, false })
    verif.egal(etat.objets[K].fines.nombre, 60)
  end,

  les_cases_perimees_sont_retirees_et_un_objet_immobile_depuis_une_heure_n_a_plus_de_cases = function()
    local etat = suivre(nil, BRUT, 0, 10, 10, function(t) return 10 + t end)
    flux.nommer(etat, { [K] = "Bidule" })
    suivre(etat, BRUT, 20, 620, 10, function() return 20 end)
    verif.egal(etat.objets[K].fines.nombre, 0)
    verif.egal(etat.objets[K].larges.nombre, 1)
    suivre(etat, BRUT, 630, 3700, 10, function() return 20 end)
    verif.egal(etat.objets[K].larges.nombre, 0)
    verif.egal(etat.objets[K].stock, 20)
    verif.egal(etat.objets[K].nom, "Bidule")
  end,

  un_objet_absent_a_zero_sans_case_est_retire = function()
    local etat = suivre(nil, BRUT, 0, 10, 10, function(t) return t == 0 and 10 or nil end)
    verif.vrai(etat.objets[K] ~= nil)
    suivre(etat, BRUT, 20, 3700, 10, function() return nil end)
    verif.egal(etat.objets[K], nil)
  end,

  une_coupure_ne_note_rien_et_la_mesure_valide_suivante_compte_l_intervalle = function()
    local reglages = { seuil_coupure = 0.2, delai_aller_retour = 0 }
    local etat = flux.nouveau()
    flux.noter(etat, reseau(20, 100), 0, reglages)
    verif.egal(flux.noter(etat, {}, 10, reglages), "coupure")
    verif.egal(etat.objets["a:1|"].stock, 100)
    verif.egal(flux.noter(etat, reseau(20, 150), 20, reglages), "mesure")
    verif.egal({ flux.debits(etat, "a:1|", 60, 20) }, { 2.5, 0, 2.5, true })
  end,

  une_lecture_partielle_ne_devient_ni_reference_ni_base = function()
    local reglages = { seuil_coupure = 0.2, delai_aller_retour = 30 }
    local etat = flux.nouveau()
    flux.noter(etat, reseau(500, 100), 0, reglages)
    verif.egal(flux.noter(etat, reseau(5, 100), 10, reglages), "coupure")
    verif.egal(flux.noter(etat, reseau(5, 100), 20, reglages), "coupure")
    local revenu = reseau(500, 100)
    revenu["a:7|"] = 130
    verif.egal(flux.noter(etat, revenu, 30, reglages), "mesure")
    verif.egal({ flux.debits(etat, "a:7|", 60, 30) }, { 1, 0, 1, true })
    verif.egal({ flux.debits(etat, "a:300|", 60, 30) }, { 0, 0, 0, true })
  end,

  une_coupure_qui_dure_six_lectures_devient_la_nouvelle_base_sans_variation = function()
    local reglages = { seuil_coupure = 0.2, delai_aller_retour = 0 }
    local etat = flux.nouveau()
    flux.noter(etat, reseau(500, 100), 0, reglages)
    for k = 1, 5 do
      verif.egal(flux.noter(etat, reseau(5, 100), 10 * k, reglages), "coupure", "lecture " .. k)
    end
    verif.egal(flux.noter(etat, reseau(5, 100), 60, reglages), "base")
    verif.egal(etat.objets["a:300|"].stock, 0)
    verif.egal({ flux.debits(etat, "a:300|", 60, 60) }, { 0, 0, 0, false })
    verif.egal(flux.noter(etat, reseau(5, 110), 70, reglages), "mesure")
    proche(flux.debits(etat, "a:1|", 60, 70), 10 / 60, 1e-9, "production après la nouvelle base")
  end,

  une_nouvelle_base_abandonne_les_baisses_en_attente = function()
    local etat = suivre(nil, RETOUR, 0, 60, 2, sept_par_seconde(250))
    verif.egal(#etat.objets[K].attente, 1)
    flux.rebaser(etat)
    verif.egal(flux.noter(etat, { [K] = 1000 }, 62, RETOUR), "base")
    verif.egal(etat.objets[K].attente, {})
    suivre(etat, RETOUR, 64, 120, 2, function(t) return 1000 + 7 * (t - 62) end)
    verif.egal(select(2, flux.debits(etat, K, 600, 120)), 0)
    local coupe, instantane = flux.nouveau(), reseau(25, 10)
    for t = 0, 60, 2 do
      instantane[K] = sept_par_seconde(250)(t)
      flux.noter(coupe, instantane, t, COUPE)
    end
    verif.egal(#coupe.objets[K].attente, 1)
    for k = 1, 6 do flux.noter(coupe, {}, 60 + 2 * k, COUPE) end
    verif.egal(coupe.objets[K].attente, {})
    flux.noter(coupe, {}, 200, COUPE)
    verif.egal(select(2, flux.debits(coupe, K, 600, 200)), 0)
  end,

  une_horloge_qui_recule_ou_une_duree_nulle_prend_une_base_sans_variation = function()
    local etat = suivre(nil, BRUT, 0, 20, 10, function(t) return 100 + t end)
    verif.egal(flux.noter(etat, { [K] = 500 }, 20, BRUT), "base")
    verif.egal(flux.noter(etat, { [K] = 900 }, 5, BRUT), "base")
    verif.egal(select(2, flux.debits(etat, K, 60, 20)), 0)
    proche(flux.debits(etat, K, 60, 20), 1, 1e-9, "production")
    verif.egal(flux.noter(etat, { [K] = 910 }, 15, BRUT), "mesure")
    verif.egal({ flux.depuis_depart(etat, K) }, { 30, 15 })
  end,

  rebaser_fait_du_prochain_instantane_une_base = function()
    local etat = suivre(nil, BRUT, 0, 10, 10, function() return 5 end)
    flux.rebaser(etat)
    verif.egal(flux.noter(etat, { [K] = 500 }, 20, BRUT), "base")
    verif.egal(flux.debits(etat, K, 60, 20), 0)
  end,

  reinitialiser_vide_les_cases_et_recale_le_depart = function()
    local etat = suivre(nil, BRUT, 0, 100, 10, function(t) return t end)
    verif.egal({ flux.depuis_depart(etat, K) }, { 100, 100 })
    flux.reinitialiser(etat, K)
    verif.egal(etat.objets[K].fines.nombre, 0)
    verif.egal({ flux.debits(etat, K, 60, 100) }, { 0, 0, 0, true })
    suivre(etat, BRUT, 110, 120, 10, function(t) return t end)
    verif.egal({ flux.depuis_depart(etat, K) }, { 20, 20 })
    flux.reinitialiser(etat, "inconnu|")
  end,

  les_unites_convertissent_les_debits = function()
    verif.egal(flux.convertir(2, "min"), 120)
    verif.erreur(function() flux.convertir(1, "jour") end, "unité inconnue")
  end,
}
