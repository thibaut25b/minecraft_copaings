-- Débit : fenêtres, barres, historique borné et conversion d'unités.

local verif = require("verif")
local debit = require("production.debit")

-- Série d'un item dont le stock monte de `pente` par seconde, mesuré toutes les `pas` secondes de 0 à `fin`.
local function serie_lineaire(depart, pente, pas, fin)
  local serie = {}
  for t = 0, fin, pas do serie[#serie + 1] = { t = t, n = depart + pente * t } end
  return serie
end

return {
  une_lecture_illisible_n_ajoute_aucun_echantillon = function()
    local series = {}
    debit.noter(series, { fer = 10 }, 0, 100)
    debit.noter(series, { fer = nil }, 2, 100)
    verif.egal(series, { fer = { { t = 0, n = 10 } } })
  end,

  une_lecture_valide_ajoute_un_echantillon_par_objet = function()
    local series = {}
    debit.noter(series, { fer = 10, cuivre = 0 }, 4, 100)
    verif.egal(series, { fer = { { t = 4, n = 10 } }, cuivre = { { t = 4, n = 0 } } })
  end,

  l_historique_oublie_les_echantillons_plus_vieux_que_la_duree = function()
    local series = {}
    for t = 0, 10 do debit.noter(series, { fer = t }, t, 5) end
    verif.egal(series.fer[1], { t = 5, n = 5 })
    verif.egal(#series.fer, 6)
  end,

  l_historique_garde_au_moins_deux_echantillons = function()
    local series = {}
    debit.noter(series, { fer = 1 }, 0, 5)
    debit.noter(series, { fer = 2 }, 100, 5)
    verif.egal(#series.fer, 2)
  end,

  le_debit_est_la_pente_moyenne_sur_la_fenetre = function()
    local d, partiel = debit.debit(serie_lineaire(100, 3, 2, 120), 60)
    verif.egal(d, 3)
    verif.egal(partiel, false)
  end,

  le_debit_est_negatif_quand_le_stock_baisse = function()
    local d = debit.debit(serie_lineaire(1000, -2, 2, 60), 30)
    verif.egal(d, -2)
  end,

  le_debit_ne_regarde_que_la_fenetre_demandee = function()
    local serie = { { t = 0, n = 0 }, { t = 50, n = 500 }, { t = 60, n = 500 }, { t = 70, n = 500 } }
    verif.egal((debit.debit(serie, 20)), 0)
  end,

  fenetre_plus_longue_que_l_historique_debit_marque_partiel = function()
    local d, partiel = debit.debit(serie_lineaire(0, 1, 2, 20), 3600)
    verif.egal(d, 1)
    verif.egal(partiel, true)
  end,

  fenetre_couverte_a_95_pour_cent_n_est_pas_partielle = function()
    local _, partiel = debit.debit(serie_lineaire(0, 1, 1, 95), 100)
    verif.egal(partiel, false)
    _, partiel = debit.debit(serie_lineaire(0, 1, 1, 94), 100)
    verif.egal(partiel, true)
  end,

  pas_de_debit_avec_moins_de_deux_echantillons_ou_une_duree_nulle = function()
    verif.egal(debit.debit({}, 60), nil)
    verif.egal(debit.debit({ { t = 0, n = 1 } }, 60), nil)
    verif.egal(debit.debit({ { t = 5, n = 1 }, { t = 5, n = 9 } }, 60), nil)
    verif.egal(debit.debit(serie_lineaire(0, 1, 1, 10), 0), nil)
  end,

  les_barres_vont_de_la_plus_ancienne_a_la_plus_recente = function()
    -- Stock constant 40 s, puis +5/s.
    local serie = {}
    for t = 0, 80, 2 do serie[#serie + 1] = { t = t, n = t <= 40 and 0 or (t - 40) * 5 } end
    verif.egal(debit.barres(serie, 80, 4), { 0, 0, 5, 5 })
  end,

  une_tranche_sans_donnees_vaut_nil = function()
    local serie = { { t = 0, n = 0 }, { t = 2, n = 2 }, { t = 50, n = 50 }, { t = 52, n = 52 } }
    local barres = debit.barres(serie, 40, 4)
    verif.egal(barres[1], nil)
    verif.egal(barres[2], nil)
    verif.egal(barres[3], nil)
    verif.egal(barres[4], 1)
  end,

  une_tranche_avant_le_debut_de_l_historique_vaut_nil = function()
    local barres = debit.barres(serie_lineaire(0, 1, 2, 20), 100, 5)
    verif.egal(barres, { nil, nil, nil, nil, 1 })
  end,

  barres_sans_historique_suffisant_est_vide = function()
    verif.egal(debit.barres({ { t = 0, n = 1 } }, 60, 6), {})
  end,

  le_depart_est_le_premier_echantillon_lu_et_ne_bouge_plus = function()
    local departs = {}
    debit.noter_departs(departs, { fer = 10, cuivre = 3 }, 4)
    debit.noter_departs(departs, { fer = 50, cuivre = nil, or_ = 7 }, 8)
    verif.egal(departs, { fer = { t = 4, n = 10 }, cuivre = { t = 4, n = 3 }, or_ = { t = 8, n = 7 } })
  end,

  une_lecture_illisible_ne_fixe_pas_de_depart = function()
    local departs = {}
    debit.noter_departs(departs, { fer = nil }, 4)
    verif.egal(departs, {})
  end,

  depuis_debut_mesure_depuis_le_depart_meme_oublie_par_la_fenetre = function()
    local series, departs = {}, {}
    for t = 0, 100, 10 do
      local lectures = { fer = 10 + 2 * t }
      debit.noter(series, lectures, t, 30)
      debit.noter_departs(departs, lectures, t)
    end
    verif.egal(series.fer[1].t, 70, "la fenêtre a oublié le départ")
    local variation, duree = debit.depuis_debut(series.fer, departs.fer)
    verif.egal({ variation, duree }, { 200, 100 })
  end,

  depuis_debut_est_vide_sans_depart_sans_echantillon_ou_sans_duree = function()
    verif.egal(debit.depuis_debut({ { t = 5, n = 1 } }, nil), nil)
    verif.egal(debit.depuis_debut({}, { t = 0, n = 1 }), nil)
    verif.egal(debit.depuis_debut({ { t = 5, n = 1 } }, { t = 5, n = 1 }), nil)
  end,

  convertir_passe_de_items_par_seconde_a_l_unite_choisie = function()
    verif.egal(debit.convertir(2, "s"), 2)
    verif.egal(debit.convertir(2, "min"), 120)
    verif.egal(debit.convertir(2, "h"), 7200)
    verif.erreur(function() debit.convertir(2, "jour") end, "unité inconnue")
  end,

  chaque_unite_a_un_libelle = function()
    verif.egal(debit.UNITES, { "s", "min", "h" })
    for _, unite in ipairs(debit.UNITES) do verif.vrai(debit.LIBELLES[unite], unite) end
  end,
}
