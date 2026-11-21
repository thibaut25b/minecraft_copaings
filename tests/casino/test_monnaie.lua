-- Calculs purs de la vraie monnaie : valeur, rendu en pièces, équivalent affiché, couverture et mise maximale.

local verif = require("verif")
local monnaie = require("casino.monnaie")

local VALEURS = { cuivre = 1, fer = 10, ["or"] = 100, emeraude = 1000 }
local PIECES = { { id = "cuivre", nom = "cuivre" }, { id = "fer", nom = "fer" }, { id = "or", nom = "or" },
  { id = "emeraude", nom = "émeraude" } }

return {
  valeur_et_stock_ignorent_les_objets_sans_valeur = function()
    local contenu = { [1] = { name = "or", count = 3 }, [4] = { name = "terre", count = 64 },
      [9] = { name = "or", count = 2 }, [2] = { name = "cuivre", count = 7 } }
    verif.egal(monnaie.valeur(contenu, VALEURS), 507)
    verif.egal(monnaie.stock(contenu, VALEURS), { ["or"] = 5, cuivre = 7 })
  end,

  rendu_plus_grosses_pieces_d_abord_sans_limite = function()
    local lots, total = monnaie.rendu(1250, nil, VALEURS)
    verif.egal(lots, { { piece = "emeraude", nombre = 1 }, { piece = "or", nombre = 2 }, { piece = "fer", nombre = 5 } })
    verif.egal(total, 1250)
  end,

  rendu_limite_par_le_stock_descend_aux_petites_pieces = function()
    local lots, total = monnaie.rendu(1250, { emeraude = 0, ["or"] = 3, fer = 100, cuivre = 0 }, VALEURS)
    verif.egal(lots, { { piece = "or", nombre = 3 }, { piece = "fer", nombre = 95 } })
    verif.egal(total, 1250)
  end,

  rendu_montant_impossible_rend_le_maximum_en_dessous = function()
    local lots, total = monnaie.rendu(1255, { emeraude = 2, ["or"] = 5, fer = 9 }, VALEURS)
    verif.egal(total, 1250)
    verif.egal(#lots, 3)
    local _, rien = monnaie.rendu(7, { fer = 3 }, VALEURS)
    verif.egal(rien, 0)
  end,

  decrire_donne_l_equivalent_et_le_reste_en_credits = function()
    verif.egal(monnaie.decrire(1250, PIECES, VALEURS), "1 émeraude 2 or 5 fer")
    verif.egal(monnaie.decrire(0, PIECES, VALEURS), "0")
    verif.egal(monnaie.decrire(15, PIECES, { fer = 10 }), "1 fer 5 crédits")
  end,

  couverture_et_mise_maximale = function()
    verif.vrai(monnaie.couvre(10000, 100, 9900))
    verif.vrai(not monnaie.couvre(10000, 100, 9901))
    verif.vrai(not monnaie.couvre(nil, 0, 0), "réserve illisible : rien n'est couvert")
    verif.egal(monnaie.mise_max(10000, 100, 99), 100)
    verif.egal(monnaie.mise_max(50, 100, 2), 0)
    verif.egal(monnaie.mise_max(nil, 0, 2), 0)
  end,
}
