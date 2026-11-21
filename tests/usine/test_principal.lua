-- Bout en bout : le point d'entrée tourne quelques tours contre les faux périphériques, sans jamais lever.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local faux = require("faux.create")
local faux_moniteur = require("faux.moniteur")
local vers_cc = require("commun.texte").vers_cc

local depaqueter = table.unpack or unpack

local TYPES = {
  ticker_0 = "Create_StockTicker", stress_0 = "Create_Stressometer", vitesse_0 = "Create_Speedometer",
  relais_0 = "redstone_relay", energie_0 = "redstone_relay", monitor_0 = "monitor",
}

local function ligne(nom, champs)
  local l = { nom = nom, produit = "create:iron_sheet", mini = 100, maxi = 500, relais = "relais_0", cote = "back" }
  for cle, valeur in pairs(champs or {}) do l[cle] = valeur end
  return l
end

-- Monde par défaut : un Stock Ticker (300 plaques), un réseau à 50 %, un relais, un moniteur 100x38, une ligne.
local function monde(reglages)
  local m = { disque = systeme.installer(), terminal = faux_moniteur.nouveau(51, 19) }
  m.presents = {
    ticker_0 = faux.ticker({ ["create:iron_sheet"] = 300 }), stress_0 = faux.stressometre(8192, 16384),
    vitesse_0 = faux.speedometre(64), relais_0 = faux.relais(), monitor_0 = faux_moniteur.nouveau(100, 38),
  }
  m.presents.monitor_0.setTextScale = function() end
  m.disque.disque["usine.cfg"] = textutils.serialize(reglages or { lignes = { ligne("Presse") } })
  return m
end

local function ecran(m)
  return m.presents.monitor_0 or m.terminal
end

-- Lance le point d'entrée : chaque boucle est une coroutine reprise `tours` fois ; `evenements(tour)` donne
-- l'événement de ce tour (un simple rafraîchissement sinon), appelé au moment du tour.
local function lancer(m, tours, evenements, saboter)
  peripheral = {
    find = function(type_voulu)
      local noms = {}
      for nom in pairs(m.presents) do
        if TYPES[nom] == type_voulu then noms[#noms + 1] = nom end
      end
      table.sort(noms)
      return noms[1] and m.presents[noms[1]] or nil
    end,
    wrap = function(nom) return m.presents[nom] end,
    getNames = function()
      local noms = {}
      for nom in pairs(m.presents) do noms[#noms + 1] = nom end
      table.sort(noms)
      return noms
    end,
    getType = function(nom) return m.presents[nom] and TYPES[nom] or nil end,
  }
  term = { current = function() return m.terminal end }
  textutils.formatTime = function() return "12:30" end
  os.time = function() return 12.5 end
  os.queueEvent = function() end
  os.pullEvent = function() return coroutine.yield() end
  sleep = function() coroutine.yield() end
  if saboter then saboter() end
  parallel = { waitForAny = function(...)
    local boucles = {}
    for i, fonction in ipairs({ ... }) do boucles[i] = coroutine.create(fonction) end
    for tour = 0, tours do
      local evenement = (evenements and evenements(tour)) or { "usine_affichage" }
      for _, boucle in ipairs(boucles) do
        local ok, erreur = coroutine.resume(boucle, depaqueter(evenement))
        if not ok then error(erreur, 0) end
      end
    end
  end }
  assert(loadfile("projets/usine/principal.lua"))()
end

local function present(m, motif)
  verif.vrai(ecran(m).chercher(vers_cc(motif)), "introuvable à l'écran : " .. motif .. "\n" .. ecran(m).texte())
end

local function toucher(m, motif)
  local x, y = ecran(m).chercher(vers_cc(motif))
  if not x then error("introuvable à l'écran : " .. motif .. "\n" .. ecran(m).texte()) end
  return { "monitor_touch", "monitor_0", x, y }
end

local function etat_enregistre(m)
  return textutils.unserialize(m.disque.disque["usine.etat"] or "nil")
end

return {
  ligne_sous_maxi_tourne_et_s_affiche = function()
    local m = monde()
    lancer(m, 2)
    verif.egal(m.presents.relais_0.sorties.back, false, "embrayage relâché : ligne en marche")
    present(m, "Presse")
    present(m, "50 %")
    verif.vrai(m.disque.disque["usine.cfg"] ~= nil)
  end,

  stock_plein_coupe_selon_signal_coupe = function()
    local m = monde({ lignes = { ligne("A", { maxi = 200 }), ligne("B", { maxi = 200, cote = "top",
      signal_coupe = false }) } })
    lancer(m, 2)
    verif.egal(m.presents.relais_0.sorties, { back = true, top = false })
    present(m, "stock plein")
  end,

  sortie_est_reaffirmee_a_chaque_passe = function()
    local m = monde()
    lancer(m, 3)
    verif.vrai(m.presents.relais_0.ordres >= 2, "un ordre par passe")
  end,

  tous_peripheriques_absents_rien_ne_leve_et_tout_est_signale = function()
    local m = monde()
    m.presents = {}
    lancer(m, 3)
    present(m, "Stock Ticker introuvable")
    present(m, "relais relais_0 introuvable")
    present(m, "stressomètre introuvable")
  end,

  toucher_une_ligne_change_le_mode_l_applique_et_l_enregistre_tout_de_suite = function()
    local m = monde({ lignes = { ligne("Presse", { maxi = 200 }) } })
    lancer(m, 2, function(tour)
      if tour == 2 then return toucher(m, "Presse") end
    end)
    verif.egal(etat_enregistre(m).Presse.mode, "marche")
    verif.egal(m.presents.relais_0.sorties.back, false, "forcée en marche malgré le stock plein")
    present(m, "forcée marche")
  end,

  redemarrage_retrouve_modes_decisions_et_delestees = function()
    local m = monde({ lignes = { ligne("A"), ligne("B", { cote = "top" }), ligne("C", { cote = "left" }) } })
    m.disque.disque["usine.etat"] = textutils.serialize({
      A = { mode = "arret" }, B = { mode = "auto", decision = false }, C = { mode = "auto", decision = true,
        delestee = true },
    })
    m.presents.ticker_0 = nil
    m.presents.stress_0 = nil
    lancer(m, 2)
    verif.egal(m.presents.relais_0.sorties, { back = true, top = true, left = true })
    local etat = etat_enregistre(m)
    verif.egal({ etat.A.mode, etat.B.decision, etat.C.delestee }, { "arret", false, true })
    present(m, "forcée arrêt")
  end,

  surcharge_deleste_la_moins_prioritaire_et_l_enregistre = function()
    local m = monde({ lignes = { ligne("A", { priorite = 2 }), ligne("B", { cote = "top" }) } })
    m.presents.stress_0.stress = 16000
    lancer(m, 0)
    verif.egal(m.presents.relais_0.sorties, { back = true, top = false }, "une seule ligne à la première passe")
    verif.egal(etat_enregistre(m).A.delestee, true)
    present(m, "délestée")
  end,

  config_fautive_est_signalee_et_le_reste_tourne = function()
    local m = monde({ lignes = { ligne("Mauvaise", { mini = 900 }), ligne("Bonne", { cote = "top" }) } })
    lancer(m, 2)
    present(m, "Mauvaise écartée : mini > maxi")
    verif.egal(m.presents.relais_0.sorties, { top = false })
  end,

  relais_sans_setOutput_est_signale = function()
    local m = monde({ lignes = { ligne("A", { relais = "energie_0" }) } })
    m.presents.energie_0 = { getEnergy = function() return 0 end }
    lancer(m, 2)
    present(m, "pas un relais redstone de ComputerCraft")
  end,

  sans_moniteur_le_tableau_de_bord_va_sur_le_terminal = function()
    local m = monde()
    m.presents.monitor_0 = nil
    lancer(m, 2)
    present(m, "Presse")
  end,

  erreur_inattendue_s_affiche_et_se_journalise_sans_arreter = function()
    local m = monde()
    lancer(m, 3, nil, function()
      local wrap = peripheral.wrap
      peripheral.wrap = function(nom)
        if nom == "relais_0" then error("modem en panne", 0) end
        return wrap(nom)
      end
    end)
    present(m, "modem en panne")
    verif.vrai(m.disque.disque["usine.log"]:find("modem en panne", 1, true))
  end,
}
