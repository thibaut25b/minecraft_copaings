-- Bout en bout : le point d'entrée tourne quelques tours contre les faux périphériques, sans jamais lever.

local verif = require("verif")
colors = require("faux.couleurs")
local systeme = require("faux.systeme")
local faux_pont = require("faux.pont_me")
local faux_integrateur = require("faux.integrateur")
local faux_moniteur = require("faux.moniteur")
local vues = require("colonie.vues")

local depaqueter = table.unpack or unpack

-- Monde par défaut : une colonie, une requête de 16 planches, 64 planches en stock, un moniteur 60x24.
local function monde()
  local m = { disque = systeme.installer(), redstone = {}, terminal = faux_moniteur.nouveau(51, 19) }
  m.pont, m.etat_pont = faux_pont.creer()
  m.integrateur, m.colonie = faux_integrateur.creer()
  m.moniteur = faux_moniteur.nouveau(60, 24)
  -- Comme CC : une échelle hors de 0.5 à 5 lève une erreur.
  m.moniteur.setTextScale = function(echelle)
    if type(echelle) ~= "number" or echelle < 0.5 or echelle > 5 then error("Expected number in range 0.5-5", 0) end
    m.echelle = echelle
  end
  m.etat_pont.stock["minecraft:oak_planks"] = 64
  m.colonie.requetes = { {
    id = "r1", displayName = "16 Planches", description = "", state = "IN_PROGRESS", count = 16, minCount = 16,
    items = { { name = "minecraft:oak_planks", count = 16, displayName = "Planches", tags = {} } },
    target = { x = 1, y = 64, z = 1 },
  } }
  return m
end

-- Lance le point d'entrée : chaque boucle est une coroutine, reprise `tours` fois ; `evenements[tour]` est
-- l'événement distribué à ce tour (un simple timer sinon).
local function lancer(m, tours, evenements, saboter)
  local presents = { colony_integrator = m.integrateur, me_bridge = m.pont, monitor = m.moniteur }
  peripheral = { find = function(type_voulu) return presents[type_voulu] end }
  term = { current = function() return m.terminal end }
  redstone = {
    getSides = function() return { "top", "bottom", "left", "right", "front", "back" } end,
    setOutput = function(cote, actif) m.redstone[cote] = actif end,
  }
  if saboter then saboter() end
  textutils.formatTime = function() return "12:30" end
  os.time = function() return 12.5 end
  os.queueEvent = function() end
  os.pullEvent = function() return coroutine.yield() end
  sleep = function() coroutine.yield() end
  parallel = { waitForAny = function(...)
    local boucles = {}
    for i, fonction in ipairs({ ... }) do boucles[i] = coroutine.create(fonction) end
    for tour = 0, tours do
      local evenement = (evenements or {})[tour] or { "colonie_affichage" }
      for _, boucle in ipairs(boucles) do
        local ok, erreur = coroutine.resume(boucle, depaqueter(evenement))
        if not ok then error(erreur, 0) end
      end
    end
  end }
  assert(loadfile("projets/colonie/principal.lua"))()
end

local function colonne_onglet(cible, page)
  local largeur = cible.getSize()
  for x = 1, largeur do
    if vues.page_touchee(cible, x, 2) == page then return x end
  end
  error("onglet introuvable : " .. page)
end

return {
  requete_en_stock_est_livree_et_la_colonie_affichee = function()
    local m = monde()
    lancer(m, 2)
    verif.egal(m.etat_pont.livre["minecraft:oak_planks"], 16)
    verif.vrai(m.moniteur.chercher("Valfleuri"), "le nom de la colonie doit être à l'écran")
    verif.vrai(m.disque.disque["colonie.cfg"] ~= nil, "la config doit être créée au premier lancement")
  end,

  requete_n_est_pas_relivree_aux_passes_suivantes = function()
    local m = monde()
    lancer(m, 6)
    verif.egal(m.etat_pont.livre["minecraft:oak_planks"], 16)
  end,

  toucher_un_onglet_change_de_page = function()
    local m = monde()
    local x = colonne_onglet(m.moniteur, "requetes")
    lancer(m, 3, { [2] = { "monitor_touch", "top", x, 2 } })
    verif.vrai(m.moniteur.chercher("16 Planches"), "la page des requêtes doit lister la requête")
  end,

  sans_pont_me_l_erreur_s_affiche_et_la_boucle_continue = function()
    local m = monde()
    m.pont = nil
    lancer(m, 3)
    verif.vrai(m.moniteur.chercher("Pont ME introuvable"))
  end,

  hors_colonie_l_erreur_s_affiche_et_la_boucle_continue = function()
    local m = monde()
    m.colonie.en_colonie = false
    lancer(m, 3)
    verif.vrai(m.moniteur.chercher("hors colonie"))
  end,

  sans_moniteur_le_tableau_de_bord_va_sur_le_terminal = function()
    local m = monde()
    m.moniteur = nil
    lancer(m, 2)
    verif.vrai(m.terminal.chercher("Valfleuri"))
  end,

  raid_active_la_redstone_du_cote_regle = function()
    local m = monde()
    m.disque.disque["colonie.cfg"] = textutils.serialize({ cote_alarme = "back" })
    m.colonie.raid = true
    lancer(m, 2)
    verif.egal(m.redstone.back, true)
    verif.vrai(m.moniteur.chercher("RAID"))
  end,

  cote_d_alarme_inconnu_est_signale_sans_planter = function()
    local m = monde()
    m.disque.disque["colonie.cfg"] = textutils.serialize({ cote_alarme = "dessus" })
    lancer(m, 2)
    verif.vrai(m.moniteur.chercher("cote_alarme inconnu"))
  end,

  -- Non-régression : une échelle invalide dans la config tuait le programme au démarrage.
  echelle_de_texte_invalide_est_signalee_sans_arreter_le_programme = function()
    local m = monde()
    m.disque.disque["colonie.cfg"] = textutils.serialize({ echelle_texte = 8 })
    lancer(m, 3)
    verif.vrai(m.moniteur.chercher("echelle_texte"))
    verif.egal(m.etat_pont.livre["minecraft:oak_planks"], 16)
  end,

  -- Non-régression : une erreur inattendue dans une boucle arrêtait les trois.
  erreur_inattendue_d_une_boucle_n_arrete_pas_les_autres = function()
    local m = monde()
    m.disque.disque["colonie.cfg"] = textutils.serialize({ cote_alarme = "back" })
    lancer(m, 3, nil, function() redstone.setOutput = function() error("redstone en panne", 0) end end)
    verif.vrai(m.moniteur.chercher("redstone en panne"), "l'erreur doit être à l'écran")
    verif.egal(m.etat_pont.livre["minecraft:oak_planks"], 16)
    verif.vrai(m.disque.disque["colonie.log"]:find("redstone en panne", 1, true), "l'erreur doit être journalisée")
  end,

  motif_d_exclusion_invalide_est_signale_a_l_ecran = function()
    local m = monde()
    m.disque.disque["colonie.cfg"] = textutils.serialize({ exclusions = { 42 } })
    lancer(m, 2)
    verif.vrai(m.moniteur.chercher("Exclusion invalide"))
  end,
}
