-- Bout en bout : le point d'entrée tourne quelques tours contre le faux ME Bridge, sans jamais lever.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local pont_me = require("faux.pont_me")
local coffre = require("faux.coffre")
local faux_moniteur = require("faux.moniteur")
local vers_cc = require("commun.texte").vers_cc

local depaqueter = table.unpack or unpack
local classement = require("production.classement")
local flux = require("production.flux")

local TYPES = { pont_0 = "me_bridge", monitor_0 = "monitor", chest_0 = "minecraft:chest" }
local FER = "minecraft:iron_ingot"

-- Monde par défaut : un pont avec 100 lingots de fer (nom AE « Iron Ingot »), un moniteur, un objet suivi.
local function monde(reglages)
  local m = { disque = systeme.installer(), terminal = faux_moniteur.nouveau(51, 19) }
  local pont, etat = pont_me.creer()
  etat.stock[FER] = 100
  etat.noms[FER] = "Iron Ingot"
  m.pont, m.etat_pont = pont, etat
  m.presents = { pont_0 = pont, monitor_0 = faux_moniteur.nouveau(100, 38) }
  m.presents.monitor_0.setTextScale = function() end
  m.disque.disque["production.cfg"] = textutils.serialize(reglages or { periode = 2, tout = false, objets = { { objet = FER, nom = "" } } })
  return m
end

local function ecran(m)
  return m.presents.monitor_0 or m.terminal
end

-- Lance le point d'entrée : chaque boucle est une coroutine reprise `tours` fois ; chaque `sleep` fait avancer
-- l'horloge de 2 s. `evenements(tour)` donne l'événement du tour (un rafraîchissement sinon).
local function lancer(m, tours, evenements, saboter)
  peripheral = {
    find = function(type_voulu)
      for nom, present in pairs(m.presents) do
        if TYPES[nom] == type_voulu then return present end
      end
      return nil
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
  sleep = function()
    m.disque.epoch = m.disque.epoch + 2000
    coroutine.yield()
  end
  if saboter then saboter() end
  parallel = { waitForAny = function(...)
    local boucles = {}
    for i, fonction in ipairs({ ... }) do boucles[i] = coroutine.create(fonction) end
    for tour = 0, tours do
      local evenement = (evenements and evenements(tour)) or { "production_affichage" }
      for _, boucle in ipairs(boucles) do
        local ok, erreur = coroutine.resume(boucle, depaqueter(evenement))
        if not ok then error(erreur, 0) end
      end
    end
  end }
  assert(loadfile("projets/production/principal.lua"))()
end

local function present(m, motif)
  verif.vrai(ecran(m).chercher(vers_cc(motif)), "introuvable à l'écran : " .. motif .. "\n" .. ecran(m).texte())
end

local function toucher(m, motif)
  local x, y = ecran(m).chercher(vers_cc(motif))
  if not x then error("introuvable à l'écran : " .. motif .. "\n" .. ecran(m).texte()) end
  return { "monitor_touch", "monitor_0", x, y }
end

return {
  le_stock_le_nom_de_l_ae_et_le_debit_s_affichent = function()
    local m = monde()
    lancer(m, 4, function(tour)
      m.etat_pont.stock[FER] = 100 + 10 * tour
      return { "production_affichage" }
    end)
    present(m, "Iron Ingot")
    present(m, "+300")
  end,

  la_premiere_mesure_sert_de_base_et_le_dit = function()
    local m = monde()
    lancer(m, 0)
    present(m, "Base prise : premiers débits dans")
  end,

  les_noms_lus_dans_l_ae_sont_retenus_quand_le_pont_disparait = function()
    local m = monde()
    lancer(m, 3, function(tour)
      if tour == 2 then m.etat_pont.exceptions.getItems = "pont débranché" end
      return { "production_affichage" }
    end)
    present(m, "Iron Ingot")
    present(m, "pont débranché")
  end,

  sans_pont_l_erreur_s_affiche_se_journalise_une_fois_et_rien_ne_leve = function()
    local m = monde()
    m.presents.pont_0 = nil
    lancer(m, 4)
    present(m, "ME Bridge absent")
    local _, nombre = m.disque.disque["production.log"]:gsub("ME Bridge absent", "")
    verif.egal(nombre, 1)
  end,

  le_pont_nomme_dans_la_config_est_celui_qui_est_lu = function()
    local m = monde({ pont = "pont_2", periode = 2, tout = false, objets = { { objet = FER, nom = "" } } })
    local autre, etat = pont_me.creer()
    etat.stock[FER] = 777
    m.presents.pont_2 = autre
    lancer(m, 2)
    present(m, "777")
  end,

  toucher_une_unite_change_les_debits_affiches = function()
    local m = monde()
    lancer(m, 5, function(tour)
      m.etat_pont.stock[FER] = 100 + tour
      if tour == 5 then return toucher(m, "/h") end
      return { "production_affichage" }
    end)
    present(m, "+1 800")
  end,

  toucher_reset_remet_le_depart_de_l_objet_a_zero = function()
    local m = monde()
    lancer(m, 7, function(tour)
      m.etat_pont.stock[FER] = 100 + 10 * tour
      if tour == 5 then return toucher(m, "Reset") end
      return { "production_affichage" }
    end)
    local _, y = ecran(m).chercher(vers_cc("Départ"))
    verif.vrai(ecran(m).ligne(y):find("+20 en 4 s", 1, true), ecran(m).ligne(y))
  end,

  toucher_une_ligne_choisit_l_objet_dont_le_detail_s_affiche = function()
    local m = monde({ periode = 2, tout = false,
      objets = { { objet = FER, nom = "" }, { objet = "minecraft:gold_ingot", nom = "Or" } } })
    lancer(m, 3, function(tour)
      if tour == 3 then return toucher(m, "Or") end
      return { "production_affichage" }
    end)
    local _, y = ecran(m).chercher("Reset")
    verif.vrai(ecran(m).ligne(y):find("Or", 1, true), ecran(m).ligne(y))
  end,

  la_vue_tout_ne_liste_que_ce_qui_bouge = function()
    local m = monde({ periode = 2, objets = { { objet = FER, nom = "" } } })
    m.etat_pont.stock["minecraft:stone"] = 64
    m.etat_pont.noms["minecraft:stone"] = "Stone"
    lancer(m, 4, function(tour)
      m.etat_pont.stock[FER] = 100 + 10 * tour
      return { "production_affichage" }
    end)
    present(m, "Iron Ingot")
    verif.egal(ecran(m).chercher("Stone"), nil)
  end,

  le_classement_se_calcule_par_mesure_ou_par_action_jamais_par_dessin = function()
    local m = monde()
    local original, appels = classement.ecran, 0
    classement.ecran = function(...)
      appels = appels + 1
      return original(...)
    end
    local ok, erreur = pcall(lancer, m, 5, function(tour)
      if tour == 5 then return toucher(m, "1 h") end
      return { "monitor_resize" }
    end)
    classement.ecran = original
    verif.vrai(ok, tostring(erreur))
    verif.egal(appels, #pont_me.appels_de(m.etat_pont, "getItems") + 1)
  end,

  une_coupure_est_ignoree_et_affichee = function()
    local m = monde({ periode = 2, objets = { { objet = FER, nom = "" } } })
    for i = 1, 30 do m.etat_pont.stock["a:objet_" .. i] = 50 end
    lancer(m, 3, function(tour)
      if tour == 3 then
        for i = 1, 30 do m.etat_pont.stock["a:objet_" .. i] = nil end
      end
      return { "production_affichage" }
    end)
    present(m, "Lecture ignorée : réseau AE incomplet")
  end,

  la_mesure_se_fait_d_un_bloc_rend_la_main_par_sleep_et_aucun_evenement_filtre_n_est_attendu = function()
    local m = monde({ periode = 2, objets = { { objet = FER, nom = "" } } })
    for i = 1, 2500 do m.etat_pont.stock["a:objet_" .. i] = i end
    local filtres, sommeils = {}, 0
    lancer(m, 6, function(tour)
      if tour == 4 then return toucher(m, "1 h") end
      return { "production_affichage" }
    end, function()
      os.pullEvent = function(filtre)
        if filtre ~= nil then filtres[#filtres + 1] = filtre end
        return coroutine.yield()
      end
      local dormir = sleep
      sleep = function()
        sommeils = sommeils + 1
        dormir()
      end
    end)
    verif.egal(filtres, {})
    verif.egal(sommeils, #pont_me.appels_de(m.etat_pont, "getItems"))
  end,

  reordonner_le_coffre_modele_ne_refait_pas_de_base = function()
    local m = monde({ periode = 2, tout = false, coffre = "chest_0", objets = { { objet = FER, nom = "" } } })
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [1] = { name = "minecraft:gold_ingot", count = 1 },
      [2] = { name = "minecraft:copper_ingot", count = 1 } })
    m.presents.chest_0 = c
    local rebaser, rebases = flux.rebaser, 0
    flux.rebaser = function(...)
      rebases = rebases + 1
      return rebaser(...)
    end
    local ok, erreur = pcall(lancer, m, 5, function(tour)
      if tour == 3 then c.emplacements[1], c.emplacements[2] = c.emplacements[2], c.emplacements[1] end
      return { "production_affichage" }
    end)
    flux.rebaser = rebaser
    verif.vrai(ok, tostring(erreur))
    verif.egal(rebases, 0)
  end,

  un_ajout_d_ids_prend_une_base_sans_signaler_de_coupure = function()
    local objets = {}
    for i = 1, 20 do
      objets[i] = { objet = "a:objet_" .. i, nom = "" }
    end
    local m = monde({ periode = 2, tout = false, coffre = "chest_0", objets = objets })
    for i = 1, 30 do m.etat_pont.stock["a:objet_" .. i] = 50 end
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27)
    m.presents.chest_0 = c
    lancer(m, 3, function(tour)
      if tour == 3 then
        for i = 21, 30 do c.emplacements[i - 20] = { name = "a:objet_" .. i, count = 1 } end
      end
      return { "production_affichage" }
    end)
    verif.egal(ecran(m).chercher(vers_cc("réseau AE incomplet")), nil, ecran(m).texte())
  end,

  config_fautive_est_signalee_et_le_reste_tourne = function()
    local m = monde({ periode = 2, tout = false, objets = { { objet = FER, nom = "" }, { objet = FER, nom = "" } } })
    lancer(m, 2)
    present(m, "déjà suivi")
    present(m, "Iron Ingot")
  end,

  sans_moniteur_le_tableau_de_bord_va_sur_le_terminal = function()
    local m = monde()
    m.presents.monitor_0 = nil
    lancer(m, 2)
    present(m, "Iron Ingot")
  end,

  erreur_inattendue_s_affiche_et_se_journalise_sans_arreter = function()
    local m = monde()
    lancer(m, 3, nil, function()
      local trouver = peripheral.find
      peripheral.find = function(type_voulu)
        if type_voulu == "me_bridge" then error("modem en panne", 0) end
        return trouver(type_voulu)
      end
    end)
    present(m, "modem en panne")
    verif.vrai(m.disque.disque["production.log"]:find("modem en panne", 1, true))
  end,

  un_id_nouveau_en_mode_suivi_ne_compte_pas_son_stock_comme_production = function()
    local m = monde({ periode = 2, tout = false, coffre = "chest_0", objets = { { objet = FER, nom = "" } } })
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27)
    m.presents.chest_0 = c
    m.etat_pont.stock["minecraft:gold_ingot"] = 55
    m.etat_pont.noms["minecraft:gold_ingot"] = "Gold Ingot"
    lancer(m, 5, function(tour)
      if tour == 2 then c.emplacements[3] = { name = "minecraft:gold_ingot", count = 1 } end
      return { "production_affichage" }
    end)
    present(m, "Iron Ingot")
    local _, y = ecran(m).chercher("Gold Ingot")
    verif.vrai(y, ecran(m).texte())
    verif.egal(ecran(m).ligne(y):find("+", 1, true), nil, ecran(m).ligne(y))
  end,

  un_item_retire_du_coffre_modele_disparait_et_la_selection_retombe_sur_le_premier = function()
    local m = monde({ periode = 2, tout = false, coffre = "chest_0", objets = { { objet = FER, nom = "" } } })
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [1] = { name = "minecraft:gold_ingot", count = 1 } })
    m.presents.chest_0 = c
    m.etat_pont.stock["minecraft:gold_ingot"] = 55
    m.etat_pont.noms["minecraft:gold_ingot"] = "Gold Ingot"
    lancer(m, 6, function(tour)
      if tour == 2 then return toucher(m, "Gold Ingot") end
      if tour == 4 then c.emplacements[1] = nil end
      return { "production_affichage" }
    end)
    verif.egal(ecran(m).chercher("Gold Ingot"), nil)
    local _, y = ecran(m).chercher("Reset")
    verif.vrai(ecran(m).ligne(y):find("Iron Ingot", 1, true), ecran(m).ligne(y))
  end,

  un_coffre_modele_absent_s_affiche_se_journalise_et_la_config_reste_suivie = function()
    local m = monde({ periode = 2, tout = false, coffre = "chest_9", objets = { { objet = FER, nom = "" } } })
    lancer(m, 4)
    present(m, "Coffre modèle absent : chest_9")
    present(m, "Iron Ingot")
    local _, nombre = m.disque.disque["production.log"]:gsub("Coffre modèle absent", "")
    verif.egal(nombre, 1)
  end,

  un_coffre_modele_en_panne_s_affiche_et_garde_son_dernier_contenu_et_son_historique = function()
    local m = monde({ periode = 2, tout = false, coffre = "chest_0", objets = { { objet = FER, nom = "" } } })
    local c = coffre.nouveau(coffre.reseau(), "chest_0", 27, { [1] = { name = "minecraft:gold_ingot", count = 1 } })
    m.presents.chest_0 = c
    m.etat_pont.noms["minecraft:gold_ingot"] = "Gold Ingot"
    lancer(m, 8, function(tour)
      m.etat_pont.stock["minecraft:gold_ingot"] = 100 + 10 * tour
      if tour == 2 then return toucher(m, "Gold Ingot") end
      if tour == 4 then c.panne = "coffre débranché" end
      if tour == 6 then c.panne = nil end
      return { "production_affichage" }
    end)
    present(m, "Iron Ingot")
    present(m, "Gold Ingot")
    verif.vrai(m.disque.disque["production.log"]:find("coffre débranché", 1, true))
    local _, y = ecran(m).chercher(vers_cc("Départ"))
    verif.vrai(ecran(m).ligne(y):find("+80 en 16 s", 1, true), ecran(m).ligne(y))
  end,

  sans_coffre_configure_le_premier_inventaire_du_reseau_n_est_pas_pris = function()
    local m = monde({ periode = 2, tout = false, objets = { { objet = FER, nom = "" } } })
    m.presents.chest_0 = coffre.nouveau(coffre.reseau(), "chest_0", 27,
      { [1] = { name = "minecraft:gold_ingot", count = 1 } })
    lancer(m, 3)
    verif.egal(ecran(m).chercher("gold_ingot"), nil)
  end,
}
