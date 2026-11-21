-- Banque en vraie monnaie contre de faux coffres et un faux lc_money : dépôts, encaissements, pannes, conservation.

local verif = require("verif")
local systeme = require("faux.systeme")
local coffre = require("faux.coffre")
local faux_lc = require("faux.lc_money")
local banque_monnaie = require("casino.banque")
local caisse = require("casino.caisse")
local monnaie = require("casino.monnaie")
local session = require("casino.session")
local defauts = require("casino.reglages")

local CUIVRE, FER, OR, EMERAUDE = "lightmanscurrency:coin_copper", "lightmanscurrency:coin_iron",
  "lightmanscurrency:coin_gold", "lightmanscurrency:coin_emerald"
local VALEURS = { [CUIVRE] = 1, [FER] = 10, [OR] = 100, [EMERAUDE] = 1000, ["lightmanscurrency:coin_diamond"] = 10000,
  ["lightmanscurrency:coin_netherite"] = 100000 }

local function copie(source)
  local resultat = {}
  for cle, valeur in pairs(source) do resultat[cle] = valeur end
  return resultat
end

-- Monde : coffres « depot », « sortie », « reserve » sur un réseau, faux lc_money, journal en mémoire, caisse en
-- mémoire couverte par la réserve. `options` : contenus et tailles des coffres, `sans_api`.
local function monde(options)
  options = options or {}
  systeme.installer()
  local m = { reseau = coffre.reseau(), journal = {}, fichier = { solde = options.solde or 0 } }
  m.depot = coffre.nouveau(m.reseau, "depot", options.taille_depot or 27, options.depot)
  m.sortie = coffre.nouveau(m.reseau, "sortie", options.taille_sortie or 27, options.sortie)
  m.reserve = coffre.nouveau(m.reseau, "reserve", options.taille_reserve or 54, options.reserve)
  peripheral = {
    wrap = function(nom) return m.reseau.inventaires[nom] end,
    getNames = function()
      local noms = {}
      for nom in pairs(m.reseau.inventaires) do noms[#noms + 1] = nom end
      return noms
    end,
    getType = function() return "minecraft:chest" end,
  }
  m.api = not options.sans_api and faux_lc.nouveau(copie(VALEURS)) or nil
  m.reglages = copie(defauts)
  m.reglages.depot, m.reglages.sortie, m.reglages.reserve = "depot", "sortie", "reserve"
  for cle, valeur in pairs(options.reglages or {}) do m.reglages[cle] = valeur end
  local trace = {
    info = function(texte) m.journal[#m.journal + 1] = "INFO " .. texte end,
    erreur = function(texte) m.journal[#m.journal + 1] = "ERREUR " .. texte end,
  }
  m.banque = banque_monnaie.ouvrir(m.reglages, m.api, trace)
  m.banque.verifier()
  m.caisse = caisse.ouvrir({ lire = function() return m.fichier end,
    ecrire = function(etat) m.fichier = etat; return true end },
    { depart = 0, recharge = 0, unite = "crédit", couverture = function() return m.banque.pret and m.banque.reserve end })
  function m.valeur_totale()
    local total = 0
    for _, c in ipairs({ m.depot, m.sortie, m.reserve }) do total = total + monnaie.valeur(c.emplacements, VALEURS) end
    return total
  end
  function m.journal_contient(motif)
    for _, ligne in ipairs(m.journal) do
      if ligne:find(motif, 1, true) then return true end
    end
    return false
  end
  return m
end

return {
  depot_credite_ce_qui_a_bouge_et_journalise = function()
    local m = monde({ depot = { [1] = { name = OR, count = 3 }, [5] = { name = FER, count = 5 } } })
    local credite, messages = m.banque.relever(m.caisse)
    verif.egal(credite, 350)
    verif.egal(messages, {})
    verif.egal(m.caisse.solde(), 350)
    verif.egal(m.depot.emplacements, {})
    verif.egal(m.banque.reserve, 350)
    verif.vrai(m.journal_contient("Dépôt : 3 x " .. OR .. " rangées"))
    verif.vrai(m.journal_contient("+300 crédits, solde 300"), table.concat(m.journal, " | "))
    verif.vrai(m.journal_contient("+50 crédits, solde 350"), table.concat(m.journal, " | "))
  end,

  reserve_pleine_rien_credite_au_dela_de_ce_qui_bouge = function()
    local m = monde({ taille_reserve = 1, reserve = { [1] = { name = OR, count = 62 } },
      depot = { [1] = { name = OR, count = 5 } } })
    local credite, messages = m.banque.relever(m.caisse)
    verif.egal(credite, 200)
    verif.egal(m.depot.compter(OR), 3)
    verif.vrai(messages[1]:find("Réserve pleine"), messages[1])
    local pleine = monde({ taille_reserve = 1, reserve = { [1] = { name = CUIVRE, count = 64 } },
      depot = { [1] = { name = OR, count = 2 } } })
    verif.egal((pleine.banque.relever(pleine.caisse)), 0)
    verif.egal(pleine.caisse.solde(), 0)
    verif.egal(pleine.depot.compter(OR), 2)
  end,

  objet_etranger_renvoye_vers_la_sortie_ou_laisse = function()
    local m = monde({ depot = { [2] = { name = "minecraft:dirt", count = 4 } } })
    local credite, messages = m.banque.relever(m.caisse)
    verif.egal(credite, 0)
    verif.egal(m.sortie.compter("minecraft:dirt"), 4)
    verif.vrai(messages[1]:find("rendu dans le coffre de sortie"), messages[1])
    local bouche = monde({ taille_sortie = 1, sortie = { [1] = { name = "minecraft:stone", count = 64 } },
      depot = { [1] = { name = "minecraft:dirt", count = 1 } } })
    local _, autres = bouche.banque.relever(bouche.caisse)
    verif.egal(bouche.depot.compter("minecraft:dirt"), 1)
    verif.vrai(autres[1]:find("reprends"), autres[1])
  end,

  encaissement_exact_plus_grosses_pieces_d_abord = function()
    local m = monde({ solde = 1250, reserve = { [1] = { name = EMERAUDE, count = 2 }, [2] = { name = OR, count = 5 },
      [3] = { name = FER, count = 10 }, [4] = { name = CUIVRE, count = 10 } } })
    local verse, message = m.banque.encaisser(m.caisse)
    verif.egal({ verse, message }, { 1250 })
    verif.egal(m.caisse.solde(), 0)
    verif.egal({ m.sortie.compter(EMERAUDE), m.sortie.compter(OR), m.sortie.compter(FER) }, { 1, 2, 5 })
  end,

  encaissement_partiel_faute_de_petites_pieces = function()
    local m = monde({ solde = 1255, reserve = { [1] = { name = EMERAUDE, count = 2 }, [2] = { name = OR, count = 5 },
      [3] = { name = FER, count = 9 } } })
    local verse, message = m.banque.encaisser(m.caisse)
    verif.egal(verse, 1250)
    verif.egal(m.caisse.solde(), 5)
    verif.vrai(message:find("Pas la monnaie exacte"), message)
  end,

  encaissement_partiel_faute_de_place_puis_repris = function()
    local m = monde({ solde = 1250, taille_sortie = 2, sortie = { [1] = { name = "minecraft:stone", count = 64 } },
      reserve = { [1] = { name = EMERAUDE, count = 2 }, [2] = { name = OR, count = 5 }, [3] = { name = FER, count = 9 } } })
    local verse, message = m.banque.encaisser(m.caisse)
    verif.egal(verse, 1000)
    verif.egal(m.caisse.solde(), 250)
    verif.vrai(message:find("Coffre de sortie plein"), message)
    verif.vrai(m.journal_contient("+200 crédits rendus au solde"), table.concat(m.journal, "\n"))
    m.sortie.emplacements = {}
    verif.egal({ m.banque.encaisser(m.caisse) }, { 250 })
    verif.egal(m.caisse.solde(), 0)
  end,

  solde_ecrit_avant_chaque_lot_et_panne_d_envoi_au_profit_de_la_maison = function()
    local m = monde({ solde = 300, reserve = { [1] = { name = OR, count = 5 } } })
    local ecritures = {}
    local origine = m.reserve.pushItems
    m.reserve.pushItems = function(...)
      ecritures[#ecritures + 1] = m.fichier.solde
      error("Target 'sortie' does not exist", 0)
    end
    local verse, message = m.banque.encaisser(m.caisse)
    verif.egal(ecritures, { 0 }, "le solde est écrit diminué avant l'envoi")
    verif.egal(verse, 0)
    verif.egal(m.caisse.solde(), 0)
    verif.vrai(message:find("admin"), message)
    verif.vrai(m.journal_contient("envoi incertain de 3 x " .. OR), table.concat(m.journal, "\n"))
    m.reserve.pushItems = origine
  end,

  panne_ou_coffre_absent_suspend_le_jeu_avec_le_nom = function()
    local m = monde({ depot = { [1] = { name = OR, count = 1 } } })
    m.depot.panne = "chunk déchargé"
    verif.egal((m.banque.relever(m.caisse)), 0)
    verif.egal(m.banque.pret, false)
    verif.vrai(m.banque.probleme:find("chunk déchargé"), m.banque.probleme)
    m.depot.panne = nil
    m.reseau.inventaires.reserve = nil
    verif.egal(m.banque.verifier(), false)
    verif.vrai(m.banque.probleme:find("réserve « reserve » introuvable", 1, true), m.banque.probleme)
    verif.vrai(m.banque.probleme:find("Visibles : depot (minecraft:chest)", 1, true), m.banque.probleme)
    verif.egal(m.caisse.miser(1, 0, 99), false)
    m.reseau.inventaires.reserve = m.reserve
    verif.egal(m.banque.verifier(), true)
  end,

  sans_lc_money_ou_reglage_vide_rien_ne_s_ouvre = function()
    local m = monde({ sans_api = true })
    verif.egal(m.banque.pret, false)
    verif.vrai(m.banque.probleme:find("lc_money"), m.banque.probleme)
    local vide = monde({ reglages = { depot = "" } })
    verif.vrai(vide.banque.probleme:find("réglage depot vide"), vide.banque.probleme)
  end,

  valeurs_changees_par_le_serveur_entre_deux_lectures = function()
    local m = monde({ reserve = { [1] = { name = OR, count = 10 } }, depot = { [1] = { name = OR, count = 1 } } })
    verif.egal(m.banque.reserve, 1000)
    m.api.valeurs[OR] = 50
    verif.egal(m.banque.lire_valeurs(), true)
    m.banque.verifier()
    verif.egal(m.banque.reserve, 500)
    verif.egal((m.banque.relever(m.caisse)), 50)
    verif.vrai(m.journal_contient("or = 50"), table.concat(m.journal, "\n"))
  end,

  aucune_valeur_creee_ni_detruite_et_solde_toujours_couvert = function()
    local m = monde({ reserve = { [1] = { name = EMERAUDE, count = 20 }, [2] = { name = OR, count = 30 },
      [3] = { name = FER, count = 50 }, [4] = { name = CUIVRE, count = 64 } },
      depot = { [1] = { name = OR, count = 4 }, [2] = { name = FER, count = 7 } } })
    local total = m.valeur_totale()
    m.banque.relever(m.caisse)
    verif.egal(m.valeur_totale(), total)
    local graine = 7
    local ctx = { caisse = m.caisse, maintenant = 0, inactivite = 90, hasard = function(n)
      graine = (48271 * graine) % 2147483647
      return graine % n + 1
    end }
    local etat = session.nouvelle(m.reglages, m.caisse.solde())
    etat.monnaie = { pret = true, reserve = m.banque.reserve }
    session.agir(etat, { type = "ouvrir", jeu = "machine" }, ctx)
    for _ = 1, 200 do
      session.agir(etat, { type = "jouer" }, ctx)
      ctx.maintenant = ctx.maintenant + 3
      session.avancer(etat, ctx)
      verif.vrai(m.caisse.solde() <= m.banque.reserve, "solde non couvert : " .. m.caisse.solde())
    end
    m.banque.encaisser(m.caisse)
    verif.egal(m.valeur_totale(), total)
    verif.egal(m.caisse.solde(), 0, "la réserve variée rend tout le solde")
    verif.vrai(m.caisse.solde() <= m.banque.reserve)
  end,
}
