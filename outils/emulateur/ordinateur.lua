-- Ordinateur CC émulé : le programme tourne dans une coroutine reprise à chaque événement, l'hôte fournit l'horloge.

local bibliotheques = require("outils.emulateur.bibliotheques")
local disques = require("outils.emulateur.disque")
local enregistreur = require("outils.moniteur_enregistreur")
local faux_peripheriques = require("outils.emulateur.peripheriques")

local ordinateur = {}

local TICK = 50                 -- ms par tick de Minecraft
local LIMITE_SANS_PAUSE = 7000  -- ms de calcul sans rendre la main avant « Too long without yielding », comme CC
local PAS_CONTROLE = 10000      -- instructions Lua entre deux contrôles de cette limite
local TRANCHE = 50              -- ms de calcul avant de rendre la main au navigateur
local FILE_MAX = 256            -- événements en attente au plus, comme CC
local TERMINAL = { 51, 19 }     -- taille de l'écran d'un ordinateur avancé
local COTES = { "top", "bottom", "left", "right", "front", "back" }
local CHEMIN_REQUIRE = "?;?.lua;?/init.lua;/rom/modules/main/?;/rom/modules/main/?.lua;/rom/modules/main/?/init.lua"
local KEYS = bibliotheques.keys()

local METHODES_TERM = {
  "write", "blit", "clear", "clearLine", "getCursorPos", "setCursorPos", "getCursorBlink", "setCursorBlink", "getSize",
  "scroll", "isColor", "isColour", "getTextColor", "getTextColour", "setTextColor", "setTextColour",
  "getBackgroundColor", "getBackgroundColour", "setBackgroundColor", "setBackgroundColour",
  "getPaletteColor", "getPaletteColour", "setPaletteColor", "setPaletteColour",
}

-- Méthodes visibles par le programme d'une cible enregistreuse : celles de `term`, plus `extra`.
local function publique(cible, extra)
  local methodes = {}
  for _, nom in ipairs(METHODES_TERM) do methodes[nom] = cible[nom] end
  for _, nom in ipairs(extra or {}) do methodes[nom] = cible[nom] end
  return methodes
end

local function copie(source)
  local resultat = {}
  for cle, valeur in pairs(source) do resultat[cle] = valeur end
  return resultat
end

--- Case (x, y), comptée depuis 1, sous le point (px, py) d'un écran de `colonnes` x `lignes` cases affiché sur
--- `largeur_px` x `hauteur_px` pixels.
function ordinateur.case_du_clic(px, py, largeur_px, hauteur_px, colonnes, lignes)
  local x = math.floor(px * colonnes / largeur_px) + 1
  local y = math.floor(py * lignes / hauteur_px) + 1
  return math.max(1, math.min(colonnes, x)), math.max(1, math.min(lignes, y))
end

--- Crée un ordinateur. `options` : `hote` (maintenant() en ms, epoque() en ms UTC, decalage_local() en ms,
--- son(frequence, volume, duree)), `fichiers` (chemin -> contenu), `entree` (programme lancé au démarrage),
--- `moniteur` ({ nom, largeur, hauteur }). Appeler `demarrer()` puis `executer()` à chaque réveil.
function ordinateur.creer(options)
  local hote = options.hote
  local disque = disques.creer(options.fichiers)
  local nom_moniteur = options.moniteur.nom
  local moniteur = enregistreur.creer(options.moniteur.largeur, options.moniteur.hauteur)
  local origine_monde = hote.maintenant()
  local branches = { [nom_moniteur] = { type = "monitor", methodes = publique(moniteur, { "setTextScale", "getTextScale" }) } }
  local ordi = { disque = disque, moniteur = moniteur }

  -- État d'une session, remis à neuf par demarrer().
  local fil, filtre, file, minuteries, prochain_id, demarrage
  local lance, demande, en_cours, debut_tranche
  local etat, message, trace

  local function surveiller()
    if en_cours and hote.maintenant() - debut_tranche > LIMITE_SANS_PAUSE then
      error("Too long without yielding", 2)
    end
  end

  local function creer_coroutine(fonction)
    local nouvelle = coroutine.create(fonction)
    debug.sethook(nouvelle, surveiller, "", PAS_CONTROLE)
    return nouvelle
  end

  -- Avant le premier démarrage, il n'y a pas de file : rien n'est mis en attente.
  local function enfiler(...)
    if file and #file < FILE_MAX then file[#file + 1] = table.pack(...) end
  end

  -- Globales de CC d'une session et fonction principale de sa coroutine.
  local function construire(terminal)
    local G = {}
    for _, nom in ipairs({ "assert", "error", "getmetatable", "setmetatable", "ipairs", "pairs", "next", "pcall",
      "xpcall", "rawequal", "rawget", "rawset", "rawlen", "select", "tonumber", "tostring", "type", "_VERSION" }) do
      G[nom] = _G[nom]
    end
    for _, nom in ipairs({ "string", "table", "math", "utf8", "debug", "coroutine" }) do G[nom] = copie(_G[nom]) end
    G._G = G
    G._HOST = "ComputerCraft 1.120.2 (émulateur navigateur)"
    G.coroutine.create = creer_coroutine
    function G.coroutine.wrap(fonction)
      local enveloppee = creer_coroutine(fonction)
      return function(...)
        local resultats = table.pack(coroutine.resume(enveloppee, ...))
        if not resultats[1] then error(resultats[2], 0) end
        return table.unpack(resultats, 2, resultats.n)
      end
    end
    G.colors = bibliotheques.colors()
    G.colours = bibliotheques.colours(G.colors)
    G.keys = copie(KEYS)
    G.textutils = bibliotheques.textutils()
    local fs = copie(disque.fs)
    G.fs = fs

    function G.load(morceau, nom, mode, env)
      return load(morceau, nom, mode, env == nil and G or env)
    end
    function G.loadfile(chemin, mode, env)
      local fichier = fs.open(chemin, "r")
      if not fichier then return nil, "File not found" end
      local source = fichier.readAll()
      fichier.close()
      return load(source, "@/" .. fs.combine(chemin), mode, env == nil and G or env)
    end
    function G.dofile(chemin)
      local fonction, erreur = G.loadfile(chemin, nil, G)
      if not fonction then error(erreur, 2) end
      return fonction()
    end

    -- term : redirection vers la cible courante, le terminal de l'ordinateur par défaut.
    local natif = publique(terminal)
    local courant = natif
    local term = {}
    for _, nom in ipairs(METHODES_TERM) do term[nom] = function(...) return courant[nom](...) end end
    function term.current() return courant end
    function term.native() return natif end
    function term.redirect(cible)
      if type(cible) ~= "table" then error("bad argument #1 (table expected, got " .. type(cible) .. ")", 2) end
      local ancien = courant
      courant = cible
      return ancien
    end
    local reference = enregistreur.creer(1, 1)
    term.nativePaletteColour = reference.getPaletteColour
    term.nativePaletteColor = reference.getPaletteColour
    G.term = term

    -- write et print : retour à la ligne aux mots et défilement, comme le bios de CC.
    function G.write(texte)
      local largeur, hauteur = term.getSize()
      local x, y = term.getCursorPos()
      local lignes = 0
      local function a_la_ligne()
        if y + 1 <= hauteur then
          term.setCursorPos(1, y + 1)
        else
          term.setCursorPos(1, hauteur)
          term.scroll(1)
        end
        x, y = term.getCursorPos()
        lignes = lignes + 1
      end
      texte = tostring(texte)
      while #texte > 0 do
        local blanc = texte:match("^[ \t]+")
        if blanc then
          term.write(blanc)
          x, y = term.getCursorPos()
          texte = texte:sub(#blanc + 1)
        end
        if texte:sub(1, 1) == "\n" then
          a_la_ligne()
          texte = texte:sub(2)
        end
        local mot = texte:match("^[^ \t\n]+")
        if mot then
          texte = texte:sub(#mot + 1)
          if #mot > largeur then
            while #mot > 0 do
              if x > largeur then a_la_ligne() end
              term.write(mot)
              mot = mot:sub(largeur - x + 2)
              x, y = term.getCursorPos()
            end
          else
            if x + #mot - 1 > largeur then a_la_ligne() end
            term.write(mot)
            x, y = term.getCursorPos()
          end
        end
      end
      return lignes
    end
    function G.print(...)
      local lignes = 0
      local nombre = select("#", ...)
      for n = 1, nombre do
        local texte = tostring((select(n, ...)))
        if n < nombre then texte = texte .. "\t" end
        lignes = lignes + G.write(texte)
      end
      return lignes + G.write("\n")
    end
    function G.printError(...)
      local ancienne = term.getTextColour()
      term.setTextColour(G.colors.red)
      G.print(...)
      term.setTextColour(ancienne)
    end
    function G.read(remplacement)
      term.setCursorBlink(true)
      local texte = ""
      local x0, y0 = term.getCursorPos()
      local function redessiner()
        local visible = remplacement and string.rep(remplacement:sub(1, 1), #texte) or texte
        term.setCursorPos(x0, y0)
        term.write(visible .. " ")
        term.setCursorPos(x0 + #visible, y0)
      end
      while true do
        local evenement, valeur = G.os.pullEvent()
        if evenement == "char" then
          texte = texte .. valeur
          redessiner()
        elseif evenement == "key" and valeur == KEYS.enter then
          break
        elseif evenement == "key" and valeur == KEYS.backspace and #texte > 0 then
          texte = texte:sub(1, -2)
          redessiner()
        end
      end
      term.setCursorBlink(false)
      G.print()
      return texte
    end

    -- os : événements, minuteries, heures.
    local os_ = { date = os.date }
    G.os = os_
    local etiquette
    function os_.pullEventRaw(filtre_voulu) return coroutine.yield(filtre_voulu) end
    function os_.pullEvent(filtre_voulu)
      local evenement = table.pack(G.os.pullEventRaw(filtre_voulu))
      if evenement[1] == "terminate" then error("Terminated", 0) end
      return table.unpack(evenement, 1, evenement.n)
    end
    function os_.queueEvent(nom, ...)
      if type(nom) ~= "string" then error("bad argument #1 (string expected, got " .. type(nom) .. ")", 2) end
      enfiler(nom, ...)
    end
    function os_.startTimer(duree)
      if type(duree) ~= "number" then error("bad argument #1 (number expected, got " .. type(duree) .. ")", 2) end
      if duree < 0 then error("bad argument #1 (number must be >= 0)", 2) end
      prochain_id = prochain_id + 1
      minuteries[prochain_id] = hote.maintenant() + math.max(1, math.ceil(duree * 20 - 1e-9)) * TICK
      return prochain_id
    end
    function os_.cancelTimer(id) minuteries[id] = nil end
    function os_.clock() return math.floor((hote.maintenant() - demarrage) / TICK) / 20 end
    local function lieu(locale)
      local nom = string.lower(locale or "ingame")
      if nom ~= "ingame" and nom ~= "utc" and nom ~= "local" then error("Unsupported operation", 3) end
      return nom
    end
    local function ticks_monde() return math.floor((hote.maintenant() - origine_monde) / TICK) end
    local function ms_reelles(nom)
      return nom == "utc" and hote.epoque() or hote.epoque() + hote.decalage_local()
    end
    function os_.time(locale)
      if type(locale) == "table" then return os.time(locale) end
      local nom = lieu(locale)
      if nom == "ingame" then return ((ticks_monde() + 6000) % 24000) / 1000 end
      return (ms_reelles(nom) % 86400000) / 3600000
    end
    function os_.day(locale)
      local nom = lieu(locale)
      if nom == "ingame" then return math.floor((ticks_monde() + 6000) / 24000) + 1 end
      return math.floor(ms_reelles(nom) / 86400000)
    end
    function os_.epoch(locale)
      local nom = lieu(locale)
      if nom == "ingame" then return math.floor((os_.day() * 24 + os_.time()) * 3600000) end
      return math.floor(ms_reelles(nom))
    end
    function os_.getComputerID() return 0 end
    os_.computerID = os_.getComputerID
    function os_.getComputerLabel() return etiquette end
    function os_.setComputerLabel(texte) etiquette = texte end
    os_.computerLabel = os_.getComputerLabel
    function os_.version() return "CraftOS 1.9" end
    function os_.reboot()
      demande = "reboot"
      while true do coroutine.yield() end
    end
    function os_.shutdown()
      demande = "arret"
      while true do coroutine.yield() end
    end
    function G.sleep(duree)
      local minuteur = G.os.startTimer(duree or 0)
      local _, parametre
      repeat _, parametre = G.os.pullEvent("timer") until parametre == minuteur
    end
    os_.sleep = G.sleep
    G.parallel = bibliotheques.parallel(function() return G.os.pullEventRaw() end, creer_coroutine)

    -- peripheral : le moniteur et les faux périphériques branchés.
    local peripheral = {}
    local enveloppes = setmetatable({}, { __mode = "k" })
    local function noms()
      local liste = {}
      for nom in pairs(branches) do liste[#liste + 1] = nom end
      table.sort(liste)
      return liste
    end
    local function branche(objet)
      if type(objet) == "table" then return branches[enveloppes[objet]] end
      return branches[objet]
    end
    peripheral.getNames = noms
    function peripheral.isPresent(nom) return branches[nom] ~= nil end
    function peripheral.getType(objet)
      local trouve = branche(objet)
      return trouve and trouve.type or nil
    end
    function peripheral.hasType(objet, genre)
      local trouve = branche(objet)
      if not trouve then return nil end
      return trouve.type == genre
    end
    function peripheral.getMethods(nom)
      if not branches[nom] then return nil end
      local liste = {}
      for methode in pairs(branches[nom].methodes) do liste[#liste + 1] = methode end
      table.sort(liste)
      return liste
    end
    function peripheral.call(nom, methode, ...)
      if not branches[nom] then error("No peripheral attached", 2) end
      local fonction = branches[nom].methodes[methode]
      if not fonction then error("No such method " .. tostring(methode), 2) end
      return fonction(...)
    end
    function peripheral.wrap(nom)
      local trouve = branches[nom]
      if not trouve then return nil end
      local objet = {}
      for methode, fonction in pairs(trouve.methodes) do
        objet[methode] = function(...)
          if branches[nom] ~= trouve then error("Peripheral " .. nom .. " is detached", 2) end
          return fonction(...)
        end
      end
      enveloppes[objet] = nom
      return objet
    end
    function peripheral.getName(objet)
      if not enveloppes[objet] then error("bad argument #1 (table is not a peripheral)", 2) end
      return enveloppes[objet]
    end
    function peripheral.find(genre, filtre_objet)
      local trouves = {}
      for _, nom in ipairs(noms()) do
        if branches[nom].type == genre then
          local objet = peripheral.wrap(nom)
          if not filtre_objet or filtre_objet(nom, objet) then trouves[#trouves + 1] = objet end
        end
      end
      return table.unpack(trouves)
    end
    G.peripheral = peripheral

    -- redstone : sorties mémorisées sans effet, entrées toujours éteintes.
    local sorties = {}
    local redstone = {}
    local function cote(nom)
      for _, connu in ipairs(COTES) do
        if connu == nom then return nom end
      end
      error("bad argument #1 (unknown option " .. tostring(nom) .. ")", 3)
    end
    function redstone.getSides() return copie(COTES) end
    function redstone.setOutput(nom, valeur) sorties[cote(nom)] = valeur and 15 or 0 end
    function redstone.getOutput(nom) return (sorties[cote(nom)] or 0) > 0 end
    function redstone.setAnalogOutput(nom, valeur) sorties[cote(nom)] = valeur end
    function redstone.getAnalogOutput(nom) return sorties[cote(nom)] or 0 end
    function redstone.getInput(nom) cote(nom) return false end
    function redstone.getAnalogInput(nom) cote(nom) return 0 end
    function redstone.getBundledInput(nom) cote(nom) return 0 end
    function redstone.getBundledOutput(nom) cote(nom) return 0 end
    function redstone.setBundledOutput(nom) cote(nom) end
    function redstone.testBundledInput(nom) cote(nom) return false end
    redstone.setAnalogueOutput, redstone.getAnalogueOutput = redstone.setAnalogOutput, redstone.getAnalogOutput
    redstone.getAnalogueInput = redstone.getAnalogInput
    G.redstone, G.rs = redstone, redstone

    -- shell, require et package : propres à chaque programme, comme dans CC.
    local shell = {}
    local dossier = ""
    local pile = {}

    local function creer_paquet(env)
      local paquet = { config = "/\n;\n?\n!\n-", preload = {}, loaded = {}, path = CHEMIN_REQUIRE }
      for _, nom in ipairs({ "_G", "string", "table", "math", "coroutine", "utf8" }) do paquet.loaded[nom] = G[nom] end
      paquet.loaded.package = paquet
      function paquet.searchpath(nom, chemins)
        local relatif = nom:gsub("%.", "/")
        local erreurs = {}
        for modele in chemins:gmatch("[^;]+") do
          local chemin = modele:gsub("%?", relatif)
          if chemin:sub(1, 1) ~= "/" then chemin = fs.combine(dossier, chemin) end
          if fs.exists(chemin) and not fs.isDir(chemin) then return chemin end
          erreurs[#erreurs + 1] = "no file '" .. chemin .. "'"
        end
        return nil, table.concat(erreurs, "\n  ")
      end
      paquet.loaders = {
        function(nom)
          if paquet.preload[nom] then return paquet.preload[nom], ":preload:" end
          return nil, "no field package.preload['" .. nom .. "']"
        end,
        function(nom)
          local chemin, erreur = paquet.searchpath(nom, paquet.path)
          if not chemin then return nil, erreur end
          local fonction, echec = G.loadfile(chemin, nil, env)
          if not fonction then return nil, echec end
          return fonction, chemin
        end,
      }
      paquet.searchers = paquet.loaders
      local sentinelle = {}
      local function require(nom)
        if type(nom) ~= "string" then error("bad argument #1 (string expected, got " .. type(nom) .. ")", 2) end
        if paquet.loaded[nom] == sentinelle then error("loop or previous error loading module '" .. nom .. "'", 0) end
        if paquet.loaded[nom] then return paquet.loaded[nom] end
        local message_erreur = "module '" .. nom .. "' not found:"
        for _, chercheur in ipairs(paquet.loaders) do
          local chargeur, info = chercheur(nom)
          if chargeur then
            paquet.loaded[nom] = sentinelle
            local resultat = chargeur(nom, info)
            if resultat == nil then resultat = true end
            paquet.loaded[nom] = resultat
            return resultat
          end
          message_erreur = message_erreur .. "\n  " .. info
        end
        error(message_erreur, 2)
      end
      return require, paquet
    end

    local function charger_programme(chemin, arguments)
      local env = setmetatable({ shell = shell }, { __index = G })
      env.require, env.package = creer_paquet(env)
      env.arg = { [0] = chemin, table.unpack(arguments) }
      return G.loadfile(chemin, nil, env)
    end

    function shell.dir() return dossier end
    function shell.setDir(chemin)
      local normal = fs.combine(chemin)
      if not fs.isDir(normal) then error("Not a directory", 2) end
      dossier = normal
    end
    function shell.resolve(chemin)
      local premier = chemin:sub(1, 1)
      if premier == "/" or premier == "\\" then return fs.combine(chemin) end
      return fs.combine(dossier, chemin)
    end
    function shell.resolveProgram(commande)
      local chemin = shell.resolve(commande)
      for _, essai in ipairs({ chemin, chemin .. ".lua" }) do
        if fs.exists(essai) and not fs.isDir(essai) then return essai end
      end
      return nil
    end
    function shell.getRunningProgram() return pile[#pile] end
    function shell.path() return ".:/rom/programs" end
    function shell.exit() end
    function shell.run(...)
      local mots = {}
      for mot in table.concat({ ... }, " "):gmatch("%S+") do mots[#mots + 1] = mot end
      local commande = table.remove(mots, 1)
      if not commande then return false end
      local chemin = shell.resolveProgram(commande)
      if not chemin then
        G.printError("No such program")
        return false
      end
      local fonction, erreur = charger_programme(chemin, mots)
      if not fonction then
        G.printError(erreur)
        return false
      end
      pile[#pile + 1] = chemin
      local ok, echec = pcall(fonction, table.unpack(mots))
      pile[#pile] = nil
      if not ok and echec ~= nil and echec ~= "" then G.printError(tostring(echec)) end
      return ok
    end
    function os_.run(env, chemin, ...)
      setmetatable(env, { __index = G })
      local fonction, erreur = G.loadfile(chemin, nil, env)
      local ok, echec = fonction ~= nil, erreur
      if fonction then ok, echec = pcall(fonction, ...) end
      if not ok and echec ~= nil and echec ~= "" then G.printError(tostring(echec)) end
      return ok
    end

    local function principal()
      local chemin = fs.combine(options.entree)
      local fonction, erreur = charger_programme(chemin, {})
      if not fonction then
        G.printError(erreur)
        etat, message = "erreur", erreur
        return
      end
      pile[1] = chemin
      local ok, echec = xpcall(fonction, function(objet)
        en_cours = false
        return { message = tostring(objet), trace = debug.traceback(tostring(objet), 2) }
      end)
      if ok then
        etat = "fini"
      elseif echec.message == "Terminated" then
        G.printError("Terminated")
        etat, message = "fini", "Terminated"
      else
        G.printError(echec.message)
        etat, message, trace = "erreur", echec.message, echec.trace
      end
    end
    return principal
  end

  --- (Re)démarre le programme : globales, file, minuteries et terminal neufs ; disque, moniteur et périphériques gardés.
  function ordi.demarrer()
    ordi.terminal = enregistreur.creer(TERMINAL[1], TERMINAL[2])
    file, minuteries, prochain_id = {}, {}, 0
    filtre, demande, lance, en_cours = nil, nil, false, false
    etat, message, trace = "attente", nil, nil
    demarrage = hote.maintenant()
    fil = creer_coroutine(construire(ordi.terminal))
  end

  local function deplacer_minuteries()
    local maintenant = hote.maintenant()
    local echues = {}
    for id, echeance in pairs(minuteries) do
      if echeance <= maintenant then echues[#echues + 1] = id end
    end
    table.sort(echues, function(a, b)
      if minuteries[a] ~= minuteries[b] then return minuteries[a] < minuteries[b] end
      return a < b
    end)
    for _, id in ipairs(echues) do
      minuteries[id] = nil
      enfiler("timer", id)
    end
  end

  local function reprendre(evenement)
    if filtre ~= nil and evenement[1] ~= filtre and evenement[1] ~= "terminate" then return end
    debut_tranche, en_cours = hote.maintenant(), true
    local ok, resultat = coroutine.resume(fil, table.unpack(evenement, 1, evenement.n))
    en_cours = false
    if not ok then
      etat, message, trace = "erreur", tostring(resultat), debug.traceback(fil, tostring(resultat))
    elseif coroutine.status(fil) ~= "dead" then
      filtre = type(resultat) == "string" and resultat or nil
    end
  end

  local function delai()
    if etat ~= "attente" then return -1 end
    if demande or not lance or #file > 0 then return 0 end
    local proche
    for _, echeance in pairs(minuteries) do
      if not proche or echeance < proche then proche = echeance end
    end
    if not proche then return -1 end
    return math.max(0, proche - hote.maintenant())
  end

  --- Traite les événements dus pendant au plus une tranche. Renvoie l'état (attente, fini, erreur, arrete), le délai en
  --- ms avant le prochain réveil utile (-1 : aucun, seule une action de l'utilisateur relancera), le message et la trace.
  function ordi.executer()
    local debut = hote.maintenant()
    while etat == "attente" do
      if demande == "reboot" then ordi.demarrer() end
      if demande == "arret" then
        etat, demande = "arrete", nil
        break
      end
      local evenement
      if not lance then
        lance, evenement = true, { n = 0 }
      else
        deplacer_minuteries()
        evenement = table.remove(file, 1)
      end
      if not evenement then break end
      reprendre(evenement)
      if hote.maintenant() - debut > TRANCHE then break end
    end
    return etat, delai(), message, trace
  end

  --- Ajoute un événement à la file (touche, terminate...).
  function ordi.evenement(...) enfiler(...) end

  --- Toucher du moniteur au point (px, py) de son affichage de `largeur_px` x `hauteur_px` ; renvoie la case.
  function ordi.toucher(px, py, largeur_px, hauteur_px)
    local x, y = ordinateur.case_du_clic(px, py, largeur_px, hauteur_px, moniteur.getSize())
    enfiler("monitor_touch", nom_moniteur, x, y)
    return x, y
  end

  --- Événement de souris `nom` (mouse_click, mouse_up) sur le terminal, même convention que toucher.
  function ordi.souris(nom, bouton, px, py, largeur_px, hauteur_px)
    local x, y = ordinateur.case_du_clic(px, py, largeur_px, hauteur_px, ordi.terminal.getSize())
    enfiler(nom, bouton, x, y)
  end

  --- Nouvelle taille du moniteur en cases ; émet monitor_resize.
  function ordi.redimensionner(largeur, hauteur)
    moniteur.redimensionner(largeur, hauteur)
    enfiler("monitor_resize", nom_moniteur)
  end

  --- Code CC de la touche nommée comme dans `keys` (nil si inconnue).
  function ordi.code_touche(nom) return KEYS[nom] end

  --- Faux périphériques proposés, une ligne « nom type » chacun.
  function ordi.faux_peripheriques()
    local lignes = {}
    for _, entree in ipairs(faux_peripheriques) do lignes[#lignes + 1] = entree.nom .. " " .. entree.type end
    return table.concat(lignes, "\n")
  end

  --- Branche (`oui` vrai) ou débranche le faux périphérique `nom` ; émet peripheral ou peripheral_detach.
  function ordi.brancher(nom, oui)
    for _, entree in ipairs(faux_peripheriques) do
      if entree.nom == nom and oui and not branches[nom] then
        branches[nom] = { type = entree.type, methodes = entree.methodes(hote) }
        enfiler("peripheral", nom)
      elseif entree.nom == nom and not oui and branches[nom] then
        branches[nom] = nil
        enfiler("peripheral_detach", nom)
      end
    end
  end

  return ordi
end

return ordinateur
