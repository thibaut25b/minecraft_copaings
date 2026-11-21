-- Validation de la config : entrées fautives écartées avec leur message, le reste gardé.

local verif = require("verif")
colors = require("faux.couleurs")
local validation = require("usine.validation")
local defauts = require("usine.reglages")

local function avec(reglages)
  local complet = {}
  for cle, valeur in pairs(defauts) do complet[cle] = valeur end
  for cle, valeur in pairs(reglages) do complet[cle] = valeur end
  return validation.valider(complet, defauts)
end

local function ligne(nom, champs)
  local l = { nom = nom, produit = "create:iron_sheet", mini = 10, maxi = 20, relais = "relais_0", cote = "back" }
  for cle, valeur in pairs(champs or {}) do l[cle] = valeur end
  return l
end

local function contient(erreurs, motif)
  for _, message in ipairs(erreurs) do
    if message:find(motif, 1, true) then return true end
  end
  return false
end

return {
  defauts_sont_valides_et_forment_le_reseau_principal = function()
    local propre, erreurs = avec({})
    verif.egal(erreurs, {})
    verif.egal(propre.reseaux, { { nom = "Principal" } })
    verif.egal(propre.lignes, {})
  end,

  ligne_valide_recoit_ses_defauts_et_le_premier_reseau = function()
    local propre = avec({ lignes = { ligne("Presse") } })
    verif.egal(propre.lignes[1], { nom = "Presse", produit = "create:iron_sheet", mini = 10, maxi = 20,
      relais = "relais_0", cote = "back", signal_coupe = true, reseau = "Principal", priorite = 1 })
  end,

  ligne_a_champ_manquant_est_ecartee_et_les_autres_gardees = function()
    local propre, erreurs = avec({ lignes = { ligne("A", { produit = "" }), ligne("B", { cote = "top" }) } })
    verif.egal(#propre.lignes, 1)
    verif.egal(propre.lignes[1].nom, "B")
    verif.vrai(contient(erreurs, "ligne A écartée : produit manquant"), erreurs[1])
  end,

  ligne_avec_mini_au_dessus_de_maxi_est_ecartee = function()
    local propre, erreurs = avec({ lignes = { ligne("A", { mini = 30 }) } })
    verif.egal(propre.lignes, {})
    verif.vrai(contient(erreurs, "mini > maxi"))
  end,

  ligne_au_cote_inconnu_est_ecartee = function()
    local propre, erreurs = avec({ lignes = { ligne("A", { cote = "dessus" }) } })
    verif.egal(propre.lignes, {})
    verif.vrai(contient(erreurs, "côté inconnu : dessus"))
  end,

  deux_lignes_sur_la_meme_sortie_la_seconde_est_ecartee = function()
    local propre, erreurs = avec({ lignes = { ligne("A"), ligne("B"), ligne("C", { cote = "left" }) } })
    verif.egal(#propre.lignes, 2)
    verif.egal(propre.lignes[2].nom, "C")
    verif.vrai(contient(erreurs, "ligne B écartée : même sortie que la ligne A"))
  end,

  ligne_au_reseau_inconnu_ou_a_priorite_invalide_est_ecartee = function()
    local propre, erreurs = avec({
      reseaux = { { nom = "Nord", stressometre = "s0" } },
      lignes = { ligne("A", { reseau = "Sud" }), ligne("B", { priorite = 0, cote = "top" }),
        ligne("C", { reseau = "Nord", cote = "left" }) },
    })
    verif.egal(#propre.lignes, 1)
    verif.egal(propre.lignes[1].reseau, "Nord")
    verif.vrai(contient(erreurs, "réseau inconnu : Sud"))
    verif.vrai(contient(erreurs, "priorite"))
  end,

  reseau_sans_stressometre_est_ecarte_speedometre_vide_veut_dire_aucun = function()
    local propre, erreurs = avec({ reseaux = { { nom = "A" }, { nom = "B", stressometre = "s1", speedometre = "" } } })
    verif.egal(propre.reseaux, { { nom = "B", stressometre = "s1", speedometre = false } })
    verif.vrai(contient(erreurs, "réseau A écarté : stressometre manquant"))
  end,

  stock_fautif_est_ecarte = function()
    local propre, erreurs = avec({ stocks = { { nom = "Rails", objet = "create:track", seuil = 200 },
      { nom = "Vide", seuil = 5 } } })
    verif.egal(propre.stocks, { { nom = "Rails", objet = "create:track", seuil = 200 } })
    verif.vrai(contient(erreurs, "stock Vide écarté : objet manquant"))
  end,

  reglages_simples_fautifs_retombent_sur_les_defauts = function()
    local propre, erreurs = avec({ periode = -1, theme = "rose", seuil_reprise = 0.99, lignes = "pas une liste" })
    verif.egal(propre.periode, 5)
    verif.egal(propre.theme, "nuit")
    verif.egal({ propre.seuil_delestage, propre.seuil_reprise }, { 0.95, 0.80 })
    verif.egal(propre.lignes, {})
    verif.egal(#erreurs, 4)
  end,
}
