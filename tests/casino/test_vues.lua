-- Écrans du casino : aucun débordement dans chaque état et chaque taille, touchers traduits par la même géométrie.

colors = require("faux.couleurs")

local verif = require("verif")
local moniteur = require("faux.moniteur")
local cible_comptable = require("casino.cible_comptable")
local caisse = require("casino.caisse")
local session = require("casino.session")
local vues = require("casino.vues")
local machine = require("casino.jeux.machine")
local crash = require("casino.jeux.crash")
local defauts = require("casino.reglages")

local TAILLES = { { 51, 19 }, { 60, 24 }, { 79, 29 }, { 100, 38 }, { 164, 81 } }

local function arret(symbole)
  for i, nom in ipairs(machine.BANDE) do
    if nom == symbole then return i end
  end
end

-- Session jouée par `etapes` ({ action } ou { attendre = s }) ; renvoie l'état et l'instant.
local function jouer(etapes, tirages, solde)
  local d = { contenu = { solde = solde or 1250 } }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat) d.contenu = etat; return true end
  local indice = 0
  local ctx = { caisse = caisse.ouvrir(d, { depart = 500, recharge = 500 }), maintenant = 10, inactivite = 90,
    hasard = function() indice = indice + 1; return (tirages or {})[indice] or 1 end }
  local etat = session.nouvelle(defauts, ctx.caisse.solde())
  for _, etape in ipairs(etapes) do
    if etape.attendre then
      ctx.maintenant = ctx.maintenant + etape.attendre
      session.avancer(etat, ctx)
    else
      session.agir(etat, etape, ctx)
    end
  end
  return etat, ctx.maintenant
end

local SEPT = arret("sept")
local function ouvrir(jeu) return { type = "ouvrir", jeu = jeu } end
local JOUER = { type = "jouer" }
local MISES = { ouvrir("roulette"), { type = "mise", pas = 3 }, { type = "case", case = "n17" },
  { type = "case", case = "rouge" }, { type = "case", case = "d2" }, { type = "case", case = "n0" } }
local function suite(a, b)
  local l = {}
  for _, e in ipairs(a) do l[#l + 1] = e end
  for _, e in ipairs(b) do l[#l + 1] = e end
  return l
end

local PIECES = { { id = "a", nom = "cuivre" }, { id = "b", nom = "fer" }, { id = "c", nom = "or" },
  { id = "d", nom = "émeraude" } }
local MONNAIES = {
  pret = { pret = true, reserve = 15000, valeurs = { a = 1, b = 10, c = 100, d = 1000 }, pieces = PIECES },
  suspendu = { pret = false, pieces = PIECES, probleme = "réserve « minecraft:chest_2 » introuvable. Visibles : "
    .. "minecraft:chest_0 (minecraft:chest), minecraft:chest_1 (minecraft:chest), left (monitor)" },
}

-- État joué du cas `cas` : { nom, étapes, tirages, solde, monnaie (clé de MONNAIES, facultative) }.
local function etat_du_cas(cas)
  local etat, maintenant = jouer(cas[2], cas[3], cas[4])
  if cas[5] then etat.monnaie, etat.unite = MONNAIES[cas[5]], "crédit" end
  return etat, maintenant
end

local ETATS = {
  { "hall", {} },
  { "hall record", { ouvrir("machine"), JOUER, { attendre = 3 }, { type = "hall" } }, { SEPT, SEPT, SEPT } },
  { "machine attente", { ouvrir("machine") } },
  { "machine tourne", { ouvrir("machine"), JOUER, { attendre = 0.5 } }, { SEPT, 1, 2 } },
  { "machine gain", { ouvrir("machine"), JOUER, { attendre = 2.2 } }, { SEPT, SEPT, SEPT } },
  { "machine perte", { ouvrir("machine"), JOUER, { attendre = 3 } }, { 2, 3, 4 } },
  { "roulette mises", MISES },
  { "roulette tourne", suite(MISES, { JOUER, { attendre = 2 } }), { 18 } },
  { "roulette fini", suite(MISES, { JOUER, { attendre = 5 } }), { 18 } },
  { "crash attente", { ouvrir("crash") } },
  { "crash monte", { ouvrir("crash"), JOUER, { attendre = 20 } }, { 9990 } },
  { "crash encaisse", { ouvrir("crash"), JOUER, { attendre = 2 }, { type = "encaisser" } }, { 9000 } },
  { "crash explose", { ouvrir("crash"), JOUER, { attendre = 40 } }, { 9000 } },
  { "crash plafond", { ouvrir("crash"), JOUER, { attendre = 40 } }, { crash.TIRAGES } },
  { "règles", { ouvrir("roulette"), { type = "regles" } } },
  { "blackjack attente", { ouvrir("blackjack") } },
  { "blackjack distribution", { ouvrir("blackjack"), JOUER, { attendre = 0.8 } }, { 2, 3, 4, 5 } },
  { "blackjack main", { ouvrir("blackjack"), JOUER, { attendre = 2 } } },
  { "blackjack fini", { ouvrir("blackjack"), JOUER, { attendre = 2 }, { type = "tirer" }, { type = "doubler" },
    { attendre = 2 }, { type = "rester" }, { attendre = 4 } } },
  { "blackjack règles", { ouvrir("blackjack"), { type = "regles" } } },
  { "refus", { ouvrir("machine"), { type = "mise", pas = 5 }, JOUER }, {}, 3 },
  { "gros solde", { ouvrir("machine") }, {}, 123456789 },
  { "hall monnaie", {}, {}, 1250, "pret" },
  { "hall suspendu", {}, {}, 0, "suspendu" },
  { "machine monnaie", { ouvrir("machine") }, {}, 1250, "pret" },
  { "blackjack monnaie", { ouvrir("blackjack"), JOUER, { attendre = 6 }, { type = "rester" }, { attendre = 6 } }, {},
    1250, "pret" },
}

-- Milieu de la dernière occurrence du texte `motif` à l'écran : les boutons sont en bas, sous les messages qui
-- peuvent les citer.
local function viser(m, motif)
  local _, hauteur = m.getSize()
  for y = hauteur, 1, -1 do
    local x = m.ligne(y):find(motif, 1, true)
    if x then return x + math.floor(#motif / 2), y end
  end
  error("introuvable : " .. motif .. "\n" .. m.texte())
end

local function dessine(etat, maintenant, largeur, hauteur)
  local m = moniteur.nouveau(largeur, hauteur)
  vues.dessiner(m, etat, maintenant)
  return m
end

return {
  aucun_debordement_dans_chaque_etat_et_chaque_taille = function()
    for _, cas in ipairs(ETATS) do
      local etat, maintenant = etat_du_cas(cas)
      for _, taille in ipairs(TAILLES) do
        local c = cible_comptable.nouvelle(taille[1], taille[2])
        vues.dessiner(c, etat, maintenant)
        verif.egal(c.debordements, 0, string.format("%s en %dx%d", cas[1], taille[1], taille[2]))
      end
    end
  end,

  zones_dans_l_ecran_sans_chevauchement_et_assez_grandes = function()
    for _, cas in ipairs(ETATS) do
      local etat = etat_du_cas(cas)
      for _, taille in ipairs(TAILLES) do
        local zones = vues.disposer(taille[1], taille[2], etat).zones
        local nom = string.format("%s en %dx%d", cas[1], taille[1], taille[2])
        for i, a in ipairs(zones) do
          verif.vrai(a.x >= 1 and a.y >= 1 and a.x + a.largeur - 1 <= taille[1] and a.y + a.hauteur - 1 <= taille[2],
            nom .. " : " .. a.cle .. " hors écran")
          if a.action then verif.vrai(a.largeur >= 2 and a.hauteur >= 1 and a.largeur * a.hauteur >= 4,
            nom .. " : " .. a.cle .. " trop petite") end
          for j = i + 1, #zones do
            local b = zones[j]
            local disjoint = a.x + a.largeur <= b.x or b.x + b.largeur <= a.x or a.y + a.hauteur <= b.y
              or b.y + b.hauteur <= a.y
            verif.vrai(disjoint, nom .. " : " .. a.cle .. " chevauche " .. b.cle)
          end
        end
      end
    end
  end,

  sous_la_taille_minimale_un_message_et_aucune_action = function()
    local etat, maintenant = jouer({})
    for _, taille in ipairs({ { 50, 19 }, { 51, 18 }, { 15, 5 }, { 1, 1 } }) do
      local m = dessine(etat, maintenant, taille[1], taille[2])
      verif.egal(m.debordements, 0)
      verif.egal(vues.action_touchee(m, etat, 2, 2), nil)
    end
    verif.vrai(dessine(etat, maintenant, 39, 13).chercher("Moniteur trop petit"))
  end,

  hall_tuiles_et_recharge_traduites_en_actions = function()
    local etat, maintenant = jouer({})
    for _, taille in ipairs(TAILLES) do
      local m = dessine(etat, maintenant, taille[1], taille[2])
      verif.egal(vues.action_touchee(m, etat, viser(m, "Recharger")).type, "recharger")
      verif.egal(vues.action_touchee(m, etat, viser(m, "Roulette")), { type = "ouvrir", jeu = "roulette",
        cle = "tuile_roulette" })
      verif.egal(vues.action_touchee(m, etat, viser(m, "Crash")).jeu, "crash")
      verif.vrai(m.chercher("jetons fictifs"), "la mention de démo doit être visible")
    end
  end,

  machine_jouer_mise_hall_et_regles_au_toucher = function()
    local etat, maintenant = jouer({ ouvrir("machine") })
    for _, taille in ipairs(TAILLES) do
      local m = dessine(etat, maintenant, taille[1], taille[2])
      verif.egal(vues.action_touchee(m, etat, viser(m, "JOUER")).type, "jouer")
      verif.egal(vues.action_touchee(m, etat, viser(m, " + ")).pas, 1)
      verif.egal(vues.action_touchee(m, etat, viser(m, "<")).type, "hall")
    end
  end,

  pendant_un_tour_les_boutons_sont_inactifs = function()
    local etat, maintenant = jouer({ ouvrir("machine"), JOUER, { attendre = 0.5 } }, { 1, 2, 3 })
    local m = dessine(etat, maintenant, 100, 38)
    verif.egal(vues.action_touchee(m, etat, viser(m, "JOUER")), nil)
    verif.egal(vues.action_touchee(m, etat, viser(m, "Hall")), nil)
  end,

  roulette_chaque_case_du_tapis_se_touche_a_son_libelle = function()
    local etat, maintenant = jouer({ ouvrir("roulette") })
    for _, taille in ipairs({ { 51, 19 }, { 100, 38 } }) do
      local m = dessine(etat, maintenant, taille[1], taille[2])
      local zones = vues.disposer(taille[1], taille[2], etat).zones
      local cases = 0
      for _, zone in ipairs(zones) do
        if zone.case then
          cases = cases + 1
          verif.egal(vues.action_touchee(m, etat, zone.x, zone.y).case, zone.case)
        end
      end
      verif.egal(cases, 37 + 12)
      local x, y = m.chercher("13-24")
      verif.egal(vues.action_touchee(m, etat, x, y).case, "d2")
    end
  end,

  blackjack_tirer_rester_doubler_au_toucher_pendant_la_main = function()
    local etat, maintenant = jouer({ ouvrir("blackjack"), JOUER, { attendre = 2 } })
    verif.egal(etat.blackjack.phase, "joueur")
    for _, taille in ipairs(TAILLES) do
      local m = dessine(etat, maintenant, taille[1], taille[2])
      verif.egal(vues.action_touchee(m, etat, viser(m, "TIRER")).type, "tirer")
      verif.egal(vues.action_touchee(m, etat, viser(m, "RESTER")).type, "rester")
      local x, y = viser(m, m.chercher("DOUBLER") and "DOUBLER" or "x2")
      verif.egal(vues.action_touchee(m, etat, x, y).type, "doubler")
    end
  end,

  crash_encaisser_remplace_jouer_pendant_la_montee = function()
    local etat, maintenant = jouer({ ouvrir("crash"), JOUER, { attendre = 2 } }, { 9000 })
    local m = dessine(etat, maintenant, 51, 19)
    verif.egal(vues.action_touchee(m, etat, viser(m, "ENCAISSER")).type, "encaisser")
    verif.egal(m.chercher("JOUER"), nil)
  end,

  regles_n_offrent_que_le_retour_au_jeu = function()
    local etat, maintenant = jouer({ ouvrir("machine"), { type = "regles" } })
    local m = dessine(etat, maintenant, 51, 19)
    verif.vrai(m.chercher("95,3 %"), m.texte())
    local zones = vues.disposer(51, 19, etat).zones
    verif.egal(#zones, 1)
    verif.egal(vues.action_touchee(m, etat, viser(m, "Retour")).type, "regles")
  end,

  appui_donne_un_retour_visuel_sur_le_bouton = function()
    local etat, maintenant = jouer({ ouvrir("machine"), { type = "mise", pas = 1, cle = "plus" } })
    local m = dessine(etat, maintenant, 100, 38)
    local x, y = viser(m, " + ")
    verif.egal(m.couleur_fond(x, y), colors.white)
    local apres = dessine(etat, maintenant + 1, 100, 38)
    verif.vrai(apres.couleur_fond(x, y) ~= colors.white)
  end,
}
