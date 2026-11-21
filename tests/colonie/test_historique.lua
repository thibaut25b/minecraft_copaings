-- L'historique garde une mesure par période, reste borné, et un fichier illisible donne une série vide.

colors = require("faux.couleurs")

local verif = require("verif")
local historique = require("colonie.historique")

local function mesure(bonheur)
  return { bonheur = bonheur or 7.5, population = 20, limite = 25, ouvertes = 4, problemes = 1 }
end

local function ligne(statut)
  return { statut = statut }
end

return {
  mesure_compte_les_requetes_ouvertes_et_celles_qui_demandent_d_agir = function()
    local colonie = { bonheur = 6.8, citoyens = 21, limite = 25 }
    local lignes = { ligne("livre"), ligne("manquant"), ligne("partiel"), ligne("erreur"), ligne("ignore") }
    verif.egal(historique.mesure(colonie, lignes),
      { bonheur = 6.8, population = 21, limite = 25, ouvertes = 4, problemes = 2 })
  end,

  sans_colonie_aucune_mesure_n_est_prise = function()
    verif.egal(historique.mesure(nil, {}), nil)
    local serie = {}
    verif.egal(historique.ajouter(serie, nil, 0, 300, 10), false)
    verif.egal(#serie, 0)
  end,

  une_mesure_par_periode_au_plus = function()
    local serie = {}
    verif.vrai(historique.ajouter(serie, mesure(), 1000, 300, 10))
    verif.egal(historique.ajouter(serie, mesure(), 1299, 300, 10), false)
    verif.vrai(historique.ajouter(serie, mesure(), 1300, 300, 10))
    verif.egal(#serie, 2)
    verif.egal(serie[2].instant, 1300)
  end,

  une_horloge_qui_recule_n_arrete_pas_l_historique = function()
    local serie = {}
    historique.ajouter(serie, mesure(), 5000, 300, 10)
    verif.vrai(historique.ajouter(serie, mesure(), 100, 300, 10))
  end,

  la_serie_garde_les_derniers_points_seulement = function()
    local serie = {}
    for i = 1, 8 do historique.ajouter(serie, mesure(i), i * 300, 300, 5) end
    verif.egal(#serie, 5)
    verif.egal(historique.valeurs(serie, "bonheur"), { 4, 5, 6, 7, 8 })
  end,

  serialiser_puis_lire_redonne_la_serie = function()
    local serie = {}
    historique.ajouter(serie, mesure(7.4), 1767300000, 300, 10)
    historique.ajouter(serie, { bonheur = 6.2, population = 23, limite = 25, ouvertes = 0, problemes = 0 }, 1767300300,
      300, 10)
    verif.egal(historique.lire(historique.serialiser(serie), 10), serie)
  end,

  lire_borne_aussi_la_serie = function()
    local serie = {}
    for i = 1, 6 do historique.ajouter(serie, mesure(), i * 300, 300, 10) end
    verif.egal(#historique.lire(historique.serialiser(serie), 3), 3)
  end,

  fichier_absent_vide_ou_corrompu_donne_une_serie_vide = function()
    verif.egal(historique.lire(nil, 10), {})
    verif.egal(historique.lire("", 10), {})
    verif.egal(historique.lire("{ pas un historique", 10), {})
    verif.egal(historique.lire("1000 7.5 20 25 4 1\n1300 7.5 20 abc 4 1", 10), {})
  end,

  etendue_en_texte_court = function()
    verif.egal(historique.etendue({}), "0 s")
    verif.egal(historique.etendue({ { instant = 0 }, { instant = 40 } }), "40 s")
    verif.egal(historique.etendue({ { instant = 0 }, { instant = 2100 } }), "35 min")
    verif.egal(historique.etendue({ { instant = 0 }, { instant = 21600 } }), "6 h")
  end,

  un_jour_de_mesures_par_defaut_tient_largement_sur_le_disque = function()
    local reglages = require("colonie.reglages")
    local serie = {}
    for i = 1, reglages.points_historique do
      historique.ajouter(serie, { bonheur = 10, population = 999, limite = 999, ouvertes = 999, problemes = 999 },
        1767300000 + i * reglages.periode_historique, reglages.periode_historique, reglages.points_historique)
    end
    verif.vrai(#historique.serialiser(serie) < 16000, "moins de 16 Ko sur un disque de 1 Mo")
  end,
}
