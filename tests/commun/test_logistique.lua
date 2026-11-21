-- Lecture du stock et commande par le Stock Ticker : jamais d'erreur levée, jamais de commande vide.

local verif = require("verif")
local logistique = require("commun.logistique")
local faux = require("faux.create")

return {
  stock_additionne_les_variantes_d_un_meme_objet = function()
    local ticker = { stock = function()
      return { { name = "minecraft:iron_ingot", count = 100 }, { name = "minecraft:iron_ingot", count = 28, nbt = "a" },
        { name = "create:brass_ingot", count = 7 } }
    end }
    verif.egal(logistique.stock(ticker), { ["minecraft:iron_ingot"] = 128, ["create:brass_ingot"] = 7 })
  end,

  stock_ignore_les_entrees_mal_formees = function()
    local ticker = { stock = function() return { "x", { name = "a:b" }, { name = "a:c", count = 2 } } end }
    verif.egal(logistique.stock(ticker), { ["a:c"] = 2 })
  end,

  stock_d_un_ticker_absent_ou_en_panne_renvoie_nil_et_un_message = function()
    local quantites, message = logistique.stock(nil)
    verif.egal(quantites, nil)
    verif.vrai(message:find("absent", 1, true))
    local ticker = faux.ticker({})
    ticker.panne = "chunk déchargé"
    quantites, message = logistique.stock(ticker)
    verif.egal(quantites, nil)
    verif.vrai(message:find("chunk déchargé", 1, true))
  end,

  commande_passe_l_adresse_puis_un_filtre_par_nom_borne_par_la_quantite = function()
    local ticker = faux.ticker({ ["create:brass_ingot"] = 100 })
    verif.egal(logistique.commander(ticker, "Boutique", "create:brass_ingot", 64), 64)
    verif.egal(ticker.commandes, { { adresse = "Boutique", objet = "create:brass_ingot", nombre = 64 } })
  end,

  commande_renvoie_ce_que_le_reseau_peut_fournir = function()
    local ticker = faux.ticker({ ["create:brass_ingot"] = 10 })
    verif.egal(logistique.commander(ticker, "Boutique", "create:brass_ingot", 64), 10)
    verif.egal(logistique.commander(ticker, "Boutique", "create:brass_ingot", 64), 0)
  end,

  commande_sans_adresse_ou_sans_quantite_n_appelle_pas_le_ticker = function()
    local ticker = faux.ticker({ ["a:b"] = 10 })
    verif.egal(logistique.commander(ticker, "", "a:b", 5), nil)
    verif.egal(logistique.commander(ticker, "Boutique", "a:b", 0), nil)
    verif.egal(#ticker.commandes, 0)
    verif.egal(ticker.stock_reseau["a:b"], 10)
  end,

  commande_sur_un_ticker_en_panne_renvoie_nil_et_un_message = function()
    local ticker = faux.ticker({ ["a:b"] = 10 })
    ticker.panne = "No peripheral attached"
    local nombre, message = logistique.commander(ticker, "Boutique", "a:b", 5)
    verif.egal(nombre, nil)
    verif.vrai(message:find("No peripheral attached", 1, true))
  end,
}
