-- Flux : base sans débit, production et consommation séparées, aller-retour, cases alignées sur le temps absolu.

local verif = require("verif")
local flux = require("production.flux")

local K = "a:b|"
local BRUT = { seuil_coupure = 1, delai_aller_retour = 0 }
local RETOUR = { seuil_coupure = 1, delai_aller_retour = 30 }

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

  un_aller_retour_rapide_n_est_ni_production_ni_consommation = function()
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

  une_coupure_ne_note_rien_et_l_instantane_suivant_sert_de_base = function()
    local plein = {}
    for i = 1, 20 do plein["a:" .. i .. "|"] = 100 end
    local reglages = { seuil_coupure = 0.2, delai_aller_retour = 0 }
    local etat = flux.nouveau()
    flux.noter(etat, plein, 0, reglages)
    verif.egal(flux.noter(etat, {}, 10, reglages), "coupure")
    verif.egal(etat.objets["a:1|"].stock, 100)
    local revenu = {}
    for cle in pairs(plein) do revenu[cle] = 150 end
    verif.egal(flux.noter(etat, revenu, 20, reglages), "base")
    verif.egal({ flux.debits(etat, "a:1|", 60, 20) }, { 0, 0, 0, true })
    verif.egal(flux.noter(etat, revenu, 30, reglages), "mesure")
    verif.egal({ flux.depuis_depart(etat, "a:1|") }, { 0, 30 })
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

  noter_en_lots_avec_pause_donne_le_meme_etat_qu_en_une_fois = function()
    local function instantane(t)
      local liste = {}
      for i = 1, 2500 do liste["a:" .. i .. "|"] = i + t * (i % 3) end
      return liste
    end
    local une_fois, en_lots, pauses = flux.nouveau(), flux.nouveau(), 0
    for t = 0, 20, 10 do
      flux.noter(une_fois, instantane(t), t, BRUT)
      flux.noter(en_lots, instantane(t), t, BRUT, function() pauses = pauses + 1 end)
    end
    verif.egal(en_lots, une_fois)
    verif.egal(pauses, 6)
  end,

  les_unites_convertissent_les_debits = function()
    verif.egal(flux.convertir(2, "min"), 120)
    verif.erreur(function() flux.convertir(1, "jour") end, "unité inconnue")
  end,
}
