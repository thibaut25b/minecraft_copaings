-- Prix et permissions : prix réglé, déjà bon, refus sans martelage, openStorage absente sans bloquer les autres.

local verif = require("verif")
local prix = require("boutique.prix")
local monde = require("boutique.monde")

local FER, OR = "minecraft:iron_ingot", "minecraft:gold_ingot"
local CUIVRE = "lightmanscurrency:coin_copper"

local function un_comptoir(prix_offre, articles)
  local m = monde.nouveau({ [1] = { name = FER, count = 64 } }, { articles = articles })
  local c = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } }, prix = prix_offre } })
  return m, c
end

return {
  valeur_de_prix_suit_le_format_de_lightmans = function()
    verif.egal(prix.valeur(12, CUIVRE), "coin;12-lightmanscurrency:coin_copper")
  end,

  prix_regle_qui_differe_est_pose_sur_l_offre = function()
    local m, c = un_comptoir(5, { [FER] = { prix = 12 } })
    m.passer(0)
    verif.egal(c.prix_regles, { "coin;12-lightmanscurrency:coin_copper" })
    verif.egal(c.offres[1].prix, 12)
  end,

  prix_deja_bon_n_appelle_pas_set_price = function()
    local m, c = un_comptoir(12, { [FER] = { prix = 12 } })
    local appels = 0
    c.offres[1].setPrice = function() appels = appels + 1 return true end
    m.passer(0)
    verif.egal(appels, 0)
  end,

  article_sans_prix_garde_le_prix_de_l_offre = function()
    local m, c = un_comptoir(7, {})
    m.passer(0)
    verif.egal(c.prix_regles, {})
  end,

  refus_donne_le_message_editTrades_et_n_est_pas_retente_tant_que_rien_ne_change = function()
    local m, c = un_comptoir(5, { [FER] = { prix = 12 } })
    c.permissions.editTrades = 0
    local appels = 0
    local origine = c.offres[1].setPrice
    c.offres[1].setPrice = function(valeur) appels = appels + 1 return origine(valeur) end
    local premier = m.passer(0)
    local second = m.passer(10)
    verif.egal(appels, 1)
    local attendu = "donne la permission editTrades à computercraft#7 sur lc_trader_item_0"
    verif.vrai(monde.contient(premier.erreurs.prix, attendu))
    verif.vrai(monde.contient(second.erreurs.prix, attendu), "le message reste tant que le refus dure")
    verif.egal(c.stockage.compter(FER), 64, "le refus ne bloque pas le réassort")
    m.reglages.articles[FER].prix = 13
    c.permissions.editTrades = 1
    local troisieme = m.passer(20)
    verif.egal(appels, 2, "un nouveau prix voulu est retenté")
    verif.egal(troisieme.erreurs.prix, {})
  end,

  sans_openStorage_le_message_s_affiche_et_les_autres_comptoirs_continuent = function()
    local m = monde.nouveau({ [1] = { name = FER, count = 64 }, [2] = { name = OR, count = 64 } })
    local ferme = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } })
    local ouvert = m.comptoir("lc_trader_item_1", { { vend = { { name = OR, count = 1 } } } })
    ferme.permissions.openStorage = 0
    local resultat = m.passer(0)
    verif.vrai(monde.contient(resultat.erreurs.comptoirs,
      "donne la permission openStorage à computercraft#7 sur lc_trader_item_0"))
    verif.egal(ouvert.stockage.compter(OR), 64)
    verif.egal(m.tampon.compter(FER), 64)
    for _, article in ipairs(resultat.articles) do
      if article.objet == FER then verif.egal(article.comptoir, nil, "stock inconnu du comptoir fermé") end
    end
  end,

  comptoir_en_panne_ne_leve_pas = function()
    local m, c = un_comptoir(5, { [FER] = { prix = 12 } })
    c.panne = "No peripheral attached"
    local resultat = m.passer(0)
    verif.vrai(#resultat.erreurs.comptoirs >= 1)
    verif.egal(m.tampon.compter(FER), 64)
  end,
}
