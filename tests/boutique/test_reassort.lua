-- Réassort : tampon d'abord, commande du reste moins ce qui est en route, délai, partage, tampon étranger intact.

local verif = require("verif")
local reassort = require("boutique.reassort")
local monde = require("boutique.monde")

local FER, OR, PIERRE = "minecraft:iron_ingot", "minecraft:gold_ingot", "minecraft:stone"
local REGLAGES = { reserve_defaut = 64, articles = {} }

local function vend(objet)
  return { indice = 1, objets = { { objet = objet, quantite = 1 } } }
end

local function plan(comptoirs, tampon, reseau, en_route, reglages)
  return reassort.planifier({ comptoirs = comptoirs, tampon = tampon, reseau = reseau, en_route = en_route or {},
    reglages = reglages or REGLAGES })
end

return {
  manque_est_tire_du_tampon_d_abord_puis_le_reste_commande = function()
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = { [FER] = 4 } } }, { [FER] = 20 }, { [FER] = 500 })
    verif.egal(p.tirages, { { comptoir = "a", objet = FER, nombre = 20 } })
    verif.egal(p.commandes, { { objet = FER, nombre = 40 } })
  end,

  ce_qui_est_en_route_est_deduit_de_la_commande = function()
    local en_route = {}
    reassort.ajouter(en_route, FER, 50, 0)
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = {} } }, {}, { [FER] = 500 }, en_route)
    verif.egal(p.commandes, { { objet = FER, nombre = 14 } })
  end,

  commande_bornee_au_stock_du_reseau = function()
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = {} } }, {}, { [FER] = 10 })
    verif.egal(p.commandes, { { objet = FER, nombre = 10 } })
  end,

  jamais_de_commande_si_le_stock_du_reseau_est_inconnu_ou_nul = function()
    local comptoirs = { { nom = "a", offres = { vend(FER), vend(OR) }, stockage = {} } }
    verif.egal(plan(comptoirs, {}, nil).commandes, {})
    verif.egal(plan(comptoirs, {}, { [FER] = 0 }).commandes, {})
  end,

  jamais_de_commande_de_moins_d_un_objet = function()
    local en_route = {}
    reassort.ajouter(en_route, FER, 64, 0)
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = {} } }, {}, { [FER] = 500 }, en_route)
    verif.egal(p.commandes, {})
  end,

  deux_comptoirs_se_partagent_le_tampon_dans_l_ordre_des_noms_et_une_seule_commande = function()
    local p = plan({ { nom = "b", offres = { vend(FER) }, stockage = {} }, { nom = "a", offres = { vend(FER) },
      stockage = { [FER] = 34 } } }, { [FER] = 40 }, { [FER] = 500 })
    verif.egal(p.tirages, { { comptoir = "a", objet = FER, nombre = 30 }, { comptoir = "b", objet = FER, nombre = 10 } })
    verif.egal(p.commandes, { { objet = FER, nombre = 54 } })
  end,

  objet_du_tampon_qu_aucun_comptoir_ne_vend_n_est_jamais_tire = function()
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = { [FER] = 64 } } }, { [PIERRE] = 64 }, {})
    verif.egal(p.tirages, {})
  end,

  comptoir_sans_stockage_lisible_est_ignore = function()
    local p = plan({ { nom = "a", offres = { vend(FER) } } }, { [FER] = 64 }, { [FER] = 64 })
    verif.egal(p, { tirages = {}, commandes = {} })
  end,

  reserve_de_l_article_remplace_la_reserve_par_defaut = function()
    local reglages = { reserve_defaut = 64, articles = { [FER] = { reserve = 10 } } }
    local p = plan({ { nom = "a", offres = { vend(FER) }, stockage = { [FER] = 4 } } }, { [FER] = 64 }, nil, nil,
      reglages)
    verif.egal(p.tirages, { { comptoir = "a", objet = FER, nombre = 6 } })
  end,

  commande_en_route_est_oubliee_apres_le_delai = function()
    local en_route = {}
    reassort.ajouter(en_route, FER, 10, 0)
    reassort.ajouter(en_route, FER, 5, 100)
    local garde = reassort.oublier(en_route, 120, 120)
    verif.egal(reassort.en_route(garde, FER), 5)
  end,

  objets_tires_du_tampon_reduisent_les_commandes_les_plus_anciennes = function()
    local en_route = {}
    reassort.ajouter(en_route, FER, 10, 0)
    reassort.ajouter(en_route, FER, 5, 1)
    reassort.deduire(en_route, FER, 12)
    verif.egal(en_route[FER], { { nombre = 3, instant = 1 } })
    reassort.deduire(en_route, FER, 50)
    verif.egal(en_route[FER], nil)
  end,

  -- Sur les faux : la livraison arrive au tampon, la passe suivante la tire et l'oublie des commandes en route.
  commande_livree_est_tiree_puis_n_est_plus_en_route = function()
    local m = monde.nouveau({}, nil, { [FER] = 500 })
    local c = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } }, prix = 5 } })
    m.passer(0)
    verif.egal(m.ticker.commandes, { { adresse = "Boutique", objet = FER, nombre = 64 } })
    m.passer(10)
    verif.egal(#m.ticker.commandes, 1, "rien de recommandé tant que la commande est en route")
    m.tampon.emplacements[1] = { name = FER, count = 64 }
    m.passer(20)
    verif.egal(c.stockage.compter(FER), 64)
    verif.egal(m.memoire.en_route, {})
  end,

  commande_non_arrivee_est_refaite_apres_le_delai = function()
    local m = monde.nouveau({}, { delai_commande = 120 }, { [FER] = 500 })
    m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } })
    m.passer(0)
    m.passer(119)
    verif.egal(#m.ticker.commandes, 1)
    m.passer(120)
    verif.egal(#m.ticker.commandes, 2)
  end,

  cible_pleine_ne_compte_que_ce_qui_a_vraiment_bouge = function()
    local m = monde.nouveau({ [3] = { name = FER, count = 64 } })
    m.reseau.piles[FER] = 16
    local c = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } }, 1,
      { [1] = { name = FER, count = 10 } })
    m.passer(0)
    verif.egal(c.stockage.compter(FER), 16)
    verif.egal(m.tampon.compter(FER), 58)
    verif.vrai(monde.contient(m.journal, "Réassort : 6 x " .. FER), table.concat(m.journal, "\n"))
  end,

  tampon_etranger_reste_intact_sur_les_faux = function()
    local m = monde.nouveau({ [1] = { name = PIERRE, count = 64 }, [2] = { name = FER, count = 64 } })
    local c = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } })
    m.passer(0)
    verif.egal(m.tampon.compter(PIERRE), 64)
    verif.egal(c.stockage.compter(FER), 64)
  end,

  sans_stock_ticker_le_tampon_suffit = function()
    local m = monde.nouveau({ [1] = { name = FER, count = 30 } })
    local c = m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } })
    local resultat = m.passer(0)
    verif.egal(c.stockage.compter(FER), 30)
    verif.egal(resultat.articles[1].usine, nil)
  end,

  tampon_illisible_bloque_les_commandes = function()
    local m = monde.nouveau({}, nil, { [FER] = 500 })
    m.tampon.panne = "No peripheral attached"
    m.comptoir("lc_trader_item_0", { { vend = { { name = FER, count = 1 } } } })
    local resultat = m.passer(0)
    verif.egal(m.ticker.commandes, {})
    verif.vrai(monde.contient(resultat.erreurs.tampon, "illisible"))
  end,
}
