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
    verif.egal(propre.periode, 2)
    verif.egal(propre.unite, "min")
    verif.egal(propre.coffre, "")
    verif.egal(propre.objets, {})
  end,

  objet_valide_recoit_un_nom_vide_par_defaut = function()
    local propre = avec({ objets = { { objet = "minecraft:iron_ingot" },
      { objet = "minecraft:gold_ingot", nom = "Or" } } })
    verif.egal(propre.objets, { { objet = "minecraft:iron_ingot", nom = "" },
      { objet = "minecraft:gold_ingot", nom = "Or" } })
  end,

  objet_fautif_est_ecarte_et_les_autres_gardes = function()
    local propre, erreurs = avec({ objets = { { nom = "Sans id" }, "texte", { objet = "a:b", nom = 3 },
      { objet = "minecraft:iron_ingot" } } })
    verif.egal(propre.objets, { { objet = "minecraft:iron_ingot", nom = "" } })
    verif.vrai(contient(erreurs, "objet n°1 écarté : objet manquant"), erreurs[1])
    verif.vrai(contient(erreurs, "objet n°2 écarté : n'est pas une table"))
    verif.vrai(contient(erreurs, "objet a:b écarté : nom doit être un texte"))
  end,

  un_doublon_est_ecarte_et_signale = function()
    local propre, erreurs = avec({ objets = { { objet = "a:b", nom = "Premier" }, { objet = "a:b", nom = "Second" } } })
    verif.egal(propre.objets, { { objet = "a:b", nom = "Premier" } })
    verif.vrai(contient(erreurs, "objet a:b écarté : déjà suivi"))
  end,

  valeurs_hors_bornes_retombent_sur_les_defauts = function()
    local propre, erreurs = avec({ periode = 0, echelle_texte = 9, theme = "rose", unite = "jour",
      duree_historique = -5, duree_graphe = "long", pont = 3, coffre = 4, objets = "pas une liste" })
    verif.egal(propre.periode, 2)
    verif.egal(propre.echelle_texte, 0.5)
    verif.egal(propre.theme, "nuit")
    verif.egal(propre.unite, "min")
    verif.egal(propre.duree_historique, 3600)
    verif.egal(propre.duree_graphe, 600)
    verif.egal(propre.pont, "")
    verif.egal(propre.coffre, "")
    verif.egal(propre.objets, {})
    verif.egal(#erreurs, 9)
  end,

  un_nombre_nan_est_refuse = function()
    local propre, erreurs = avec({ periode = 0 / 0 })
    verif.egal(propre.periode, 2)
    verif.egal(#erreurs, 1)
  end,

  un_graphe_plus_long_que_l_historique_est_ramene_a_l_historique = function()
    local propre, erreurs = avec({ duree_historique = 300, duree_graphe = 900 })
    verif.egal(propre.duree_graphe, 300)
    verif.vrai(contient(erreurs, "duree_graphe dépasse duree_historique"))
  end,
}
