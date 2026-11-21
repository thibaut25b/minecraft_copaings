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

-- Joue `etapes` (actions, attentes) sur une session neuve ; renvoie l'état et l'instant final.
-- Une étape : { action } pour agir, { attendre = secondes } pour avancer le temps.
local function jouer(etapes, tirages, solde)
  local d = { contenu = { solde = solde or 1250 } }
  d.lire = function() return d.contenu end
  d.ecrire = function(etat) d.contenu = etat; return true end
  local c = caisse.ouvrir(d, { depart = defauts.jetons_depart, recharge = defauts.recharge })
  local indice = 0
  local ctx = { caisse = c, maintenant = 100, inactivite = defauts.inactivite, hasard = function()
    indice = indice + 1
    return (tirages or {})[indice] or 1
  end }
  local etat = session.nouvelle(defauts, c.solde())
  for _, etape in ipairs(etapes) do
    if etape.attendre then
      ctx.maintenant = ctx.maintenant + etape.attendre
      session.avancer(etat, ctx)
    else
      session.agir(etat, etape, ctx)
    end
  end
  etat.appui = nil
  return etat, ctx.maintenant
end

local function ecran(nom, titre, largeur, hauteur, etapes, tirages, solde)
  return {
    nom = nom, titre = titre, largeur = largeur, hauteur = hauteur, images = 1,
    dessiner = function(cible)
      local etat, maintenant = jouer(etapes, tirages, solde)
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
    { "regles_roulette", "Règles de la roulette", { ouvrir("roulette"), { type = "regles" } } },
    { "refus", "Mise refusée : solde insuffisant", { ouvrir("machine"), MISE_PLUS, MISE_PLUS, MISE_PLUS, JOUER }, {}, 3 },
  }
  for _, c in ipairs(cas) do ecrans[#ecrans + 1] = ecran(c[1] .. s, c[2] .. " (" .. l .. "x" .. h .. ")", l, h, c[3],
    c[4], c[5]) end
end
ecrans[#ecrans + 1] = ecran("hall_164x81", "Hall, très grand moniteur", 164, 81, {})
ecrans[#ecrans + 1] = ecran("roulette_164x81", "Roulette, très grand moniteur", 164, 81, MISES_ROULETTE)
ecrans[#ecrans + 1] = ecran("trop_petit", "Moniteur trop petit (39x13)", 39, 13, {})

return ecrans
