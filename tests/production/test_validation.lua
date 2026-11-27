-- Validation de la config : entrées fautives écartées avec leur message, valeurs hors bornes au défaut.

local verif = require("verif")
colors = require("faux.couleurs")
local validation = require("production.validation")
local defauts = require("production.reglages")

local function avec(reglages)
  local complet = {}
  for cle, valeur in pairs(defauts) do complet[cle] = valeur end
  for cle, valeur in pairs(reglages) do complet[cle] = valeur end
  return validation.valider(complet, defauts)
end

local function contient(erreurs, motif)
  for _, message in ipairs(erreurs) do
    if message:find(motif, 1, true) then return true end
  end
  return false
end

return {
  defauts_sont_valides = function()
    local propre, erreurs = avec({})
    verif.egal(erreurs, {})
    verif.egal(propre.periode, 10)
    verif.egal(propre.unite, "min")
    verif.egal(propre.tout, true)
    verif.egal(propre.consommation, true)
    verif.egal(propre.fenetre, 600)
    verif.egal(propre.sens, "prod")
    verif.egal(propre.exclure, {})
    verif.egal(propre.debit_mini, 0)
    verif.egal(propre.seuil_coupure, 0.2)
    verif.egal(propre.delai_aller_retour, 30)
    verif.egal(propre.delai_alerte, 3600)
    verif.egal(propre.coffre, "")
    verif.egal(propre.objets, {})
    verif.egal(propre.duree_historique, nil)
    verif.egal(propre.duree_graphe, nil)
  end,

  objet_valide_recoit_un_nom_vide_par_defaut_et_garde_son_nbt = function()
    local propre = avec({ objets = { { objet = "minecraft:iron_ingot" },
      { objet = "minecraft:gold_ingot", nom = "Or", nbt = "" } } })
    verif.egal(propre.objets, { { objet = "minecraft:iron_ingot", nom = "" },
      { objet = "minecraft:gold_ingot", nom = "Or", nbt = "" } })
  end,

  objet_fautif_est_ecarte_et_les_autres_gardes = function()
    local propre, erreurs = avec({ objets = { { nom = "Sans id" }, "texte", { objet = "a:b", nom = 3 },
      { objet = "a:c", nbt = 5 }, { objet = "minecraft:iron_ingot" } } })
    verif.egal(propre.objets, { { objet = "minecraft:iron_ingot", nom = "" } })
    verif.vrai(contient(erreurs, "objet n°1 écarté : objet manquant"), erreurs[1])
    verif.vrai(contient(erreurs, "objet n°2 écarté : n'est pas une table"))
    verif.vrai(contient(erreurs, "objet a:b écarté : nom doit être un texte"))
    verif.vrai(contient(erreurs, "objet a:c écarté : nbt doit être un texte"))
  end,

  un_doublon_meme_objet_meme_nbt_est_ecarte_mais_deux_variantes_restent = function()
    local propre, erreurs = avec({ objets = { { objet = "a:b", nom = "Premier" }, { objet = "a:b", nom = "Second" },
      { objet = "a:b", nbt = "x" }, { objet = "a:b", nbt = "" }, { objet = "a:b", nbt = "x" } } })
    verif.egal(propre.objets, { { objet = "a:b", nom = "Premier" }, { objet = "a:b", nom = "", nbt = "x" },
      { objet = "a:b", nom = "", nbt = "" } })
    verif.egal(#erreurs, 2)
    verif.vrai(contient(erreurs, "objet a:b écarté : déjà suivi"))
  end,

  valeurs_hors_bornes_retombent_sur_les_defauts = function()
    local propre, erreurs = avec({ periode = 1, echelle_texte = 9, theme = "rose", unite = "jour", tout = "oui",
      consommation = 1, fenetre = 300, sens = "haut", debit_mini = -1, seuil_coupure = 0, delai_aller_retour = 301,
      delai_alerte = 0, pont = 3, coffre = 4, objets = "pas une liste", exclure = "ae2:" })
    verif.egal(propre.periode, 10)
    verif.egal(propre.echelle_texte, 0.5)
    verif.egal(propre.theme, "nuit")
    verif.egal(propre.unite, "min")
    verif.egal(propre.tout, true)
    verif.egal(propre.consommation, true)
    verif.egal(propre.fenetre, 600)
    verif.egal(propre.sens, "prod")
    verif.egal(propre.debit_mini, 0)
    verif.egal(propre.seuil_coupure, 0.2)
    verif.egal(propre.delai_aller_retour, 30)
    verif.egal(propre.delai_alerte, 3600)
    verif.egal(propre.pont, "")
    verif.egal(propre.coffre, "")
    verif.egal(propre.objets, {})
    verif.egal(propre.exclure, {})
    verif.egal(#erreurs, 16)
  end,

  la_periode_minimale_est_de_deux_secondes = function()
    verif.egal(avec({ periode = 2 }).periode, 2)
    verif.egal(avec({ periode = 1.9 }).periode, 10)
  end,

  un_delai_d_aller_retour_nul_est_accepte = function()
    local propre, erreurs = avec({ delai_aller_retour = 0, fenetre = 3600, sens = "conso", tout = false })
    verif.egal(erreurs, {})
    verif.egal(propre.delai_aller_retour, 0)
    verif.egal(propre.fenetre, 3600)
    verif.egal(propre.sens, "conso")
    verif.egal(propre.tout, false)
  end,

  une_exclusion_qui_n_est_pas_un_texte_non_vide_est_ecartee = function()
    local propre, erreurs = avec({ exclure = { "ae2:", "", 3, "minecraft:dirt" } })
    verif.egal(propre.exclure, { "ae2:", "minecraft:dirt" })
    verif.egal(#erreurs, 2)
    verif.vrai(contient(erreurs, "exclusion n°2 écartée"))
  end,

  un_nombre_nan_est_refuse = function()
    local propre, erreurs = avec({ periode = 0 / 0 })
    verif.egal(propre.periode, 10)
    verif.egal(#erreurs, 1)
  end,
}
