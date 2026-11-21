-- Écrans de l'aperçu du casino : hall et jeux dans leurs états marquants, joués par la vraie session sur une caisse
-- en mémoire et dessinés par le vrai `vues.dessiner`.

local theme = require("commun.theme")
local caisse = require("casino.caisse")
local session = require("casino.session")
local vues = require("casino.vues")
local machine = require("casino.jeux.machine")
local crash = require("casino.jeux.crash")
local defauts = require("casino.reglages")

local function arret(symbole)
  for i, nom in ipairs(machine.BANDE) do
    if nom == symbole then return i end
  end
end

local COULEURS = { "pique", "coeur", "carreau", "trefle" }

-- Vraie monnaie de l'aperçu : pièces par défaut, valeurs de Lightman's Currency, réserve de valeur donnée.
local VALEURS = {}
for i, piece in ipairs(defauts.pieces) do VALEURS[piece.id] = 10 ^ (i - 1) end
local function banque(reserve, probleme)
  return { pret = probleme == nil, probleme = probleme, reserve = reserve, valeurs = VALEURS, pieces = defauts.pieces }
end
local MANQUE = "réserve « minecraft:chest_2 » introuvable. Visibles : minecraft:chest_0 (minecraft:chest), "
  .. "minecraft:chest_1 (minecraft:chest), monitor_0 (monitor)"

-- Joue `etapes` sur une session neuve ; renvoie l'état et l'instant final. Une étape : { action } pour agir,
-- { attendre = secondes } pour avancer le temps, { sabot = rangs } pour fixer le sabot, { message, ton } pour un
-- message. `monnaie` (facultatif) : banque de la vraie monnaie, qui couvre aussi les mises.
local function jouer(etapes, tirages, solde, monnaie)
  local d = { contenu = { solde = solde or 1250 } }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat) d.contenu = etat; return true end
  local regles = { depart = defauts.jetons_depart, recharge = defauts.recharge }
  if monnaie then
    regles = { depart = 0, recharge = 0, unite = "crédit", couverture = function() return monnaie.reserve end }
  end
  local c = caisse.ouvrir(d, regles)
  local indice = 0
  local ctx = { caisse = c, maintenant = 100, inactivite = defauts.inactivite, hasard = function()
    indice = indice + 1
    return (tirages or {})[indice] or 1
  end }
  local etat = session.nouvelle(defauts, c.solde())
  if monnaie then etat.monnaie, etat.unite = monnaie, "crédit" end
  for _, etape in ipairs(etapes) do
    if etape.message then
      session.avertir(etat, etape.message, etape.ton, ctx.maintenant)
    elseif etape.sabot then
      local cartes = {}
      for i, rang in ipairs(etape.sabot) do cartes[i] = { rang = rang, couleur = COULEURS[i % 4 + 1] } end
      etat.blackjack.sabot = { cartes = cartes, position = 1 }
    elseif etape.attendre then
      ctx.maintenant = ctx.maintenant + etape.attendre
      session.avancer(etat, ctx)
    else
      session.agir(etat, etape, ctx)
    end
  end
  etat.appui = nil
  return etat, ctx.maintenant
end

local function ecran(nom, titre, largeur, hauteur, etapes, tirages, solde, monnaie)
  return {
    nom = nom, titre = titre, largeur = largeur, hauteur = hauteur, images = 1,
    dessiner = function(cible)
      local etat, maintenant = jouer(etapes, tirages, solde, monnaie)
      theme.appliquer(cible, "nuit")
      vues.dessiner(cible, etat, maintenant)
    end,
  }
end

local function ouvrir(jeu) return { type = "ouvrir", jeu = jeu } end
local JOUER = { type = "jouer" }
local MISE_PLUS = { type = "mise", pas = 1 }
local SEPT, CERISE = arret("sept"), arret("cerise")
local PERDANT = { arret("citron"), arret("orange"), arret("prune") }

local MISES_ROULETTE = {
  ouvrir("roulette"), MISE_PLUS, MISE_PLUS, MISE_PLUS, { type = "case", case = "n17" }, { type = "case", case = "rouge" },
  { type = "case", case = "d2" }, { type = "case", case = "pair" }, { type = "case", case = "n0" },
}
local function avec(base_etapes, suite)
  local liste = {}
  for _, etape in ipairs(base_etapes) do liste[#liste + 1] = etape end
  for _, etape in ipairs(suite) do liste[#liste + 1] = etape end
  return liste
end

local ecrans = {}
for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
  local l, h = taille[1], taille[2]
  local s = "_" .. l .. "x" .. h
  local cas = {
    { "hall", "Hall", {} },
    { "hall_record", "Hall après un gain", { ouvrir("machine"), MISE_PLUS, JOUER, { attendre = 3 }, { type = "hall" } },
      { SEPT, SEPT, SEPT } },
    { "machine_attente", "Machine : attente de mise", { ouvrir("machine"), MISE_PLUS, MISE_PLUS } },
    { "machine_tourne_1", "Machine : les rouleaux tournent", { ouvrir("machine"), JOUER, { attendre = 0.4 } },
      { SEPT, CERISE, SEPT } },
    { "machine_tourne_2", "Machine : deux rouleaux arrêtés", { ouvrir("machine"), JOUER, { attendre = 1.8 } },
      { SEPT, CERISE, SEPT } },
    { "machine_gain", "Machine : trois 7", { ouvrir("machine"), MISE_PLUS, MISE_PLUS, JOUER, { attendre = 2.2 } },
      { SEPT, SEPT, SEPT } },
    { "machine_perte", "Machine : perte", { ouvrir("machine"), MISE_PLUS, JOUER, { attendre = 2.5 } }, PERDANT },
    { "roulette_mises", "Roulette : mises posées", MISES_ROULETTE },
    { "roulette_tourne", "Roulette : la bille roule", avec(MISES_ROULETTE, { JOUER, { attendre = 1.5 } }), { 18 } },
    { "roulette_gain", "Roulette : le 17 sort", avec(MISES_ROULETTE, { JOUER, { attendre = 5 } }), { 18 } },
    { "roulette_perte", "Roulette : le 11 sort", avec(MISES_ROULETTE, { JOUER, { attendre = 5 } }), { 12 } },
    { "crash_attente", "Crash : attente de mise", { ouvrir("crash") } },
    { "crash_monte", "Crash : le multiplicateur monte", { ouvrir("crash"), MISE_PLUS, MISE_PLUS, JOUER,
      { attendre = 7 } }, { 9500 } },
    { "crash_encaisse", "Crash : encaissé", { ouvrir("crash"), MISE_PLUS, MISE_PLUS, JOUER,
      { attendre = crash.instant(180) + 0.01 }, { type = "encaisser" } }, { 6866 } },
    { "crash_explose", "Crash : explosion", { ouvrir("crash"), MISE_PLUS, MISE_PLUS, JOUER, { attendre = 12 } },
      { 6866 } },
    { "regles_machine", "Règles de la machine", { ouvrir("machine"), { type = "regles" } } },
    { "bj_attente", "Blackjack : attente de mise", { ouvrir("blackjack") } },
    { "bj_distribution", "Blackjack : distribution", { ouvrir("blackjack"), { sabot = { 5, 10, 4, 7, 3 } }, JOUER,
      { attendre = 0.8 } } },
    { "bj_main", "Blackjack : main en cours", { ouvrir("blackjack"), { sabot = { 5, 10, 4, 7, 3 } }, JOUER,
      { attendre = 2 }, { type = "tirer" }, { attendre = 1 } } },
    { "bj_double", "Blackjack : doublé et gagné", { ouvrir("blackjack"), { sabot = { 5, 10, 6, 7, 10, 4 } }, JOUER,
      { attendre = 2 }, { type = "doubler" }, { attendre = 3 } } },
    { "bj_gagne", "Blackjack : gagné", { ouvrir("blackjack"), { sabot = { 10, 10, 9, 7 } }, JOUER, { attendre = 2 },
      { type = "rester" }, { attendre = 2 } } },
    { "bj_perdu", "Blackjack : dépassé", { ouvrir("blackjack"), { sabot = { 10, 10, 6, 9, 10 } }, JOUER,
      { attendre = 2 }, { type = "tirer" }, { attendre = 2 } } },
    { "bj_blackjack", "Blackjack naturel", { ouvrir("blackjack"), { sabot = { 1, 9, 13, 7 } }, JOUER,
      { attendre = 3 } } },
    { "bj_egalite", "Blackjack : égalité", { ouvrir("blackjack"), { sabot = { 10, 10, 8, 8 } }, JOUER,
      { attendre = 2 }, { type = "rester" }, { attendre = 2 } } },
    { "regles_blackjack", "Règles du blackjack", { ouvrir("blackjack"), { type = "regles" } } },
    { "regles_roulette", "Règles de la roulette", { ouvrir("roulette"), { type = "regles" } } },
    { "refus", "Mise refusée : solde insuffisant", { ouvrir("machine"), MISE_PLUS, MISE_PLUS, MISE_PLUS, JOUER }, {}, 3 },
  }
  for _, c in ipairs(cas) do ecrans[#ecrans + 1] = ecran(c[1] .. s, c[2] .. " (" .. l .. "x" .. h .. ")", l, h, c[3],
    c[4], c[5]) end
end
ecrans[#ecrans + 1] = ecran("hall_164x81", "Hall, très grand moniteur", 164, 81, {})
ecrans[#ecrans + 1] = ecran("bj_main_164x81", "Blackjack, très grand moniteur", 164, 81, { ouvrir("blackjack"),
  { sabot = { 5, 10, 4, 7, 3 } }, JOUER, { attendre = 2 }, { type = "tirer" }, { attendre = 1 } })
ecrans[#ecrans + 1] = ecran("roulette_164x81", "Roulette, très grand moniteur", 164, 81, MISES_ROULETTE)
ecrans[#ecrans + 1] = ecran("trop_petit", "Moniteur trop petit (39x13)", 39, 13, {})

-- Vraie monnaie : hall, dépôt, encaissement, mise refusée faute de réserve, inventaire manquant.
for _, taille in ipairs({ { 100, 38 }, { 51, 19 } }) do
  local l, h = taille[1], taille[2]
  local s = "_" .. l .. "x" .. h
  local monnaie_cas = {
    { "monnaie_hall", "Monnaie : hall", {}, 1250, banque(48250) },
    { "monnaie_depot", "Monnaie : dépôt crédité", { { message = "+300 crédits déposés.", ton = "bon" } }, 1550,
      banque(48550) },
    { "monnaie_encaisse", "Monnaie : encaissement", { { message = "1 250 crédits versés dans le coffre de sortie.",
      ton = "bon" } }, 0, banque(47000) },
    { "monnaie_refus", "Monnaie : mise refusée, réserve insuffisante", { ouvrir("machine"), MISE_PLUS, MISE_PLUS,
      JOUER }, 1250, banque(3000) },
    { "monnaie_manque", "Monnaie : réserve introuvable", { ouvrir("machine") }, 1250, banque(nil, MANQUE) },
  }
  for _, c in ipairs(monnaie_cas) do
    ecrans[#ecrans + 1] = ecran(c[1] .. s, c[2] .. " (" .. l .. "x" .. h .. ")", l, h, c[3], {}, c[4], c[5])
  end
end

return ecrans
