-- Bout en bout : le point d'entrée tourne dans une coroutine contre de faux globaux CC (horloge, minuteries, moniteur).

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local faux_moniteur = require("faux.moniteur")
local machine = require("casino.jeux.machine")

local SEPT
for i, nom in ipairs(machine.BANDE) do
  if nom == "sept" and not SEPT then SEPT = i end
end

-- Monde : disque en mémoire, moniteur 51x19 (les tailles sont balayées par test_vues) (nil pour jouer sur le terminal), horloge et minuteries pilotées.
local function monde(options)
  options = options or {}
  local m = { horloge = 0, minuteurs = {}, numero = 0, terminal = faux_moniteur.nouveau(51, 19), notes = {},
    tirage = options.tirage or SEPT }
  m.etat_disque = options.disque or systeme.installer()
  if options.disque then systeme.installer().disque = options.disque.disque end
  -- Hors du test de cadence, une image tous les quarts de seconde suffit et garde le test rapide.
  if not options.disque and not options.cadence_reelle then
    m.etat_disque.disque["casino.cfg"] = textutils.serialize({ periode_image = 0.25 })
  end
  if options.moniteur ~= false then
    m.moniteur = faux_moniteur.nouveau(51, 19)
    m.moniteur.setTextScale = function() end
  end
  if options.haut_parleur then
    m.haut_parleur = { playNote = options.haut_parleur(m) }
  end
  return m
end

-- Lance principal.lua dans une coroutine ; renvoie le pilote : toucher(motif), attendre(secondes), envoyer(...).
local function lancer(m)
  local presents = { monitor = m.moniteur, speaker = m.haut_parleur }
  peripheral = { find = function(genre) return presents[genre] end }
  term = { current = function() return m.terminal end }
  os.clock = function() return m.horloge end
  os.startTimer = function(delai)
    m.numero = m.numero + 1
    m.minuteurs[m.numero] = m.horloge + delai
    return m.numero
  end
  os.cancelTimer = function(id) m.minuteurs[id] = nil end
  os.pullEventRaw = function() return coroutine.yield() end
  math.random = function() return m.tirage end
  local co = coroutine.create(function() assert(loadfile("projets/casino/principal.lua"))() end)
  local pilote = { co = co }
  function pilote.envoyer(...)
    local ok, erreur = coroutine.resume(co, ...)
    if not ok then error(erreur, 0) end
  end
  function pilote.attendre(secondes)
    local fin = m.horloge + secondes
    while true do
      local id, quand
      for numero, instant in pairs(m.minuteurs) do
        if not quand or instant < quand then id, quand = numero, instant end
      end
      if not id or quand > fin then break end
      m.minuteurs[id] = nil
      m.horloge = math.max(m.horloge, quand)
      pilote.envoyer("timer", id)
    end
    m.horloge = fin
  end
  -- Touche le milieu de la dernière occurrence de `motif` sur l'écran de jeu.
  function pilote.toucher(motif)
    local ecran = m.moniteur or m.terminal
    local _, hauteur = ecran.getSize()
    for y = hauteur, 1, -1 do
      local x = ecran.ligne(y):find(motif, 1, true)
      if x then
        if m.moniteur then return pilote.envoyer("monitor_touch", "top", x + 1, y) end
        return pilote.envoyer("mouse_click", 1, x + 1, y)
      end
    end
    error("introuvable à l'écran : " .. motif .. "\n" .. ecran.texte())
  end
  pilote.envoyer()
  return pilote
end

local function jetons(m)
  return textutils.unserialize(m.etat_disque.disque["casino.jetons"])
end

return {
  partie_de_machine_au_toucher_met_a_jour_et_persiste_le_solde = function()
    local m = monde()
    local p = lancer(m)
    verif.vrai(m.moniteur.chercher("Solde"), m.moniteur.texte())
    verif.egal(jetons(m), { solde = 500 })
    p.toucher("Machine")
    p.toucher("JOUER")
    verif.egal(jetons(m), { solde = 490, en_cours = { mise = 10, gain = 1000 } })
    p.attendre(3)
    verif.egal(jetons(m), { solde = 1490 })
    verif.vrai(m.moniteur.chercher("1 000 jetons !"), m.moniteur.texte())
    verif.vrai(m.moniteur.chercher("Solde 1 490"), m.moniteur.texte())
    verif.vrai(m.etat_disque.disque["casino.cfg"] ~= nil, "la config doit être créée au premier lancement")
  end,

  main_de_blackjack_complete_au_toucher_reglee_au_gain_ecrit = function()
    local m = monde()
    local p = lancer(m)
    p.toucher("Blackjack")
    p.toucher("DISTRIBUER")
    local ouvert = jetons(m)
    verif.egal(ouvert.solde, 490)
    verif.egal(ouvert.en_cours.mise, 10)
    p.attendre(2)
    if m.moniteur.chercher("RESTER") then p.toucher("RESTER") end
    p.attendre(5)
    verif.egal(jetons(m), { solde = 490 + ouvert.en_cours.gain })
    verif.vrai(m.moniteur.chercher("DISTRIBUER"), m.moniteur.texte())
    verif.vrai(m.moniteur.chercher("Solde " .. require("commun.texte").milliers(490 + ouvert.en_cours.gain)),
      m.moniteur.texte())
  end,

  l_animation_tourne_par_minuterie_puis_s_arrete = function()
    local m = monde({ cadence_reelle = true })
    local p = lancer(m)
    p.toucher("Machine")
    local avant = m.numero
    p.toucher("JOUER")
    p.attendre(2.2)
    verif.vrai(m.numero - avant >= 20, "trop peu d'images : " .. (m.numero - avant))
    p.attendre(5)
    local apres = m.numero
    p.attendre(30)
    verif.vrai(m.numero - apres <= 1, "des images sans rien qui bouge : " .. (m.numero - apres))
  end,

  redemarrage_en_plein_tour_regle_le_tour_au_gain_tire = function()
    local m = monde()
    local p = lancer(m)
    p.toucher("Machine")
    p.toucher("JOUER")
    p.attendre(0.5)
    local relance = monde({ disque = m.etat_disque })
    lancer(relance)
    verif.egal(jetons(relance), { solde = 1490 })
    verif.vrai(relance.moniteur.chercher("Tour interrompu"), relance.moniteur.texte())
  end,

  retour_au_hall_apres_inactivite = function()
    local m = monde()
    local p = lancer(m)
    p.toucher("Crash")
    verif.vrai(m.moniteur.chercher("ENCAISSER"), m.moniteur.texte())
    p.attendre(95)
    verif.vrai(m.moniteur.chercher("Plus gros gain"), m.moniteur.texte())
  end,

  sans_moniteur_le_terminal_se_joue_a_la_souris = function()
    local m = monde({ moniteur = false })
    local p = lancer(m)
    p.toucher("Recharger")
    verif.egal(jetons(m), { solde = 1000 })
    verif.vrai(m.terminal.chercher("1 000"), m.terminal.texte())
  end,

  haut_parleur_en_panne_affiche_l_erreur_et_le_jeu_continue = function()
    local m = monde({ haut_parleur = function() return function() error("câble coupé", 0) end end })
    local p = lancer(m)
    p.toucher("Machine")
    p.toucher("JOUER")
    verif.vrai(m.moniteur.chercher("ble coup"), m.moniteur.texte())
    p.attendre(3)
    verif.egal(jetons(m), { solde = 1490 })
  end,

  haut_parleur_joue_les_notes_de_mise_et_de_gain = function()
    local notes = {}
    local m = monde({ haut_parleur = function() return function(instrument) notes[#notes + 1] = instrument end end })
    local p = lancer(m)
    p.toucher("Machine")
    p.toucher("JOUER")
    p.attendre(3)
    verif.egal(notes[1], "hat")
    verif.egal(notes[#notes], "bell")
  end,

  arret_restaure_la_palette = function()
    local m = monde()
    local p = lancer(m)
    local r = m.moniteur.getPaletteColour(colors.black)
    verif.vrai(math.abs(r - 0x0B / 255) < 1e-6)
    p.envoyer("terminate")
    verif.egal(coroutine.status(p.co), "dead")
    r = m.moniteur.getPaletteColour(colors.black)
    verif.vrai(math.abs(r - 0x11 / 255) < 1e-6)
  end,
}
