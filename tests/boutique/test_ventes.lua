-- Comptes des ventes : cumul par article, recette totale, dernières ventes bornées, montant illisible à 0.

local verif = require("verif")
local ventes = require("boutique.ventes")

local FER, OR = "minecraft:iron_ingot", "minecraft:gold_ingot"

local function vente(joueur, objet, quantite, montant)
  return { joueur = joueur, objets = { { objet = objet, quantite = quantite } }, montant = montant, heure = "12:00" }
end

return {
  ventes_se_cumulent_par_article_et_en_recette_totale = function()
    local etat = ventes.charger(nil)
    ventes.enregistrer(etat, vente("Alice", FER, 4, 12), 50)
    ventes.enregistrer(etat, vente("Bob", FER, 4, 12), 50)
    ventes.enregistrer(etat, vente("Bob", OR, 1, 30), 50)
    verif.egal(etat.recette, 54)
    verif.egal(etat.articles[FER], { ventes = 2, vendus = 8, recette = 24 })
    verif.egal(etat.dernieres[1].joueur, "Bob")
    verif.egal(etat.dernieres[1].objet, OR)
  end,

  seules_les_dernieres_ventes_reglees_sont_gardees = function()
    local etat = ventes.charger(nil)
    for i = 1, 5 do ventes.enregistrer(etat, vente("J" .. i, FER, 1, 1), 3) end
    verif.egal(#etat.dernieres, 3)
    verif.egal(etat.dernieres[1].joueur, "J5")
    verif.egal(etat.articles[FER].ventes, 5, "le cumul compte toutes les ventes")
  end,

  offre_a_deux_objets_compte_les_deux_et_la_recette_va_au_premier = function()
    local etat = ventes.charger(nil)
    ventes.enregistrer(etat, { joueur = "A", objets = { { objet = FER, quantite = 1 }, { objet = OR, quantite = 2 } },
      montant = 10 }, 50)
    verif.egal(etat.articles[FER].recette, 10)
    verif.egal(etat.articles[OR], { ventes = 1, vendus = 2, recette = 0 })
  end,

  montant_illisible_vaut_zero = function()
    verif.egal(ventes.montant({ numeric = 25, text = "25c" }), 25)
    verif.egal(ventes.montant(nil), 0)
    verif.egal(ventes.montant({ text = "?" }), 0)
  end,

  comptes_de_mauvaise_forme_repartent_de_zero = function()
    verif.egal(ventes.charger({ recette = "beaucoup" }), { recette = 0, articles = {}, dernieres = {} })
    local bon = { recette = 3, articles = { [FER] = { ventes = 1, vendus = 1, recette = 3 } }, dernieres = {} }
    verif.egal(ventes.charger(bon), bon)
  end,
}
