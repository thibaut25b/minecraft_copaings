-- Lecture des offres : case vide et offre d'achat ignorées, formes inattendues en ligne d'erreur sans lever.

local verif = require("verif")
local offres = require("boutique.offres")
local coffre = require("faux.coffre")
local faux_comptoir = require("faux.comptoir")

local FER, OR = "minecraft:iron_ingot", "minecraft:gold_ingot"

local function comptoir(definitions)
  return faux_comptoir.nouveau(coffre.reseau(), "lc_trader_item_0", definitions)
end

return {
  offre_de_vente_est_lue_avec_indice_objets_et_prix = function()
    local liste, erreurs = offres.lire(comptoir({ { vend = { { name = FER, count = 4 } }, prix = 12 } }))
    verif.egal(#liste, 1)
    verif.egal(liste[1].indice, 1)
    verif.egal(liste[1].objets, { { objet = FER, quantite = 4 } })
    verif.egal(liste[1].prix, 12)
    verif.egal(liste[1].texte, "12c")
    verif.egal(erreurs, {})
  end,

  case_vide_est_ignoree_et_deux_objets_sont_lus = function()
    local liste = offres.lire(comptoir({ { vend = { { name = FER, count = 1 }, { name = OR, count = 2 } } },
      { vend = {} } }))
    verif.egal(#liste, 1)
    verif.egal(liste[1].objets, { { objet = FER, quantite = 1 }, { objet = OR, quantite = 2 } })
  end,

  offre_d_achat_est_ignoree = function()
    local liste = offres.lire(comptoir({ { vend = { { name = FER, count = 1 } }, achat = true },
      { vend = { { name = OR, count = 1 } } } }))
    verif.egal(#liste, 1)
    verif.egal(liste[1].indice, 2)
  end,

  forme_inattendue_donne_une_ligne_d_erreur_et_les_autres_offres_restent = function()
    local c = comptoir({ { vend = { { name = FER, count = 1 } } }, { vend = { { name = OR, count = 1 } } } })
    c.offres[1].getSellItems = function() return "bizarre" end
    c.offres[2].getPrice = function() return 42 end
    local liste, erreurs = offres.lire(c)
    verif.egal(#liste, 1)
    verif.egal(liste[1].prix, nil)
    verif.vrai(erreurs[1]:find("getSellItems illisible (string)", 1, true), erreurs[1])
  end,

  get_trades_illisible_renvoie_nil_et_un_message = function()
    local c = comptoir({})
    c.getTrades = function() return nil end
    local liste, message = offres.lire(c)
    verif.egal(liste, nil)
    verif.vrai(message:find("illisible", 1, true))
    local en_panne = comptoir({})
    en_panne.panne = "No peripheral attached"
    verif.vrai(select(2, offres.lire(en_panne)):find("No peripheral attached", 1, true))
  end,
}
