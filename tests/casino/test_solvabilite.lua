-- Solvabilité en vraie monnaie : une mise n'est acceptée que si la réserve couvre le pire gain du tour ; le solde
-- reste couvert après chaque tour de chaque jeu, sur de longues suites tirées à graine fixe.

local verif = require("verif")
local caisse = require("casino.caisse")
local session = require("casino.session")
local machine = require("casino.jeux.machine")
local crash = require("casino.jeux.crash")
local roulette = require("casino.jeux.roulette")
local blackjack = require("casino.jeux.blackjack")
local defauts = require("casino.reglages")

local function copie(source)
  local resultat = {}
  for cle, valeur in pairs(source) do resultat[cle] = valeur end
  return resultat
end

-- Session en crédits, réserve de valeur fixe `reserve` (les jeux ne déplacent aucune pièce).
local function table_couverte(reserve, solde, graine, tirages)
  local reglages = copie(defauts)
  reglages.mode, reglages.mise_min, reglages.mise_max, reglages.mise_defaut = "monnaie", 1, 1000, 10
  local fichier = { solde = solde }
  local c = caisse.ouvrir({ lire = function() return fichier end, ecrire = function(e) fichier = e; return true end },
    { depart = 0, recharge = 0, unite = "crédit", couverture = function() return reserve end })
  local x, indice = graine, 0
  local ctx = { caisse = c, maintenant = 0, inactivite = 90, hasard = function(n)
    indice = indice + 1
    if tirages and tirages[indice] then return tirages[indice] end
    x = (48271 * x) % 2147483647
    return x % n + 1
  end }
  local etat = session.nouvelle(reglages, c.solde())
  etat.monnaie = { pret = true, reserve = reserve }
  local t = { etat = etat, ctx = ctx, caisse = c }
  function t.agir(action) session.agir(etat, action, ctx) end
  function t.attendre(secondes)
    ctx.maintenant = ctx.maintenant + secondes
    session.avancer(etat, ctx)
  end
  function t.couvert()
    verif.vrai(c.solde() <= reserve, "solde " .. c.solde() .. " non couvert par " .. reserve)
  end
  return t
end

local function arret_sept()
  for i, nom in ipairs(machine.BANDE) do
    if nom == "sept" then return i end
  end
end

return {
  expositions_par_jeu_definies_une_fois = function()
    verif.egal(machine.exposition(10), 990)
    verif.egal(crash.exposition(10), 990)
    verif.egal(roulette.exposition({ n17 = 10 }), 350)
    verif.egal(roulette.exposition({ rouge = 10, noir = 10 }), 0)
    verif.egal(roulette.exposition({ n17 = 10, rouge = 5, d2 = 5 }), 350 + 5 + 10 - 10)
    verif.egal(blackjack.exposition(10), 20)
  end,

  mise_refusee_au_dela_de_la_mise_max_affichee_puis_jackpot_couvert = function()
    local sept = arret_sept()
    local t = table_couverte(10000, 1000, 1, { sept, sept, sept, sept, sept, sept })
    verif.egal(session.mises_max(t.etat).machine, 90)
    t.agir({ type = "ouvrir", jeu = "machine" })
    t.etat.mise = 100
    t.agir({ type = "jouer" })
    verif.egal(t.etat.machine.phase, "attente")
    verif.egal(t.caisse.solde(), 1000)
    verif.vrai(t.etat.message.texte:find("Mise max : 90", 1, true), t.etat.message.texte)
    t.etat.mise = 90
    t.agir({ type = "jouer" })
    t.attendre(3)
    verif.egal(t.caisse.solde(), 1000 - 90 + 9000)
    t.couvert()
    verif.egal(session.mises_max(t.etat).machine, 0)
  end,

  reserve_illisible_aucune_mise_acceptee = function()
    local t = table_couverte(nil, 100, 1)
    t.etat.monnaie.pret = false
    t.etat.monnaie.probleme = "Réserve illisible"
    t.agir({ type = "ouvrir", jeu = "machine" })
    verif.egal(t.etat.ecran, "hall")
    verif.vrai(t.etat.message.texte:find("Réserve illisible"), t.etat.message.texte)
    verif.egal((t.caisse.miser(1, 0, 99)), false)
  end,

  machine_et_crash_couverts_sur_400_tours = function()
    for _, jeu in ipairs({ "machine", "crash" }) do
      local t = table_couverte(5000, 200, 11)
      t.agir({ type = "ouvrir", jeu = jeu })
      for tour = 1, 400 do
        t.etat.mise = t.etat.paliers[tour % #t.etat.paliers + 1]
        t.agir({ type = "jouer" })
        if jeu == "crash" and tour % 3 == 0 then
          t.attendre(tour % 7)
          t.agir({ type = "encaisser" })
        end
        t.attendre(60)
        t.couvert()
      end
    end
  end,

  roulette_plusieurs_mises_couvertes_sur_300_tours = function()
    local t = table_couverte(3000, 100, 5)
    t.agir({ type = "ouvrir", jeu = "roulette" })
    local cases = { "n0", "n17", "n36", "rouge", "noir", "d1", "d3", "c2", "pair", "manque" }
    for tour = 1, 300 do
      t.agir({ type = "effacer" })
      t.etat.mise = t.etat.paliers[tour % 4 + 1]
      for k = 0, tour % 4 do t.agir({ type = "case", case = cases[(tour + 3 * k) % #cases + 1] }) end
      t.agir({ type = "jouer" })
      t.attendre(6)
      t.couvert()
    end
  end,

  blackjack_doublements_couverts_sur_300_mains = function()
    local t = table_couverte(400, 100, 3)
    t.agir({ type = "ouvrir", jeu = "blackjack" })
    local actions = { "tirer", "doubler", "rester", "doubler" }
    for main = 1, 300 do
      t.etat.mise = t.etat.paliers[main % 5 + 1]
      t.agir({ type = "jouer" })
      t.attendre(3)
      t.agir({ type = actions[main % #actions + 1] })
      t.attendre(3)
      t.agir({ type = "rester" })
      t.attendre(6)
      t.couvert()
    end
  end,
}
