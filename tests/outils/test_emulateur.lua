-- L'ordinateur émulé suit le modèle d'exécution de CC : file d'événements, filtres de parallel, minuteries, fs, clics.

local verif = require("verif")
local ordinateur = require("outils.emulateur.ordinateur")
local bibliotheques = require("outils.emulateur.bibliotheques")
local disques = require("outils.emulateur.disque")

-- Le programme note ses observations dans /journal, une ligne par appel.
local NOTER = 'local function noter(...) local f = fs.open("/journal", "a") '
  .. 'local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end '
  .. 'f.writeLine(table.concat(t, " ")) f.close() end\n'

local function lancer(source, fichiers)
  local hote = { t = 0, derive = 0 }
  function hote.maintenant()
    hote.t = hote.t + hote.derive
    return hote.t
  end
  function hote.epoque() return 1700000000000 + hote.t end
  function hote.decalage_local() return 0 end
  function hote.son() end
  fichiers = fichiers or {}
  fichiers["/prog.lua"] = NOTER .. source
  local ordi = ordinateur.creer({ hote = hote, fichiers = fichiers, entree = "/prog.lua",
    moniteur = { nom = "monitor_0", largeur = 20, hauteur = 10 } })
  ordi.demarrer()
  return ordi, hote
end

-- Exécute jusqu'à l'instant `fin` (ms) en sautant de minuterie en minuterie ; renvoie l'état final.
local function tourner(ordi, hote, fin)
  while true do
    local etat, delai, message, trace = ordi.executer()
    if etat ~= "attente" or delai < 0 or hote.t + delai > fin then return etat, message, trace end
    hote.t = hote.t + delai
  end
end

local function journal(ordi)
  local fichier = ordi.disque.fs.open("/journal", "r")
  if not fichier then return {} end
  local lignes = {}
  for ligne in fichier.readAll():gmatch("[^\n]+") do lignes[#lignes + 1] = ligne end
  fichier.close()
  return lignes
end

return {
  pull_event_filtre_jette_les_autres_evenements_sauf_terminate = function()
    local ordi, hote = lancer('noter(os.pullEventRaw("b")) noter(os.pullEventRaw("b"))')
    tourner(ordi, hote, 0)
    ordi.evenement("a", 1)
    ordi.evenement("b", 2)
    ordi.evenement("a", 3)
    ordi.evenement("terminate")
    verif.egal(tourner(ordi, hote, 0), "fini")
    verif.egal(journal(ordi), { "b 2", "terminate" })
  end,

  pull_event_termine_le_programme_sur_terminate = function()
    local ordi, hote = lancer('os.pullEvent() noter("jamais")')
    tourner(ordi, hote, 0)
    ordi.evenement("terminate")
    local etat, message = tourner(ordi, hote, 0)
    verif.egal({ etat, message }, { "fini", "Terminated" })
    verif.egal(journal(ordi), {})
  end,

  parallel_respecte_le_filtre_de_chaque_coroutine = function()
    local ordi, hote = lancer([[
      local fini = parallel.waitForAny(
        function() while true do noter("A", os.pullEvent("a")) end end,
        function() noter("B", os.pullEvent("b")) noter("B", os.pullEvent("b")) end)
      noter("fin", fini)]])
    tourner(ordi, hote, 0)
    for _, nom in ipairs({ "a", "b", "x", "a", "b", "a" }) do ordi.evenement(nom) end
    verif.egal(tourner(ordi, hote, 0), "fini")
    verif.egal(journal(ordi), { "A a", "B b", "A a", "B b", "fin 2" })
  end,

  parallel_wait_for_all_attend_toutes_les_coroutines = function()
    local ordi, hote = lancer([[
      parallel.waitForAll(function() sleep(0.2) noter("lent") end, function() sleep(0.05) noter("vite") end)
      noter("fin")]])
    verif.egal(tourner(ordi, hote, 1000), "fini")
    verif.egal(journal(ordi), { "vite", "lent", "fin" })
  end,

  parallel_propage_l_erreur_d_une_coroutine = function()
    local ordi, hote = lancer('parallel.waitForAny(function() error("boum", 0) end, function() sleep(1) end)')
    local etat, message, trace = tourner(ordi, hote, 1000)
    verif.egal({ etat, message }, { "erreur", "boum" })
    verif.vrai(trace:find("traceback", 1, true) ~= nil, trace)
  end,

  minuterie_arrondie_au_tick_et_jamais_en_avance = function()
    local ordi, hote = lancer('local id = os.startTimer(0.12) local _, recu = os.pullEvent("timer") noter(recu == id, os.clock())')
    verif.egal(tourner(ordi, hote, 149), "attente")
    verif.egal(journal(ordi), {})
    verif.egal(tourner(ordi, hote, 150), "fini")
    verif.egal(journal(ordi), { "true 0.15" })
  end,

  minuteries_dans_l_ordre_et_annulation = function()
    local ordi, hote = lancer([[
      local a, b, c = os.startTimer(0.3), os.startTimer(0.1), os.startTimer(0.2)
      os.cancelTimer(c)
      noter(select(2, os.pullEvent("timer")) == b) noter(select(2, os.pullEvent("timer")) == a)
      os.startTimer(0) noter(select(2, os.pullEvent("timer")))]])
    verif.egal(tourner(ordi, hote, 10000), "fini")
    verif.egal(journal(ordi), { "true", "true", "4" })
    verif.egal(hote.t, 350)
  end,

  queue_event_passe_apres_les_evenements_deja_en_file = function()
    local ordi, hote = lancer('os.queueEvent("moi", 1) noter(os.pullEvent()) noter(os.pullEvent())')
    tourner(ordi, hote, 0)
    verif.egal(journal(ordi), { "moi 1" })
    ordi.evenement("char", "z")
    tourner(ordi, hote, 0)
    verif.egal(journal(ordi), { "moi 1", "char z" })
  end,

  boucle_sans_pause_interrompue_avec_le_message_de_cc = function()
    local ordi, hote = lancer("while true do end")
    hote.derive = 1000
    local etat, message = tourner(ordi, hote, 0)
    verif.egal(etat, "erreur")
    verif.vrai(message:find("Too long without yielding", 1, true) ~= nil, message)
  end,

  toucher_du_moniteur_donne_la_case_et_le_nom = function()
    local ordi, hote = lancer('noter(os.pullEvent("monitor_touch"))')
    tourner(ordi, hote, 0)
    verif.egal({ ordi.toucher(119.9, 0, 120, 90) }, { 20, 1 })
    tourner(ordi, hote, 0)
    verif.egal(journal(ordi), { "monitor_touch monitor_0 20 1" })
  end,

  case_du_clic_compte_depuis_un_et_reste_dans_l_ecran = function()
    verif.egal({ ordinateur.case_du_clic(0, 0, 612, 342, 51, 19) }, { 1, 1 })
    verif.egal({ ordinateur.case_du_clic(11.9, 17.9, 612, 342, 51, 19) }, { 1, 1 })
    verif.egal({ ordinateur.case_du_clic(12, 18, 612, 342, 51, 19) }, { 2, 2 })
    verif.egal({ ordinateur.case_du_clic(612, 342, 612, 342, 51, 19) }, { 51, 19 })
    verif.egal({ ordinateur.case_du_clic(-3, 400, 612, 342, 51, 19) }, { 1, 19 })
  end,

  peripheral_find_ne_trouve_que_le_moniteur_par_defaut = function()
    local ordi, hote = lancer([[
      local m = peripheral.find("monitor") noter(peripheral.getName(m), m.getSize())
      noter(peripheral.find("speaker"), peripheral.find("colony_integrator"))
      noter(os.pullEvent("peripheral")) noter(peripheral.getType(peripheral.find("speaker")))]])
    tourner(ordi, hote, 0)
    ordi.brancher("speaker_0", true)
    verif.egal(tourner(ordi, hote, 0), "fini")
    verif.egal(journal(ordi), { "monitor_0 20 10", "nil", "peripheral speaker_0", "speaker" })
  end,

  redimensionner_le_moniteur_emet_monitor_resize = function()
    local ordi, hote = lancer('noter(os.pullEvent("monitor_resize")) noter(peripheral.find("monitor").getSize())')
    tourner(ordi, hote, 0)
    ordi.redimensionner(30, 12)
    tourner(ordi, hote, 0)
    verif.egal(journal(ordi), { "monitor_resize monitor_0", "30 12" })
  end,

  require_charge_depuis_le_disque_avec_package_path = function()
    local ordi, hote = lancer([[
      package.path = "/?.lua;" .. package.path
      local m = require("lib.outil") noter(m.nom, require("lib.outil") == m)
      noter(pcall(require, "absent"))]], { ["/lib/outil.lua"] = 'return { nom = "outil" }' })
    verif.egal(tourner(ordi, hote, 0), "fini")
    local lignes = journal(ordi)
    verif.egal(lignes[1], "outil true")
    verif.vrai(lignes[2]:find("module 'absent' not found", 1, true) ~= nil, lignes[2])
  end,

  reboot_relance_le_programme_avec_des_globales_neuves = function()
    local ordi, hote = lancer('noter(compteur) compteur = 1 sleep(0.05) os.reboot()')
    verif.egal(tourner(ordi, hote, 120), "attente")
    verif.egal(journal(ordi), { "nil", "nil", "nil" })
  end,

  shutdown_arrete_l_ordinateur = function()
    local ordi, hote = lancer("os.shutdown()")
    verif.egal(tourner(ordi, hote, 0), "arrete")
  end,

  print_ecrit_sur_le_terminal_et_defile = function()
    local ordi, hote = lancer('for i = 1, 20 do print("ligne", i) end')
    tourner(ordi, hote, 0)
    verif.egal((ordi.terminal.ligne(19)), string.rep(" ", 51))
    verif.egal((ordi.terminal.ligne(18)):sub(1, 9), "ligne\t20 ")
  end,

  fs_lit_ecrit_ajoute_deplace_et_liste = function()
    local fs = disques.creer({ ["/a/b.txt"] = "un\r\ndeux\n" }).fs
    local lecture = fs.open("a/b.txt", "r")
    verif.egal({ lecture.readLine(), lecture.readLine(), lecture.readLine() }, { "un", "deux" })
    lecture.close()
    verif.erreur(function() lecture.readAll() end, "closed file")
    local ecriture = fs.open("/c/d.txt", "w")
    ecriture.write("x")
    ecriture.writeLine(1)
    ecriture.close()
    local ajout = fs.open("/c/d.txt", "a")
    ajout.write("y")
    ajout.close()
    verif.egal(fs.open("/c/d.txt", "r").readAll(), "x1\ny")
    verif.egal({ fs.getSize("/c/d.txt"), fs.isDir("c"), fs.getDir("/c/d.txt"), fs.getName("/c/d.txt") }, { 4, true, "c", "d.txt" })
    fs.move("/c", "/e")
    verif.egal({ fs.exists("/c/d.txt"), fs.exists("/e/d.txt") }, { false, true })
    verif.egal(fs.list("/"), { "a", "e" })
    verif.erreur(function() fs.move("/a", "/e") end, "File exists")
    verif.erreur(function() fs.getSize("/rien") end, "No such file")
    verif.egal({ fs.open("/rien", "r") }, { nil, "/rien: No such file" })
    fs.delete("/a")
    verif.egal({ fs.exists("/a/b.txt"), fs.combine("x/", "../y", "./z") }, { false, "y/z" })
  end,

  fs_export_puis_import_retrouve_les_changements = function()
    local initiaux = { ["/garde.lua"] = "g", ["/efface.lua"] = "e" }
    local premier = disques.creer(initiaux)
    verif.egal(premier.exporter(), nil)
    local fichier = premier.fs.open("/cfg", "w")
    fichier.write("\0\255\n")
    fichier.close()
    premier.fs.delete("/efface.lua")
    premier.fs.makeDir("/vide")
    local export = premier.exporter()
    verif.egal(premier.exporter(), nil)
    local second = disques.creer(initiaux)
    verif.vrai(second.importer(export))
    verif.egal(second.fs.open("/cfg", "r").readAll(), "\0\255\n")
    verif.egal(second.fs.list("/"), { "cfg", "garde.lua", "vide" })
    verif.egal(second.importer("n'importe quoi"), false)
  end,

  diagnostic_montre_la_fin_des_fichiers_ecrits_et_pas_ceux_du_projet = function()
    local disque = disques.creer({ ["/projet.lua"] = "return 1" })
    local journal = disque.fs.open("/casino.log", "w")
    for i = 1, 5 do journal.writeLine("ligne " .. i) end
    journal.close()
    local resume = disque.resumer(2)
    verif.vrai(resume:find("== /casino.log", 1, true) or resume:find("== casino.log", 1, true), resume)
    verif.vrai(resume:find("5 lignes", 1, true), resume)
    verif.vrai(resume:find("ligne 5", 1, true) and resume:find("ligne 4", 1, true), resume)
    verif.vrai(not resume:find("ligne 3", 1, true), resume)
    verif.vrai(not resume:find("projet.lua", 1, true), resume)
  end,

  textutils_serialise_comme_cc = function()
    local textutils = bibliotheques.textutils()
    verif.egal(textutils.serialize({ 1, "a", cle = true }), '{\n  1,\n  "a",\n  cle = true,\n}')
    verif.egal(textutils.serialize({ x = 2.0 }, { compact = true }), "{x=2,}")
    verif.egal(textutils.unserialize(textutils.serialize({ { n = 3 } }))[1].n, 3)
    verif.egal(textutils.unserialize("{"), nil)
    verif.erreur(function() textutils.serialize({ f = print }) end, "Cannot serialize type function")
    verif.egal({ textutils.formatTime(13.5, true), textutils.formatTime(13.5), textutils.formatTime(0.25) },
      { "13:30", "1:30 PM", "12:15 AM" })
  end,

  colors_combine_soustrait_et_teste = function()
    local colors = bibliotheques.colors()
    local ensemble = colors.combine(colors.red, colors.white, colors.red)
    verif.egal(ensemble, colors.red + colors.white)
    verif.egal(colors.subtract(ensemble, colors.red), colors.white)
    verif.egal({ colors.test(ensemble, colors.red), colors.test(ensemble, colors.blue) }, { true, false })
    verif.egal({ colors.toBlit(colors.black), colors.fromBlit("e") }, { "f", colors.red })
    verif.egal(bibliotheques.colours(colors).grey, colors.gray)
  end,
}
