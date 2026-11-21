-- Bout en bout : le point d'entrée tourne quelques tours contre les faux périphériques, sans jamais lever.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local coffre = require("faux.coffre")
local faux_comptoir = require("faux.comptoir")
local faux_create = require("faux.create")
local faux_moniteur = require("faux.moniteur")

local depaqueter = table.unpack or unpack

local FER, OR = "minecraft:iron_ingot", "minecraft:gold_ingot"
local TAMPON = "minecraft:chest_0"

-- Monde par défaut : un comptoir qui vend du fer (prix 5, réglé à 12), 20 fers dans le tampon, 500 dans l'usine.
local function monde(reglages)
  local m = { disque = systeme.installer(), reseau = coffre.reseau(), file = {}, minuteurs = 0, horloge = 0,
    terminal = faux_moniteur.nouveau(51, 19), noms = {} }
  m.disque.disque["boutique.cfg"] = textutils.serialize(reglages or { tampon = TAMPON,
    articles = { [FER] = { prix = 12, nom = "Lingot de fer" } } })
  m.tampon = coffre.nouveau(m.reseau, TAMPON, 27, { [1] = { name = FER, count = 20 } })
  m.ticker = faux_create.ticker({ [FER] = 500, [OR] = 40 })
  m.comptoirs = { faux_comptoir.nouveau(m.reseau, "lc_trader_item_0", { { vend = { { name = FER, count = 4 } },
    prix = 5 }, { vend = { { name = OR, count = 1 } }, prix = 30 } }) }
  m.moniteur = faux_moniteur.nouveau(60, 24)
  m.moniteur.setTextScale = function() end
  return m
end

-- Lance le point d'entrée : chaque boucle est une coroutine, reprise à chaque tour avec l'événement du tour :
-- `evenements(tour)` s'il en donne un, sinon le premier de la file (os.queueEvent), sinon un événement neutre.
local function lancer(m, tours, evenements)
  local presents = { lc_trader_item = m.comptoirs or {}, Create_StockTicker = { m.ticker },
    monitor = { m.moniteur } }
  for _, c in ipairs(m.comptoirs or {}) do m.noms[c] = c.nom end
  peripheral = {
    find = function(type_voulu) return depaqueter(presents[type_voulu] or {}) end,
    getName = function(objet) return m.noms[objet] end,
    wrap = function(nom) return m.reseau.inventaires[nom] end,
    getNames = function() return { TAMPON } end,
    getType = function() return "minecraft:chest" end,
  }
  term = { current = function() return m.terminal end }
  textutils.formatTime = function() return "12:30" end
  os.time = function() return 12.5 end
  os.clock = function() return m.horloge end
  os.getComputerID = function() return 7 end
  os.startTimer = function()
    m.minuteurs = m.minuteurs + 1
    return m.minuteurs
  end
  os.queueEvent = function(...) m.file[#m.file + 1] = { ... } end
  os.pullEvent = function() return coroutine.yield() end
  parallel = { waitForAny = function(...)
    local boucles = {}
    for i, fonction in ipairs({ ... }) do boucles[i] = coroutine.create(fonction) end
    for tour = 0, tours do
      local evenement = (evenements and evenements(tour)) or table.remove(m.file, 1) or { "rien" }
      for _, boucle in ipairs(boucles) do
        local ok, erreur = coroutine.resume(boucle, depaqueter(evenement))
        if not ok then error(erreur, 0) end
      end
    end
  end }
  assert(loadfile("projets/boutique/principal.lua"))()
end

local function ecran(m)
  return (m.moniteur or m.terminal).texte()
end

local function comptes(m)
  return textutils.unserialize(m.disque.disque["boutique.ventes"])
end

return {
  passe_reassortit_commande_le_reste_regle_le_prix_et_affiche = function()
    local m = monde()
    lancer(m, 3)
    local c = m.comptoirs[1]
    verif.egal(c.stockage.compter(FER), 20)
    verif.egal(m.ticker.commandes, { { adresse = "Boutique", objet = OR, nombre = 40 },
      { adresse = "Boutique", objet = FER, nombre = 44 } })
    verif.egal(c.offres[1].prix, 12)
    verif.vrai(ecran(m):find("Lingot de fer", 1, true), ecran(m))
    verif.vrai(m.disque.disque["boutique.cfg"] ~= nil)
  end,

  vente_est_comptee_persistee_journalisee_et_relance_une_passe = function()
    local m = monde()
    local lectures = 0
    local origine = m.comptoirs[1].getTrades
    m.comptoirs[1].getTrades = function() lectures = lectures + 1 return origine() end
    lancer(m, 8, function(tour) if tour == 2 then return m.comptoirs[1].evenement(1, "Alice") end end)
    verif.egal(lectures, 2, "la vente relance une passe sans attendre la période")
    local lu = comptes(m)
    verif.egal(lu.recette, 12)
    verif.egal(lu.articles[FER], { ventes = 1, vendus = 4, recette = 12 })
    verif.egal(lu.dernieres[1].joueur, "Alice")
    verif.vrai(m.disque.disque["boutique.log"]:find("Vente : Alice", 1, true))
    verif.vrai(ecran(m):find("Alice", 1, true), ecran(m))
  end,

  comptes_survivent_au_redemarrage = function()
    local m = monde()
    lancer(m, 6, function(tour) if tour == 2 then return m.comptoirs[1].evenement(1, "Alice") end end)
    lancer(m, 6, function(tour) if tour == 2 then return m.comptoirs[1].evenement(2, "Bob") end end)
    local lu = comptes(m)
    verif.egal(lu.recette, 42)
    verif.egal(#lu.dernieres, 2)
    verif.vrai(ecran(m):find("Recette 42", 1, true), ecran(m))
  end,

  fichier_de_ventes_illisible_est_mis_de_cote_et_signale = function()
    local m = monde()
    m.disque.disque["boutique.ventes"] = "{{{ pas du lua"
    lancer(m, 2)
    verif.egal(m.disque.disque["boutique.ventes.illisible-0"], "{{{ pas du lua")
    verif.vrai(ecran(m):find("illisible", 1, true), ecran(m))
  end,

  indice_de_l_evenement_est_0_based = function()
    local m = monde()
    lancer(m, 6, function(tour)
      if tour == 2 then
        local evenement = m.comptoirs[1].evenement(2, "Bob")
        evenement[4] = nil
        return evenement
      end
    end)
    verif.egal(comptes(m).articles[OR], { ventes = 1, vendus = 1, recette = 30 })
  end,

  sans_aucun_peripherique_rien_ne_leve_et_le_terminal_explique = function()
    local m = monde({})
    m.comptoirs, m.ticker, m.moniteur = {}, nil, nil
    m.reseau.inventaires[TAMPON] = nil
    lancer(m, 4)
    local texte = m.terminal.texte()
    verif.vrai(texte:find("Aucun comptoir", 1, true), texte)
    verif.vrai(texte:find("tampon vide", 1, true), texte)
  end,

  stock_ticker_en_panne_est_signale_et_le_tampon_sert_quand_meme = function()
    local m = monde()
    m.ticker.panne = "Stock Ticker déchargé"
    lancer(m, 3)
    verif.egal(m.comptoirs[1].stockage.compter(FER), 20)
    verif.vrai(ecran(m):find("Stock Ticker", 1, true), ecran(m))
  end,

  toucher_la_pagination_change_de_page = function()
    local m = monde()
    local definitions = {}
    for i = 1, 20 do definitions[i] = { vend = { { name = "mod:objet_" .. string.format("%02d", i), count = 1 } } } end
    m.comptoirs = { faux_comptoir.nouveau(m.reseau, "lc_trader_item_0", definitions) }
    m.moniteur = faux_moniteur.nouveau(51, 19)
    m.moniteur.setTextScale = function() end
    lancer(m, 4, function(tour)
      if tour == 3 then
        local x, y = m.moniteur.chercher(string.char(16))
        return { "monitor_touch", "top", x, y }
      end
    end)
    verif.vrai(ecran(m):find("2 / ", 1, true), ecran(m))
  end,
}
